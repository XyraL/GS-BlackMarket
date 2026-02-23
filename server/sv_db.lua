BMDB = {}

local function exec(query, params)
  return MySQL.query.await(query, params or {})
end

function BMDB.init()
  dbg('Initializing database tables...')

  exec([[
    CREATE TABLE IF NOT EXISTS bm_accounts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      identifier VARCHAR(64) NOT NULL,
      username VARCHAR(32) NOT NULL,
      passhash VARCHAR(128) NOT NULL,
      alias VARCHAR(32) NOT NULL,
      pin VARCHAR(16) NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_login TIMESTAMP NULL,
      UNIQUE KEY uniq_identifier (identifier),
      UNIQUE KEY uniq_username (username)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]])

  exec([[
    CREATE TABLE IF NOT EXISTS bm_orders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      identifier VARCHAR(64) NOT NULL,
      alias VARCHAR(32) NOT NULL,
      status VARCHAR(16) NOT NULL,
      payment_method VARCHAR(16) NOT NULL,
      subtotal INT NOT NULL,
      delivery_fee INT NOT NULL,
      total INT NOT NULL,
      items_json LONGTEXT NOT NULL,
      drop_json LONGTEXT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      dispatched_at TIMESTAMP NULL,
      ready_at TIMESTAMP NULL,
      eta_dispatch_at TIMESTAMP NULL,
      eta_ready_at TIMESTAMP NULL,
      claimed_at TIMESTAMP NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]])

  
  
  pcall(function() exec("ALTER TABLE bm_orders ADD COLUMN ready_at TIMESTAMP NULL") end)
  pcall(function() exec("ALTER TABLE bm_orders ADD COLUMN eta_dispatch_at TIMESTAMP NULL") end)
  pcall(function() exec("ALTER TABLE bm_orders ADD COLUMN eta_ready_at TIMESTAMP NULL") end)

  dbg('Database ready.')

  
  exec("UPDATE bm_orders SET status = 'canceled' WHERE status = 'cancelled'")

  
  
  exec("UPDATE bm_orders SET status = LOWER(REPLACE(REPLACE(TRIM(status),'-','_'),' ','_'))")

  
  
  
  exec("UPDATE bm_orders SET status = 'canceled' WHERE status = 'ready' AND claimed_at IS NULL AND ((dispatched_at IS NOT NULL AND dispatched_at < (NOW() - INTERVAL 24 HOUR)) OR (created_at < (NOW() - INTERVAL 24 HOUR)))")

end


function BMDB.getAccount(identifier)
  local rows = exec('SELECT * FROM bm_accounts WHERE identifier = ? LIMIT 1', { identifier })
  return rows and rows[1] or nil
end

function BMDB.createAccount(identifier, username, passhash, alias, pin)
  exec(
    'INSERT INTO bm_accounts (identifier, username, passhash, alias, pin, last_login) VALUES (?, ?, ?, ?, ?, NOW())',
    { identifier, username, passhash, alias, pin }
  )
  return BMDB.getAccount(identifier)
end

function BMDB.updateLastLogin(identifier)
  exec('UPDATE bm_accounts SET last_login = NOW() WHERE identifier = ?', { identifier })
end

function BMDB.updateAlias(identifier, alias)
  exec('UPDATE bm_accounts SET alias = ? WHERE identifier = ?', { alias, identifier })
  
  exec('UPDATE bm_orders SET alias = ? WHERE identifier = ? AND status NOT IN (\'claimed\')', { alias, identifier })
  return true
end

function BMDB.updatePasshash(identifier, passhash)
  exec('UPDATE bm_accounts SET passhash = ? WHERE identifier = ?', { passhash, identifier })
  return true
end


function BMDB.insertOrder(identifier, alias, status, paymentMethod, subtotal, deliveryFee, total, itemsJson)
  local q = 'INSERT INTO bm_orders (identifier, alias, status, payment_method, subtotal, delivery_fee, total, items_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  local p = { identifier, alias, status, paymentMethod, subtotal, deliveryFee, total, itemsJson }

  
  
  
  
  local id = nil
  if MySQL and MySQL.insert and MySQL.insert.await then
    id = MySQL.insert.await(q, p)
  else
    
    local res = (MySQL and MySQL.query and MySQL.query.await) and MySQL.query.await(q, p) or exec(q, p)
    if type(res) == 'table' and (res.insertId or res.insert_id) then
      id = res.insertId or res.insert_id
    end
  end

  
  if not id then
    local rows = exec('SELECT LAST_INSERT_ID() AS id')
    id = rows and rows[1] and rows[1].id or nil
  end

  return tonumber(id)
end

function BMDB.getOrder(orderId, identifier)
  local rows = exec('SELECT * FROM bm_orders WHERE id = ? AND identifier = ? LIMIT 1', { orderId, identifier })
  return rows and rows[1] or nil
end

function BMDB.updateOrderDispatch(orderId, dropJson)
  
  return MySQL.update.await("UPDATE bm_orders SET status = 'dispatched', drop_json = ?, dispatched_at = NOW() WHERE id = ? AND status NOT IN ('canceled','claimed')", { dropJson, orderId })
end


function BMDB.updateOrderStatus(orderId, status)
  
  return MySQL.update.await("UPDATE bm_orders SET status = ? WHERE id = ? AND status NOT IN ('canceled','claimed')", { status, orderId })
end

function BMDB.updateOrderReady(orderId)
  return MySQL.update.await("UPDATE bm_orders SET status = 'ready', ready_at = NOW() WHERE id = ? AND status NOT IN ('canceled','claimed')", { orderId })
end

function BMDB.updateOrderClaimed(orderId)
  
  if MySQL and MySQL.update and MySQL.update.await then
    return MySQL.update.await("UPDATE bm_orders SET status = 'claimed', claimed_at = NOW() WHERE id = ?", { orderId })
  end
  
  local ok = exec("UPDATE bm_orders SET status = 'claimed', claimed_at = NOW() WHERE id = ?", { orderId })
  return ok
end

function BMDB.updateOrderCanceled(orderId)
  
  return MySQL.update.await("UPDATE bm_orders SET status = 'canceled', drop_json = NULL WHERE id = ?", { orderId })
end




function BMDB.setOrderEtas(orderId, processingDelaySeconds, enRouteDelaySeconds)
  processingDelaySeconds = tonumber(processingDelaySeconds) or 0
  enRouteDelaySeconds = tonumber(enRouteDelaySeconds) or 0
  local total = processingDelaySeconds + enRouteDelaySeconds
  return MySQL.update.await(
    "UPDATE bm_orders SET eta_dispatch_at = (NOW() + INTERVAL ? SECOND), eta_ready_at = (NOW() + INTERVAL ? SECOND) WHERE id = ?",
    { processingDelaySeconds, total, orderId }
  )
end

function BMDB.listOrders(identifier, limit)
  limit = clamp(limit or 20, 1, 50)

  
  
  local maxH = 24
  if Config and Config.Orders and tonumber(Config.Orders.maxActiveAgeHours) then
    maxH = clamp(tonumber(Config.Orders.maxActiveAgeHours), 1, 168)
  end

  local canon = "LOWER(REPLACE(REPLACE(TRIM(status),'-','_'),' ','_'))"
  local q = (
    "SELECT id, " .. canon .. " AS status, payment_method, total, items_json, drop_json, created_at, dispatched_at, ready_at, eta_dispatch_at, eta_ready_at, claimed_at " ..
    "FROM bm_orders " ..
    "WHERE identifier = ? " ..
    "AND " .. canon .. " IN ('pending','paid','processing','dispatched','en_route','ready') " ..
    "AND created_at >= (NOW() - INTERVAL " .. tostring(maxH) .. " HOUR) " ..
    "ORDER BY id DESC LIMIT ?"
  )

  return exec(q, { identifier, limit })
end


function BMDB.getLatestReadyOrder(identifier)
  local maxH = 24
  if Config and Config.Orders and tonumber(Config.Orders.maxActiveAgeHours) then
    maxH = clamp(tonumber(Config.Orders.maxActiveAgeHours), 1, 168)
  end

  local canon = "LOWER(REPLACE(REPLACE(TRIM(status),'-','_'),' ','_'))"
  local q = (
    "SELECT * FROM bm_orders WHERE identifier = ? AND " .. canon .. " = 'ready' " ..
    "AND claimed_at IS NULL AND created_at >= (NOW() - INTERVAL " .. tostring(maxH) .. " HOUR) " ..
    "ORDER BY id DESC LIMIT 1"
  )
  local rows = exec(q, { identifier })
  return rows and rows[1] or nil
end


function BMDB.listUnclaimedOrders()
  
  
  local canon = "LOWER(REPLACE(REPLACE(TRIM(status),'-','_'),' ','_'))"
  local q = (
    "SELECT * FROM bm_orders WHERE claimed_at IS NULL AND " .. canon .. " IN ('dispatched','en_route') ORDER BY id ASC"
  )
  return exec(q, {})
end

function BMDB.forceOrderReady(orderId, dropJson)
  exec(
    'UPDATE bm_orders SET status = ?, drop_json = ?, dispatched_at = IFNULL(dispatched_at, NOW()) WHERE id = ?',
    { 'ready', dropJson, orderId }
  )
end
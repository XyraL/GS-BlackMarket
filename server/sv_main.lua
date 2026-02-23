local function validLen(s, minL, maxL)
  s = tostring(s or ''):gsub('%s+', '')
  return #s >= minL and #s <= maxL
end

local function cleanAlias(s)
  s = tostring(s or ''):gsub('[^%w_%- ]', '')
  s = s:gsub('%s+', ' '):sub(1, Config.Accounts.maxAliasLen)
  return s
end

local function cleanUser(s)
  s = tostring(s or ''):lower():gsub('[^%w_%-%.]', '')
  s = s:sub(1, Config.Accounts.maxUsernameLen)
  return s
end

local function hashPassword(password, salt)
  local data = (salt or '') .. '|' .. tostring(password or '')

  if lib and lib.crypto then
    if type(lib.crypto) == 'table' and type(lib.crypto.hash) == 'function' then
      local ok, out = pcall(lib.crypto.hash, 'sha256', data)
      if ok and out then return out end
    elseif type(lib.crypto) == 'function' then
      local ok, out = pcall(lib.crypto, 'sha256', data)
      if ok and out then return out end
    end
  end

  
  return tostring(GetHashKey(data)) .. ':' .. tostring(GetHashKey(data .. '|x'))
end

local function randBetween(a, b)
  a = tonumber(a) or 0
  b = tonumber(b) or 0
  if a > b then a, b = b, a end
  if a == b then return math.floor(a) end
  return math.random(math.floor(a), math.floor(b))
end

local function mysqlUpdate(q, params)
  if MySQL and MySQL.update and MySQL.update.await then
    return MySQL.update.await(q, params or {})
  end
  if MySQL and MySQL.query and MySQL.query.await then
    
    local r = MySQL.query.await(q, params or {})
    if type(r) == 'number' then return r end
    return 0
  end
  return 0
end

local function mysqlSingle(q, params)
  if MySQL and MySQL.single and MySQL.single.await then
    return MySQL.single.await(q, params or {})
  end
  if MySQL and MySQL.query and MySQL.query.await then
    local rows = MySQL.query.await(q, params or {})
    if type(rows) == 'table' then return rows[1] end
  end
  return nil
end

local function safeUpdateStatus(orderId, status)
  local ok, out = pcall(function()
    if BMDB and BMDB.updateOrderStatus then
      return BMDB.updateOrderStatus(orderId, status)
    end
    return mysqlUpdate("UPDATE bm_orders SET status = ? WHERE id = ? AND status NOT IN ('canceled','claimed')", { status, orderId })
  end)
  if not ok then
    dbg('Order ladder status update failed:', orderId, status, out)
    return 0
  end
  return out or 0
end

local function safeDispatch(orderId, dropJson)
  local ok, out = pcall(function()
    if BMDB and BMDB.updateOrderDispatch then
      return BMDB.updateOrderDispatch(orderId, dropJson)
    end
    return mysqlUpdate("UPDATE bm_orders SET status = 'dispatched', drop_json = ?, dispatched_at = NOW() WHERE id = ? AND status NOT IN ('canceled','claimed')", { dropJson, orderId })
  end)
  if not ok then
    dbg('Order ladder dispatch update failed:', orderId, out)
    return 0
  end
  return out or 0
end

local function safeReady(orderId)
  local ok, out = pcall(function()
    if BMDB and BMDB.updateOrderReady then
      return BMDB.updateOrderReady(orderId)
    end
    return mysqlUpdate("UPDATE bm_orders SET status = 'ready', ready_at = NOW() WHERE id = ? AND status NOT IN ('canceled','claimed')", { orderId })
  end)
  if not ok then
    dbg('Order ladder ready update failed:', orderId, out)
    return 0
  end
  return out or 0
end

local function safeGetStatus(orderId)
  local row = mysqlSingle('SELECT status FROM bm_orders WHERE id = ? LIMIT 1', { orderId })
  local stRaw = row and row.status or nil
  local st = (tostring(stRaw or ''):lower():gsub('%s+', '_'):gsub('%-+', '_'):gsub('[^%w_]', ''):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$',''))
  return st
end


local function getVendor(vendorId)
  for _, v in ipairs(Config.Vendors) do
    if v.id == vendorId then return v end
  end
  return nil
end

local function buildCatalog()
  
  local out = {}
  for _, item in ipairs(Config.Catalog) do
    local v = getVendor(item.vendor)
    if v and v.enabled then
      local price = math.floor((item.price or 0) * (v.priceMultiplier or 1.0))
      out[#out+1] = {
        name = item.name,
        label = item.label,
        price = price,
        vendor = item.vendor,
        category = item.category,
        icon = item.icon or 'box',
      }
    end
  end
  return out
end

local function computeDeliveryFee(subtotal)
  local fee = 0
  if Config.Orders.deliveryFee.mode == 'percent' then
    fee = math.floor(subtotal * (Config.Orders.deliveryFee.percent or 0))
  else
    fee = math.floor(Config.Orders.deliveryFee.flat or 0)
  end
  fee = clamp(fee, Config.Orders.deliveryFee.min or 0, Config.Orders.deliveryFee.max or 999999)
  return fee
end

local function pickDrop(src)
  
  
  local pcoords = nil
  if src then
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
      pcoords = GetEntityCoords(ped)
    end
  end

  local pools = {}

  
  if Config.Delivery and Config.Delivery.useFixedDrops and type(Config.Delivery.fixedDrops) == 'table' and #Config.Delivery.fixedDrops > 0 then
    for _, v in ipairs(Config.Delivery.fixedDrops) do
      
      local x = (v.x or v[1])
      local y = (v.y or v[2])
      local z = (v.z or v[3])
      local h = (v.w or v.heading or v[4] or 0.0)
      if x and y and z then
        pools[#pools + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0, heading = h + 0.0, label = 'Drop' }
      end
    end
  else
    if Config.Delivery.poolMode == 'city' then pools = Config.Delivery.dropPools.city
    elseif Config.Delivery.poolMode == 'desert' then pools = Config.Delivery.dropPools.desert
    else
      
      for _, d in ipairs(Config.Delivery.dropPools.city) do pools[#pools+1] = d end
      for _, d in ipairs(Config.Delivery.dropPools.desert) do pools[#pools+1] = d end
    end
  end

  
  if not pools or #pools == 0 then
    pools = {}
    if Config.Delivery.poolMode == 'city' then pools = Config.Delivery.dropPools.city
    elseif Config.Delivery.poolMode == 'desert' then pools = Config.Delivery.dropPools.desert
    else
      for _, d in ipairs(Config.Delivery.dropPools.city) do pools[#pools+1] = d end
      for _, d in ipairs(Config.Delivery.dropPools.desert) do pools[#pools+1] = d end
    end
  end

  local best = nil
  if pcoords then
    for _ = 1, (Config.Delivery.maxAttempts or 25) do
      local cand = pools[math.random(1, #pools)]
      local dist = #(vector3(cand.x, cand.y, cand.z) - pcoords)
      if dist >= (Config.Delivery.minDistanceFromPlayer or 0.0) then
        best = cand
        break
      end
    end
  end

  if not best then
    best = pools[math.random(1, #pools)]
  end

  
  return {
    mode = 'courier',
    x = best.x, y = best.y, z = best.z,
    heading = best.heading or 0.0,
  }
end


local lastOrderAt = {}
local ActiveOrderLadders = {}

CreateThread(function()
  math.randomseed(GetGameTimer())
  Adapter.detect()
  BMDB.init()
  
  local ok, rows = pcall(BMDB.listUnclaimedOrders)
  if ok and rows and #rows > 0 then
    for _, ord in ipairs(rows) do
      
      if ord.status ~= 'ready' or not ord.drop_json or ord.drop_json == '' then
        local drop = pickDrop(nil)
        BMDB.forceOrderReady(ord.id, json.encode(drop))
      end
    end
    dbg(('Recovery checked %s unclaimed orders.'):format(#rows))
  end
end)

  ActiveOrderLadders = ActiveOrderLadders or {}
  if not orderId or orderId == 0 then
    dbg('Attempted to start ladder with nil orderId')
    return
  end
  if ActiveOrderLadders[orderId] then return end
  ActiveOrderLadders[orderId] = true

CreateThread(function()
    dbg('Order ladder started:', orderId, 'processingDelay', processingDelay, 'enrouteDelay', enrouteDelay)
  Wait(500)

  local itemName = Config.Inventory.tabletItemName

  if Adapter.fw == 'qbox' then
    exports.qbx_core:CreateUseableItem(itemName, function(source)
      TriggerClientEvent('gs-blackmarket:client:openTablet', source)
    end)
    dbg('Registered usable item (qbox):', itemName)
  else
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.CreateUseableItem(itemName, function(source)
      TriggerClientEvent('gs-blackmarket:client:openTablet', source)
    end)
    dbg('Registered usable item (qbcore):', itemName)
  end
end)


lib.callback.register('gs-blackmarket:server:getConfig', function(src)
  local imgBase
  local mode = (Config.Images and Config.Images.mode) or 'auto'
  if mode == 'auto' then
    imgBase = (Adapter.inv == 'qb-inventory') and (Config.Images.qbPath) or (Config.Images.oxPath)
  elseif mode == 'qb' or mode == 'qb-inventory' then
    imgBase = Config.Images.qbPath
  else
    imgBase = Config.Images.oxPath
  end

  return {
    ui = Config.UI,
    vendors = Config.Vendors,
    images = {
      base = imgBase,
      inv = Adapter.inv,
    },
  }
end)

lib.callback.register('gs-blackmarket:server:getCatalog', function(src)
  return buildCatalog()
end)

lib.callback.register('gs-blackmarket:server:getAccountState', function(src)
  local identifier = Adapter.getIdentifier(src)
  local acct = BMDB.getAccount(identifier)
  if not acct then return { exists = false } end
  return { exists = true, alias = acct.alias, username = acct.username }
end)

lib.callback.register('gs-blackmarket:server:register', function(src, payload)
  local identifier = Adapter.getIdentifier(src)
  if BMDB.getAccount(identifier) then
    return { ok = false, err = 'Account already exists for this player.' }
  end

  local username = cleanUser(payload.username)
  local password = tostring(payload.password or '')
  local alias = cleanAlias(payload.alias)

  if not validLen(username, Config.Accounts.minUsernameLen, Config.Accounts.maxUsernameLen) then
    return { ok = false, err = 'Username length invalid.' }
  end
  if not validLen(password, Config.Accounts.minPasswordLen, Config.Accounts.maxPasswordLen) then
    return { ok = false, err = 'Password length invalid.' }
  end
  if not validLen(alias, Config.Accounts.minAliasLen, Config.Accounts.maxAliasLen) then
    return { ok = false, err = 'Alias length invalid.' }
  end

  local salt = identifier
  local passhash = hashPassword(password, salt)
  local pin = nil
  if Config.Accounts.enablePIN then
    pin = tostring(payload.pin or ''):gsub('%D', ''):sub(1, 8)
  end

  local ok, err = pcall(function()
    BMDB.createAccount(identifier, username, passhash, alias, pin)
  end)
  if not ok then
    dbg('Register error:', err)
    return { ok = false, err = 'Username might already be taken.' }
  end

  return { ok = true, alias = alias, username = username }
end)

lib.callback.register('gs-blackmarket:server:login', function(src, payload)
  local identifier = Adapter.getIdentifier(src)
  local acct = BMDB.getAccount(identifier)
  if not acct then
    return { ok = false, err = 'No account found. Create one first.' }
  end

  local username = cleanUser(payload.username)
  local password = tostring(payload.password or '')

  if username ~= acct.username then
    return { ok = false, err = 'Invalid credentials.' }
  end

  local passhash = hashPassword(password, identifier)
  if passhash ~= acct.passhash then
    return { ok = false, err = 'Invalid credentials.' }
  end

  if Config.Accounts.enablePIN then
    local pin = tostring(payload.pin or ''):gsub('%D', ''):sub(1, 8)
    if not acct.pin or pin ~= acct.pin then
      return { ok = false, err = 'Invalid PIN.' }
    end
  end

  BMDB.updateLastLogin(identifier)
  return { ok = true, alias = acct.alias, username = acct.username }
end)

lib.callback.register('gs-blackmarket:server:changeAlias', function(src, payload)
  local identifier = Adapter.getIdentifier(src)
  local acct = BMDB.getAccount(identifier)
  if not acct then return { ok=false, err='Not logged in.' } end

  local alias = tostring(payload and payload.alias or '')
  alias = alias:gsub('[^%w_%-]', ''):sub(1, 24)
  if alias == '' then return { ok=false, err='Invalid alias.' } end

  BMDB.updateAlias(identifier, alias)
  return { ok=true, alias=alias }
end)

lib.callback.register('gs-blackmarket:server:changePassword', function(src, payload)
  local identifier = Adapter.getIdentifier(src)
  local acct = BMDB.getAccount(identifier)
  if not acct then return { ok=false, err='Not logged in.' } end

  local cur = tostring(payload and payload.currentPassword or '')
  local newp = tostring(payload and payload.newPassword or '')
  if #newp < 4 then return { ok=false, err='Password too short.' } end

  if hashPassword(cur, identifier) ~= acct.passhash then
    return { ok=false, err='Current password incorrect.' }
  end

  BMDB.updatePasshash(identifier, hashPassword(newp, identifier))
  return { ok=true }
end)

lib.callback.register('gs-blackmarket:server:listOrders', function(src)
  local identifier = Adapter.getIdentifier(src)
  return BMDB.listOrders(identifier, 20)
end)



lib.callback.register('gs-blackmarket:server:getDropForOrder', function(src, orderId)
  local identifier = Adapter.getIdentifier(src)
  local ord = BMDB.getOrder(orderId, identifier)
  if not ord or not ord.drop_json or ord.drop_json == '' then return nil end
  local drop = json.decode(ord.drop_json)
  if not drop then return nil end
  return { orderId = ord.id, status = ord.status, drop = drop }
end)



lib.callback.register('gs-blackmarket:server:getActiveDrop', function(src)
  local identifier = Adapter.getIdentifier(src)
  local ord = BMDB.getLatestReadyOrder(identifier)
  if not ord or not ord.drop_json then return nil end

  local drop = json.decode(ord.drop_json)
  if not drop then return nil end
  return { orderId = ord.id, drop = drop }
end)

lib.callback.register('gs-blackmarket:server:createOrder', function(src, payload)
  local identifier = Adapter.getIdentifier(src)
  local acct = BMDB.getAccount(identifier)
  if not acct then return { ok = false, err = 'Not logged in.' } end

  
  local t = now()
  local last = lastOrderAt[identifier] or 0
  if (t - last) < (Config.Orders.cooldownSeconds or 0) then
    return { ok = false, err = 'Slow down. Try again in a moment.' }
  end

  local items = payload.items or {}
  local paymentMethod = tostring(payload.paymentMethod or 'cash')
  local allowed = false
  for _, m in ipairs(Config.Payment.allowed) do
    if m == paymentMethod then allowed = true end
  end
  if not allowed then
    return { ok = false, err = 'Payment method not allowed.' }
  end

  
  local priceMap = {}
  for _, c in ipairs(buildCatalog()) do
    priceMap[c.name] = c.price
  end

  
  local subtotal = 0
  local cleanItems = {}

  for _, it in ipairs(items) do
    local name = tostring(it.name or '')
    local qty = math.floor(tonumber(it.qty) or 0)
    if qty > 0 and priceMap[name] then
      qty = clamp(qty, 1, 999)
      local line = priceMap[name] * qty
      subtotal = subtotal + line
      cleanItems[#cleanItems+1] = { name = name, qty = qty, price = priceMap[name] }
    end
  end

  if #cleanItems == 0 then
    return { ok = false, err = 'Cart is empty.' }
  end
  if subtotal < (Config.Orders.minTotal or 0) then
    return { ok = false, err = 'Order too small.' }
  end

  local deliveryFee = computeDeliveryFee(subtotal)
  local total = subtotal + deliveryFee

  
  if Adapter.getMoney(src, paymentMethod) < total then
    return { ok = false, err = 'Not enough money.' }
  end
  if not Adapter.removeMoney(src, paymentMethod, total, 'GS-BlackMarket Order') then
    return { ok = false, err = 'Payment failed.' }
  end

  local itemsJson = json.encode(cleanItems)
  
  local orderId = BMDB.insertOrder(identifier, acct.alias, 'paid', paymentMethod, subtotal, deliveryFee, total, itemsJson)
  if not orderId or orderId == 0 then
    return { ok = false, err = 'Order creation failed.' }
  end

  lastOrderAt[identifier] = t

  local function pickTierDelays(totalAmount, itemCount)
    local tiers = Config.Orders and Config.Orders.timingTiers
    if type(tiers) == 'table' then
      for _, tier in ipairs(tiers) do
        local maxT = tonumber(tier.maxTotal or -1) or -1
        local maxI = tonumber(tier.maxItems or -1) or -1
        if (maxT < 0 or totalAmount <= maxT) and (maxI < 0 or itemCount <= maxI) then
          local pd = randBetween((tier.processing or {}).min, (tier.processing or {}).max)
          local ed = randBetween((tier.enroute or {}).min, (tier.enroute or {}).max)
          if pd > 0 and ed > 0 then return pd, ed end
        end
      end
    end

    local pd = randBetween(Config.Orders.processingDelaySeconds.min, Config.Orders.processingDelaySeconds.max)
    local ed = randBetween(Config.Orders.enRouteDelaySeconds.min, Config.Orders.enRouteDelaySeconds.max)
    return pd, ed
  end

  local processingDelay, enrouteDelay = pickTierDelays(total, #cleanItems)

  
  pcall(function()
    if BMDB and BMDB.setOrderEtas then
      BMDB.setOrderEtas(orderId, processingDelay, enrouteDelay)
    end
  end)

  
  TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'paid')

  CreateThread(function()
    dbg('Order ladder started:', orderId, 'processingDelay', processingDelay, 'enrouteDelay', enrouteDelay)
    
    Wait(500)
    safeUpdateStatus(orderId, 'processing')
    TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'processing')
    dbg('Order ladder status -> processing:', orderId)

    
    Wait(processingDelay * 1000)

    local stRow = MySQL.single.await('SELECT status FROM bm_orders WHERE id = ? LIMIT 1', { orderId })
    local stRaw = stRow and stRow.status or nil
    local st = (tostring(stRaw or ''):lower():gsub('%s+', '_'):gsub('%-+', '_'):gsub('[^%w_]', ''):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$',''))
    if st == '' or st == 'canceled' or st == 'claimed' then return end

    local drop = pickDrop(src)

    
    drop.mode = 'courier'
    drop.code = tostring(math.random(100000, 999999))

    safeDispatch(orderId, json.encode(drop))
    TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'dispatched', drop)
    dbg('Order ladder status -> dispatched:', orderId)

    
    stRow = MySQL.single.await('SELECT status FROM bm_orders WHERE id = ? LIMIT 1', { orderId })
    stRaw = stRow and stRow.status or nil
    st = (tostring(stRaw or ''):lower():gsub('%s+', '_'):gsub('%-+', '_'):gsub('[^%w_]', ''):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$',''))
    if st == '' or st == 'canceled' or st == 'claimed' then return end

    safeUpdateStatus(orderId, 'en_route')
    TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'en_route', drop)
    dbg('Order ladder status -> en_route:', orderId)

    
    Wait(enrouteDelay * 1000)

    stRow = MySQL.single.await('SELECT status FROM bm_orders WHERE id = ? LIMIT 1', { orderId })
    stRaw = stRow and stRow.status or nil
    st = (tostring(stRaw or ''):lower():gsub('%s+', '_'):gsub('%-+', '_'):gsub('[^%w_]', ''):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$',''))
    if st == '' or st == 'canceled' or st == 'claimed' then return end

    safeReady(orderId)
    TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'ready', drop)
    dbg('Order ladder status -> ready:', orderId)
    ActiveOrderLadders[orderId] = nil
    TriggerClientEvent('gs-blackmarket:client:orderReady', src, orderId, drop)
  end)


  return { ok = true, orderId = orderId, subtotal = subtotal, deliveryFee = deliveryFee, total = total }
end)

lib.callback.register('gs-blackmarket:server:claimOrder', function(src, orderId, code)
  local identifier = Adapter.getIdentifier(src)
  local order = BMDB.getOrder(orderId, identifier)
  if not order then return { ok = false, err = 'Order not found.' } end
  if order.status ~= 'ready' then return { ok = false, err = 'Order not ready.' } end

  
  local drop = nil
  pcall(function() drop = json.decode(order.drop_json or '{}') end)
  if type(drop) == 'table' and tostring(drop.mode or '') == 'courier' then
    local want = tostring(drop.code or '')
    local got = tostring(code or ''):gsub('%s+', '')
    if want ~= '' and got ~= want then
      return { ok = false, err = 'Invalid code.' }
    end
  end

  local items = json.decode(order.items_json or '[]') or {}
  
  for _, it in ipairs(items) do
    local ok, err = Adapter.addItem(src, it.name, it.qty, { bm = true, orderId = orderId })
    
    if ok == false or ok == nil then
      return { ok = false, err = ('Failed to give item: %s'):format(tostring(it.name)) }
    end
  end

  local affected = BMDB.updateOrderClaimed(orderId)
  if affected == 0 then
    
    return { ok = false, err = 'Failed to close order. Try again.' }
  end
  
  TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'claimed')
  TriggerClientEvent('gs-blackmarket:client:orderClaimed', src, orderId)
  return { ok = true }
end)


lib.callback.register('gs-blackmarket:server:cancelOrder', function(src, orderId)
  orderId = tonumber(orderId)
  if not orderId or orderId == 0 then return { ok = false, err = 'Invalid order.' } end

  local identifier = Adapter.getIdentifier(src)
  local order = BMDB.getOrder(orderId, identifier)
  if not order then return { ok = false, err = 'Order not found.' } end

  local st = tostring(order.status or ''):lower()
  if st == 'claimed' then return { ok = false, err = 'Already claimed.' } end
  if st == 'canceled' then return { ok = false, err = 'Already canceled.' } end

  
  local pay = tostring(order.payment_method or 'cash')
  local total = tonumber(order.total or 0) or 0
  if total > 0 then
    Adapter.addMoney(src, pay, total, 'GS-BlackMarket Refund')
  end

  BMDB.updateOrderCanceled(orderId)

  
  TriggerClientEvent('gs-blackmarket:client:orderStatus', src, orderId, 'canceled')
  TriggerClientEvent('gs-blackmarket:client:orderCanceled', src, orderId)

  return { ok = true }
end)
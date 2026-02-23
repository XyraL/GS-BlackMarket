Adapter = {
  fw = nil,
  inv = nil,
}

local function resStarted(name)
  return GetResourceState(name) == 'started'
end

function Adapter.detect()
  
  if Config.Framework.mode ~= 'auto' then
    Adapter.fw = Config.Framework.mode
  else
    if resStarted('qbx_core') then Adapter.fw = 'qbox'
    elseif resStarted('qb-core') then Adapter.fw = 'qbcore'
    else Adapter.fw = 'qbcore' end
  end

  
  if Config.Inventory.mode ~= 'auto' then
    Adapter.inv = Config.Inventory.mode
  else
    if resStarted('ox_inventory') then Adapter.inv = 'ox_inventory'
    elseif resStarted('qb-inventory') then Adapter.inv = 'qb-inventory'
    else Adapter.inv = 'ox_inventory' end
  end

  dbg('Detected framework:', Adapter.fw, 'inventory:', Adapter.inv)
end


function Adapter.getIdentifier(src)
  
  for _, id in ipairs(GetPlayerIdentifiers(src)) do
    if id:find('license:') == 1 then return id end
  end
  
  local ids = GetPlayerIdentifiers(src)
  return ids[1]
end


function Adapter.getPlayer(src)
  if Adapter.fw == 'qbox' then
    return exports.qbx_core:GetPlayer(src)
  end
  return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
end

function Adapter.getMoney(src, account)
  local ply = Adapter.getPlayer(src)
  if not ply then return 0 end

  if Adapter.fw == 'qbox' then
    return ply.Functions.GetMoney(account) or 0
  end

  return ply.PlayerData.money[account] or 0
end

function Adapter.removeMoney(src, account, amount, reason)
  local ply = Adapter.getPlayer(src)
  if not ply then return false end

  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return true end

  if Adapter.fw == 'qbox' then
    return ply.Functions.RemoveMoney(account, amount, reason or 'GS-BlackMarket')
  end

  return ply.Functions.RemoveMoney(account, amount, reason or 'GS-BlackMarket')
end

function Adapter.addMoney(src, account, amount, reason)
  local ply = Adapter.getPlayer(src)
  if not ply then return false end

  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return true end

  
  return ply.Functions.AddMoney(account, amount, reason or 'GS-BlackMarket')
end


function Adapter.hasItem(src, itemName, count)
  count = count or 1
  if Adapter.inv == 'ox_inventory' then
    local c = exports.ox_inventory:Search(src, 'count', itemName)
    return (c or 0) >= count
  end

  
  local ply = Adapter.getPlayer(src)
  if not ply then return false end
  local item = ply.Functions.GetItemByName(itemName)
  return item and item.amount and item.amount >= count
end

function Adapter.addItem(src, itemName, count, metadata)
  count = count or 1
  metadata = metadata or {}

  if Adapter.inv == 'ox_inventory' then
    
    local ok, extra = exports.ox_inventory:AddItem(src, itemName, count, metadata)
    if ok == nil then ok = false end

    
    
    
    if not ok and type(itemName) == 'string' then
      local lower = itemName:lower()
      if lower:sub(1,7) == 'weapon_' then
        local upper = ('WEAPON_%s'):format(lower:sub(8):upper())
        ok, extra = exports.ox_inventory:AddItem(src, upper, count, metadata)
        if ok == nil then ok = false end
      end
    end

    return ok, extra
  end

  local ply = Adapter.getPlayer(src)
  if not ply then return false end
  return ply.Functions.AddItem(itemName, count, false, metadata)
end

local opened = false
local currentDrop = nil
local currentDropReady = false
local currentOrderId = nil
local dropEntity = nil
local courierPed = nil
local guardPeds = {}
local dropBlip = nil
local dropRadiusBlip = nil
local crateRevealed = false


local signalStrength = 0.0
local lastBeepAt = 0
local revealDistOverride = nil
local unlockMult = 1.0


local pendingCourierCode = nil
local lastCollectAt = 0
local collecting = false


local fxPostRunning = false
local lockStingerPlayed = false
local lastShakeAt = 0


local lastAudioSendAt = 0
local lastAudioVol = -1.0
local function setSignalAudio(vol)
  if not (Config.Cinematic and Config.Cinematic.enabled) then return end
  local now = GetGameTimer()
  if (now - lastAudioSendAt) < 180 and math.abs((vol or 0.0) - (lastAudioVol or 0.0)) < 0.03 then
    return
  end
  lastAudioSendAt = now
  lastAudioVol = vol or 0.0
  SendNUIMessage({ type = 'signal_audio', on = (vol or 0.0) > 0.01, vol = math.max(0.0, math.min(1.0, vol or 0.0)) })
end

local function stopCinematicFx()
  
  pcall(function()
    ClearTimecycleModifier()
  end)

  local post = Config.Cinematic and Config.Cinematic.fx and Config.Cinematic.fx.postfx
  if post and AnimpostfxIsRunning(post) then
    pcall(function() AnimpostfxStop(post) end)
  end
  fxPostRunning = false
end

local function applyCinematicFx(strength)
  if not (Config.Cinematic and Config.Cinematic.enabled) then return end

  
  if not strength or strength <= 0.01 then
    if fxPostRunning then stopCinematicFx() end
    return
  end

  local fxCfg = (Config.Cinematic and Config.Cinematic.fx) or {}
  local tc = fxCfg.timecycle
  local maxTc = fxCfg.maxTimecycleStrength or 0.85
  if tc and tc ~= '' then
    
    SetTimecycleModifier(tc)
    SetTimecycleModifierStrength(math.min(maxTc, math.max(0.0, strength * maxTc)))
  end

  
  local post = fxCfg.postfx
  local startAt = fxCfg.postfxStartAt or 0.35
  local stopAt  = fxCfg.postfxStopAt  or 0.20

  if post and strength >= startAt and not AnimpostfxIsRunning(post) then
    pcall(function() AnimpostfxPlay(post, 0, true) end)
    fxPostRunning = true
  elseif post and strength <= stopAt and AnimpostfxIsRunning(post) then
    pcall(function() AnimpostfxStop(post) end)
    fxPostRunning = false
  end
end




local dropTypeIndex = nil

local function buildDropTypeIndex()
  if dropTypeIndex then return dropTypeIndex end
  dropTypeIndex = {}
  if Config.Delivery and type(Config.Delivery.dropTypes) == 'table' then
    for _, t in ipairs(Config.Delivery.dropTypes) do
      if t and t.key then
        dropTypeIndex[tostring(t.key)] = t
      end
    end
  end
  return dropTypeIndex
end

local function getDropTypeDef(typeKey)
  local idx = buildDropTypeIndex()
  return idx[tostring(typeKey or 'crate')]
end

local function playTypeSound(def, which)
  if not def then return end
  local s = def[which]
  if not s then return end
  if s.name and s.set then
    PlaySoundFrontend(-1, s.name, s.set, true)
  end
end

local function playTypeFx(def, x, y, z)
  if not def or not def.fx then return end
  local fx = def.fx
  if not fx.asset or not fx.name then return end

  
  pcall(function()
    RequestNamedPtfxAsset(fx.asset)
    local t0 = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(fx.asset) and (GetGameTimer() - t0) < 800 do
      Wait(0)
    end
    if not HasNamedPtfxAssetLoaded(fx.asset) then return end
    UseParticleFxAssetNextCall(fx.asset)
    local handle = StartParticleFxLoopedAtCoord(
      fx.name,
      x, y, z + 0.15,
      0.0, 0.0, 0.0,
      tonumber(fx.scale) or 0.7,
      false, false, false, false
    )
    SetTimeout(tonumber(fx.durMs) or 1200, function()
      if handle and handle ~= 0 then
        StopParticleFxLooped(handle, false)
      end
    end)
  end)
end

local courierVeh = nil
local courierTargetAdded = false
local courierSpawnedForOrder = nil
local courierHackBusy = false

local function closeUI()
  opened = false
  SetNuiFocus(false, false)
  SendNUIMessage({ type = 'close' })
end

local function openUI()
  opened = true
  SetNuiFocus(true, true)
  SendNUIMessage({ type = 'open' })
end


AddEventHandler('onClientResourceStart', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  
  CreateThread(function()
    Wait(0)
    closeUI()
  end)
end)

AddEventHandler('onResourceStop', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  closeUI()
end)

local function cleanupDrop()
  currentDrop = nil
  currentDropReady = false
  currentOrderId = nil
  crateRevealed = false
  signalStrength = 0.0
  lastBeepAt = 0
  revealDistOverride = nil
  unlockMult = 1.0
  lockStingerPlayed = false
  stopCinematicFx()
  setSignalAudio(0.0)
  courierSpawnedForOrder = nil

  if courierVeh and DoesEntityExist(courierVeh) then
    if GetResourceState('ox_target') == 'started' then
      pcall(function()
        exports.ox_target:removeLocalEntity(courierVeh)
      end)
    end
    DeleteEntity(courierVeh)
  end
  courierVeh = nil
  courierTargetAdded = false

  if dropEntity and DoesEntityExist(dropEntity) then
    
    if GetResourceState('ox_target') == 'started' then
      pcall(function()
        exports.ox_target:removeLocalEntity(dropEntity)
      end)
    end
    DeleteEntity(dropEntity)
  end
  dropEntity = nil

  if dropBlip then RemoveBlip(dropBlip) end
  if dropRadiusBlip then RemoveBlip(dropRadiusBlip) end
  dropBlip, dropRadiusBlip = nil, nil
  
  if courierPed and DoesEntityExist(courierPed) then
    if GetResourceState('ox_target') == 'started' then
      pcall(function() exports.ox_target:removeLocalEntity(courierPed) end)
    end
    DeleteEntity(courierPed)
  end
  courierPed = nil

  if guardPeds and type(guardPeds) == 'table' then
    for _, gp in ipairs(guardPeds) do
      if gp and DoesEntityExist(gp) then
        DeleteEntity(gp)
      end
    end
  end
  guardPeds = {}

end

local function trySetupOxTarget()
  if not Config.Delivery.crate.useOxTarget then return false end
  if GetResourceState('ox_target') ~= 'started' then return false end
  if not dropEntity or not DoesEntityExist(dropEntity) then return false end

  exports.ox_target:addLocalEntity(dropEntity, {
    {
      name = 'gs_bm_collect',
      icon = Config.Delivery.crate.targetIcon or 'fa-solid fa-box',
      label = Config.Delivery.crate.targetLabel or 'Collect Drop',
      distance = 2.0,
      onSelect = function()
        TriggerEvent('gs-blackmarket:client:collectDrop')
      end
    }
  })

  return true
end

local function trySetupCourierTarget()
  if not courierVeh or not DoesEntityExist(courierVeh) then return false end
  if courierTargetAdded then return true end
  if GetResourceState('ox_target') ~= 'started' then return false end

  exports.ox_target:addLocalEntity(courierVeh, {
    {
      name = 'gs_bm_courier_hack',
      icon = 'fa-solid fa-satellite-dish',
      label = 'Hack Courier GPS',
      distance = 2.5,
      onSelect = function()
        TriggerEvent('gs-blackmarket:client:courierHack')
      end
    },
    {
      name = 'gs_bm_courier_disable',
      icon = 'fa-solid fa-ban',
      label = 'Disable Courier Van',
      distance = 2.5,
      onSelect = function()
        TriggerEvent('gs-blackmarket:client:courierDisable')
      end
    }
  })

  courierTargetAdded = true
  return true
end

local function drawSignalHud(strength)
  if not Config.Cinematic or not Config.Cinematic.enabled then return end
  if strength <= 0.01 then return end

  local pct = math.floor(strength * 100.0 + 0.5)
  local bar = math.floor(strength * 10.0 + 0.5)
  if bar < 0 then bar = 0 end
  if bar > 10 then bar = 10 end
  local filled = string.rep('█', bar)
  local empty = string.rep('░', 10 - bar)

  
  local t = GetGameTimer() / 250.0
  local pulse = (math.sin(t) * 0.5 + 0.5)
  local a = 0.06 + (0.14 * strength) * pulse
  DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, math.floor(255 * a))

  
  SetTextFont(4)
  SetTextScale(0.35, 0.35)
  SetTextColour(220, 220, 220, 230)
  SetTextCentre(true)
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(('ENCRYPTED SIGNAL\nLOCK STRENGTH: %s%s  %d%%'):format(filled, empty, pct))
  EndTextCommandDisplayText(0.5, 0.86)

  
  if currentDrop then
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local dx = currentDrop.x - pc.x
    local dy = currentDrop.y - pc.y
    local bearing = GetHeadingFromVector_2d(dx, dy)
    local hdg = GetEntityHeading(ped)
    local diff = (bearing - hdg + 540.0) % 360.0 - 180.0 
    local side = diff >= 0 and 1 or -1
    local amt = math.min(1.0, math.abs(diff) / 90.0)
    local flick = (math.sin(GetGameTimer() / 90.0) * 0.5 + 0.5)
    local baseA = (0.04 + (0.22 * strength * amt)) * (0.45 + 0.55 * flick)
    local a255 = math.floor(255 * math.min(0.35, baseA))

    
    if side < 0 then
      DrawRect(0.075, 0.52, 0.012, 0.22, 80, 255, 220, a255)
    else
      DrawRect(0.925, 0.52, 0.012, 0.22, 255, 200, 60, a255)
    end

    
    local arrow = '▲'
    if math.abs(diff) < 10.0 then
      arrow = '▲'
    elseif side < 0 then
      arrow = '◀'
    else
      arrow = '▶'
    end
    SetTextFont(4)
    SetTextScale(0.40, 0.40)
    SetTextColour(240, 240, 245, 210)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(arrow)
    EndTextCommandDisplayText(0.5, 0.905)
  end
end





local function resolveSafeDrop(drop)
  if type(drop) ~= 'table' then return drop end

  
  local out = {}
  for k, v in pairs(drop) do out[k] = v end

  
  out.mode = 'courier'

  local x = tonumber(out.x) or 0.0
  local y = tonumber(out.y) or 0.0
  local z = tonumber(out.z) or 0.0

  
  local function isInterior(px, py, pz)
    local interior = 0
    pcall(function() interior = GetInteriorAtCoords(px, py, pz) end)
    return interior and interior ~= 0
  end

  local function snapToGround(px, py, pz)
    
    pcall(function() RequestCollisionAtCoord(px, py, pz) end)
    local found, groundZ = false, nil
    pcall(function()
      found, groundZ = GetGroundZFor_3dCoord(px, py, pz + 60.0, false)
    end)
    if found and type(groundZ) == 'number' then
      return groundZ + 0.15
    end
    return nil
  end

  local function getSafeCoord(px, py, pz)
    
    local ok, a, b, c, d = pcall(function()
      return GetSafeCoordForPed(px, py, pz, false, 16)
    end)
    if not ok then return nil end

    
    if type(a) == 'vector3' then
      return a.x, a.y, a.z
    end

    
    if type(a) == 'boolean' and a == true and type(b) == 'vector3' then
      return b.x, b.y, b.z
    end

    
    if type(a) == 'boolean' and a == true and type(b) == 'number' and type(c) == 'number' and type(d) == 'number' then
      return b, c, d
    end

    return nil
  end

  local function accept(px, py, pz)
    if isInterior(px, py, pz) then return false end
    local gz = snapToGround(px, py, pz)
    if not gz then return false end
    
    if math.abs(gz - z) > 35.0 then return false end
    return true, px, py, gz
  end

  
  local radii = { 0.0, 2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 22.0, 30.0 }
  local angles = { 0, 45, 90, 135, 180, 225, 270, 315 }

  for _, r in ipairs(radii) do
    for _, a in ipairs(angles) do
      local rad = a * 0.017453292519943295
      local cx = x + (math.cos(rad) * r)
      local cy = y + (math.sin(rad) * r)
      local cz = z

      
      local sx, sy, sz = getSafeCoord(cx, cy, cz)
      if sx and sy and sz then
        local ok2, ax, ay, az = accept(sx, sy, sz)
        if ok2 then
          out.x, out.y, out.z = ax, ay, az
          return out
        end
      end

      
      local ok3, ax, ay, az = accept(cx, cy, cz)
      if ok3 then
        out.x, out.y, out.z = ax, ay, az
        return out
      end
    end
  end

  
  pcall(function()
    local found, nodePos = GetClosestVehicleNode(x, y, z, 1, 3.0, 0)
    if found and type(nodePos) == 'vector3' and not isInterior(nodePos.x, nodePos.y, nodePos.z) then
      local gz = snapToGround(nodePos.x, nodePos.y, nodePos.z) or nodePos.z
      out.x, out.y, out.z = nodePos.x, nodePos.y, gz
    end
  end)

  return out
end


local function cinematicRevealFx()
  if not Config.Cinematic or not Config.Cinematic.enabled then return end
  local ms = (Config.Cinematic.revealFx and Config.Cinematic.revealFx.flashMs) or 180
  DoScreenFadeOut(ms)
  Wait(ms)
  DoScreenFadeIn(ms)

  
  pcall(function()
    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_amb_smoke_foundry', currentDrop.x, currentDrop.y, currentDrop.z + 0.2, 0.0, 0.0, 0.0, 0.8, false, false, false)
  end)
end

local function spawnCourierVan(drop)
  if not Config.Cinematic or not Config.Cinematic.courier or not Config.Cinematic.courier.enabled then return end
  if courierSpawnedForOrder == currentOrderId then return end
  courierSpawnedForOrder = currentOrderId

  local modelName = Config.Cinematic.courier.model or 'speedo'
  local model = joaat(modelName)
  RequestModel(model)
  while not HasModelLoaded(model) do Wait(10) end

  local minD = Config.Cinematic.courier.spawnDistanceMin or 35.0
  local maxD = Config.Cinematic.courier.spawnDistanceMax or 70.0
  local ang = math.random() * math.pi * 2.0
  local dist = minD + math.random() * (maxD - minD)
  local sx = drop.x + math.cos(ang) * dist
  local sy = drop.y + math.sin(ang) * dist
  local sz = drop.z + 2.0
  local found, gz = GetGroundZFor_3dCoord(sx, sy, sz, false)
  if found then sz = gz end

  courierVeh = CreateVehicle(model, sx, sy, sz, math.random(0, 359) + 0.0, false, false)
  SetEntityAsMissionEntity(courierVeh, true, true)
  SetVehicleDoorsLocked(courierVeh, 2)
  SetVehicleEngineOn(courierVeh, true, true, false)
  SetVehicleLights(courierVeh, 2)
  SetVehicleEngineCanDegrade(courierVeh, false)

  trySetupCourierTarget()

  
  local ttl = Config.Cinematic.courier.despawnAfterMs or 60000
  CreateThread(function()
    local my = courierVeh
    Wait(ttl)
    if my and DoesEntityExist(my) then
      if GetResourceState('ox_target') == 'started' then
        pcall(function()
          exports.ox_target:removeLocalEntity(my)
        end)
      end
      DeleteEntity(my)
    end
    if courierVeh == my then courierVeh = nil end
    courierTargetAdded = false
  end)
end

local function notifyOrdersUpdated(orderId, status)
  SendNUIMessage({ type = 'order_update', orderId = orderId, status = status })
end

local function createDropBlips(cfgUI, drop)
  
  if dropRadiusBlip then RemoveBlip(dropRadiusBlip) end
  dropRadiusBlip = nil
  if dropBlip then RemoveBlip(dropBlip) end
  dropBlip = nil

  if cfgUI and cfgUI.blipMode == 'none' then return end

  dropBlip = AddBlipForCoord(drop.x, drop.y, drop.z)
  SetBlipSprite(dropBlip, 568)
  SetBlipScale(dropBlip, (cfgUI and cfgUI.blipScaleExact) or 0.9)
  SetBlipAsShortRange(dropBlip, false)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString('Dead Drop')
  EndTextCommandSetBlipName(dropBlip)

  
  SetBlipRoute(dropBlip, true)
end

local function createAreaPingBlips(cfgUI, drop)
  
  if dropRadiusBlip then RemoveBlip(dropRadiusBlip) end
  if dropBlip then RemoveBlip(dropBlip) end

  dropRadiusBlip = nil
  dropBlip = AddBlipForCoord(drop.x, drop.y, drop.z)
  SetBlipSprite(dropBlip, 568)
  SetBlipScale(dropBlip, 0.70)
  SetBlipAsShortRange(dropBlip, false)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString('Drop')
  EndTextCommandSetBlipName(dropBlip)

  
  if cfgUI and cfgUI.routePing then
    SetBlipRoute(dropBlip, true)
  else
    SetBlipRoute(dropBlip, false)
  end
end

local function spawnCrate(drop)
  local def = getDropTypeDef(drop and drop.type)
  local prop = (def and def.prop) or (Config.Delivery and Config.Delivery.crate and Config.Delivery.crate.prop) or 'prop_box_wood02a_pu'
  local model = joaat(prop)
  RequestModel(model)
  while not HasModelLoaded(model) do Wait(10) end

  
  dropEntity = CreateObject(model, drop.x, drop.y, (drop.z or 0.0) + 1.25, false, false, false)
  SetEntityHeading(dropEntity, drop.heading or 0.0)
  SetEntityAsMissionEntity(dropEntity, true, true)

  pcall(function()
    RequestCollisionAtCoord(drop.x, drop.y, drop.z)
    PlaceObjectOnGroundProperly(dropEntity)
  end)

  
  pcall(function()
    local ex, ey, ez = table.unpack(GetEntityCoords(dropEntity))
    local found, groundZ = GetGroundZFor_3dCoord(ex, ey, ez + 50.0, false)
    if found and type(groundZ) == 'number' and ez < (groundZ - 0.35) then
      SetEntityCoordsNoOffset(dropEntity, ex, ey, groundZ + 0.15, false, false, false)
      PlaceObjectOnGroundProperly(dropEntity)
    end
  end)

  FreezeEntityPosition(dropEntity, true)

  
  if Config.Cinematic and Config.Cinematic.enabled then
    SetEntityAlpha(dropEntity, 0, false)
  end
end

local function spawnCourier(drop)
  local cfg = (Config.Delivery and Config.Delivery.codeCourier) or {}
  local pedModel = cfg.pedModel or 'g_m_y_mexgoon_02'
  local model = joaat(pedModel)
  RequestModel(model)
  while not HasModelLoaded(model) do Wait(10) end

  
  local sx, sy, sz = drop.x, drop.y, (drop.z or 0.0)

  
  
  local useFixed = (Config.Delivery and Config.Delivery.useFixedDrops and type(Config.Delivery.fixedDrops) == 'table' and #Config.Delivery.fixedDrops > 0)
  if not useFixed then
    pcall(function()
      RequestCollisionAtCoord(sx, sy, sz)
      local found, gz = GetGroundZFor_3dCoord(sx, sy, sz + 50.0, false)
      if found and type(gz) == 'number' then sz = gz + 0.05 end
    end)
  end

  courierPed = CreatePed(4, model, sx, sy, sz, drop.heading or 0.0, false, false)
  SetEntityAsMissionEntity(courierPed, true, true)
  SetBlockingOfNonTemporaryEvents(courierPed, true)
  SetPedFleeAttributes(courierPed, 0, false)
  SetPedCanRagdoll(courierPed, false)
  FreezeEntityPosition(courierPed, true)

  if cfg.invincible ~= false then
    SetEntityInvincible(courierPed, true)
  end

  pcall(function()
    TaskStartScenarioInPlace(courierPed, cfg.scenario or 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
  end)

  if GetResourceState('ox_target') == 'started' and (cfg.useOxTarget ~= false) then
    exports.ox_target:addLocalEntity(courierPed, {
      {
        icon = cfg.targetIcon or 'fa-solid fa-key',
        label = cfg.targetLabel or 'Enter Drop Code',
        distance = cfg.targetDistance or 2.0,
        onSelect = function()
          if not currentDrop or not currentOrderId then return end

          
          local now = GetGameTimer()
          if (now - (lastCollectAt or 0)) < 750 then return end
          lastCollectAt = now

          local want = tostring(currentDrop.code or '')
          if want == '' then
            SendNUIMessage({ type = 'toast', text = 'No code assigned yet.' })
            return
          end

          local input = nil
          if lib and lib.inputDialog then
            input = lib.inputDialog('Courier Verification', {
              { type = 'input', label = 'Code', description = 'Enter the 6-digit code', required = true, min = 4, max = 12 }
            })
          end
          local got = input and input[1] and tostring(input[1]) or ''
          got = got:gsub('%s+', '')
          if got == '' then return end

          
          pendingCourierCode = got
          TriggerEvent('gs-blackmarket:client:collectDrop')
        end,
      }
    })
  end
end

local function spawnGuards(drop)
  local gcfg = (Config.Delivery and Config.Delivery.guards) or {}
  if not gcfg.enabled then return end
  if guardPeds and #guardPeds > 0 then return end

  local count = tonumber(gcfg.count or 0) or 0
  if count <= 0 then return end

  local models = gcfg.models or { 'g_m_y_lost_01', 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02' }
  local weapon = gcfg.weapon or 'WEAPON_PISTOL'
  local radius = tonumber(gcfg.radius or 10.0) or 10.0

  local relGroup = gcfg.relationshipGroup or 'BM_GUARDS'
  AddRelationshipGroup(relGroup)
  SetRelationshipBetweenGroups(5, joaat(relGroup), joaat('PLAYER'))
  SetRelationshipBetweenGroups(5, joaat('PLAYER'), joaat(relGroup))

  for i=1, count do
    local m = models[((i-1) % #models) + 1]
    local model = joaat(m)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local ox = (math.random() - 0.5) * 2.0 * radius
    local oy = (math.random() - 0.5) * 2.0 * radius
    local x = drop.x + ox
    local y = drop.y + oy
    local z = (drop.z or 0.0)
    pcall(function()
      RequestCollisionAtCoord(x, y, z)
      local found, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
      if found and type(gz) == 'number' then z = gz + 0.05 end
    end)

    local ped = CreatePed(4, model, x, y, z, math.random(0, 359) + 0.0, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, joaat(relGroup))
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 1)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, tonumber(gcfg.accuracy or 35) or 35)
    SetPedArmour(ped, tonumber(gcfg.armor or 40) or 40)
    SetPedAsEnemy(ped, true)
    GiveWeaponToPed(ped, joaat(weapon), 250, false, true)
    TaskCombatPed(ped, PlayerPedId(), 0, 16)

    table.insert(guardPeds, ped)
  end
end


local function revealCrateIfNeeded()
  if crateRevealed then return end
  if not currentDrop then return end
  if not currentDropReady then return end

  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local dist = #(coords - vector3(currentDrop.x, currentDrop.y, currentDrop.z))

  local revealDist = revealDistOverride or ((Config.Delivery and Config.Delivery.revealDistance) or 65.0)
  if dist <= revealDist then
    crateRevealed = true
    
    spawnCourier(currentDrop)
    spawnGuards(currentDrop)

    local def = getDropTypeDef(currentDrop.type)
    cinematicRevealFx()
    playTypeSound(def, 'revealSound')
    playTypeFx(def, currentDrop.x, currentDrop.y, currentDrop.z)

    
    local cfg = lib.callback.await('gs-blackmarket:server:getConfig', false)
    createDropBlips(cfg.ui, currentDrop)
	    if dropEntity and DoesEntityExist(dropEntity) then
	      trySetupOxTarget()
	      
	      for a = 0, 255, 25 do
	        if not dropEntity or not DoesEntityExist(dropEntity) then break end
	        SetEntityAlpha(dropEntity, a, false)
	        Wait(28)
	      end
	      if dropEntity and DoesEntityExist(dropEntity) then
	        ResetEntityAlpha(dropEntity)
	      end
	    end

    SendNUIMessage({ type = 'toast', text = 'Signal locked. Drop revealed.' })
  end
end

RegisterNetEvent('gs-blackmarket:client:courierHack', function()
  if courierHackBusy then return end
  if not currentDrop then return end
  courierHackBusy = true

  local courierCfg = (Config.Cinematic and Config.Cinematic.courier) or {}
  local tapMs    = courierCfg.tapTimeMs or 3000
  local decMs    = courierCfg.decryptTimeMs or 5200
  local spoofMs  = courierCfg.spoofTimeMs or 2400

  local function phase(title, sub, ms, label)
    SendNUIMessage({ type = 'hack_phase', title = title, sub = sub, ms = ms })
    SendNUIMessage({ type = 'decrypt_audio', on = true, ms = ms })

    local ok = true
    if lib and lib.progressCircle then
      ok = lib.progressCircle({
        duration = ms,
        position = 'bottom',
        label = label or title,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop' },
      })
    else
      Wait(ms)
    end
    return ok
  end

  
  local ok = phase('TAPPING INTO COURIER FREQUENCY…', 'Locking onto the carrier wave.', tapMs, 'Tapping frequency…')
  if not ok then
    SendNUIMessage({ type = 'hack_end' })
    SendNUIMessage({ type = 'decrypt_audio', on = false })
    SendNUIMessage({ type = 'toast', text = 'Hack canceled.' })
    courierHackBusy = false
    return
  end

  
  ok = phase('DECRYPTING ENCRYPTED GPS ROUTE…', 'Stabilize. Noise is expected.', decMs, 'Decrypting route…')
  if not ok then
    SendNUIMessage({ type = 'hack_end' })
    SendNUIMessage({ type = 'decrypt_audio', on = false })
    SendNUIMessage({ type = 'toast', text = 'Hack canceled.' })
    courierHackBusy = false
    return
  end

  
  ok = phase('SPOOFING DELIVERY BEACON…', 'Injecting spoof payload.', spoofMs, 'Spoofing beacon…')
  SendNUIMessage({ type = 'hack_end' })
  SendNUIMessage({ type = 'decrypt_audio', on = false })

  if not ok then
    SendNUIMessage({ type = 'toast', text = 'Hack canceled.' })
    courierHackBusy = false
    return
  end

  
  unlockMult = math.min(unlockMult or 1.0, courierCfg.unlockMultAfterSpoof or 0.5)
  revealDistOverride = ((Config.Delivery and Config.Delivery.revealDistance) or 65.0) + (courierCfg.revealBonusMeters or 35.0)

  
  if dropBlip then RemoveBlip(dropBlip) end
  if dropRadiusBlip then RemoveBlip(dropRadiusBlip) end
  dropBlip, dropRadiusBlip = nil, nil
  createDropBlips({ blipMode = 'exact' }, currentDrop)

  
  PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
  SendNUIMessage({ type = 'decrypt_success' })
  pcall(function()
    local post = Config.Cinematic and Config.Cinematic.fx and Config.Cinematic.fx.postfx
    if post and not AnimpostfxIsRunning(post) then
      AnimpostfxPlay(post, 250, false)
      SetTimeout(260, function()
        if post and AnimpostfxIsRunning(post) then AnimpostfxStop(post) end
      end)
    end
  end)
  SendNUIMessage({ type = 'toast', text = 'Beacon spoofed. Exact drop marked.' })

  
  if courierVeh and DoesEntityExist(courierVeh) then
    pcall(function()
      SetVehicleLights(courierVeh, 1)
      SetVehicleEngineOn(courierVeh, false, true, true)
    end)
    Wait(650)
    if GetResourceState('ox_target') == 'started' then
      pcall(function() exports.ox_target:removeLocalEntity(courierVeh) end)
    end
    DeleteEntity(courierVeh)
  end
  courierVeh = nil
  courierTargetAdded = false
  courierHackBusy = false
end)

RegisterNetEvent('gs-blackmarket:client:courierDisable', function()
  if courierVeh and DoesEntityExist(courierVeh) then
    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if GetResourceState('ox_target') == 'started' then
      pcall(function()
        exports.ox_target:removeLocalEntity(courierVeh)
      end)
    end
    DeleteEntity(courierVeh)
  end
  courierVeh = nil
  courierTargetAdded = false
  SendNUIMessage({ type = 'toast', text = 'Courier van disabled.' })
end)

RegisterNetEvent('gs-blackmarket:client:openTablet', function()
  if Config.Inventory.requireTabletItem then
    
    
    local has = lib.callback.await('gs-blackmarket:server:getAccountState', false)
    
  end

  openUI()
end)

RegisterNUICallback('bm_close', function(_, cb)
  closeUI()
  cb(true)
end)

RegisterNUICallback('bm_getBoot', function(_, cb)
  local cfg = lib.callback.await('gs-blackmarket:server:getConfig', false)
  local state = lib.callback.await('gs-blackmarket:server:getAccountState', false)
  local catalog = lib.callback.await('gs-blackmarket:server:getCatalog', false)

  
  local active = lib.callback.await('gs-blackmarket:server:getActiveDrop', false)
  if active and active.orderId and active.drop then
    
    cleanupDrop()
    currentOrderId = active.orderId
    currentDrop = resolveSafeDrop(active.drop)
    crateRevealed = false
    
  end

  cb({ cfg = cfg, state = state, catalog = catalog })
end)


RegisterNUICallback('bm_pingArea', function(data, cb)
  local orderId = tonumber(data and data.orderId or 0)
  local cfg = lib.callback.await('gs-blackmarket:server:getConfig', false)

  local res = nil
  if not orderId or orderId <= 0 then
    SendNUIMessage({ type = 'toast', text = 'Select an order first.' })
    cb({ ok = false, err = 'no_order' })
    return
  end

  res = lib.callback.await('gs-blackmarket:server:getDropForOrder', false, orderId)

  if not res or not res.drop then
    SendNUIMessage({ type = 'toast', text = 'No drop assigned yet.' })
    cb({ ok = false })
    return
  end

  
  currentOrderId = res.orderId
  currentDrop = resolveSafeDrop(res.drop)
  crateRevealed = false

  createAreaPingBlips(cfg.ui, currentDrop)
  spawnCourierVan(currentDrop)
  SendNUIMessage({ type = 'toast', text = 'Area pinged. Get close to lock the signal.' })
  cb({ ok = true })
end)

RegisterNUICallback('bm_register', function(data, cb)
  local res = lib.callback.await('gs-blackmarket:server:register', false, data)
  cb(res)
end)

RegisterNUICallback('bm_login', function(data, cb)
  local res = lib.callback.await('gs-blackmarket:server:login', false, data)
  cb(res)
end)

RegisterNUICallback('bm_changeAlias', function(data, cb)
  local res = lib.callback.await('gs-blackmarket:server:changeAlias', false, data)
  cb(res)
end)

RegisterNUICallback('bm_changePassword', function(data, cb)
  local res = lib.callback.await('gs-blackmarket:server:changePassword', false, data)
  cb(res)
end)

RegisterNUICallback('bm_listOrders', function(_, cb)
  local orders = lib.callback.await('gs-blackmarket:server:listOrders', false)
  cb(orders or {})
end)

RegisterNUICallback('bm_createOrder', function(data, cb)
  local res = lib.callback.await('gs-blackmarket:server:createOrder', false, data)
  cb(res)
end)

RegisterNUICallback('bm_cancelOrder', function(data, cb)
  local orderId = tonumber(data and data.orderId)
  if not orderId then cb({ ok = false, err = 'Invalid order.' }) return end

  local res = lib.callback.await('gs-blackmarket:server:cancelOrder', false, orderId)
  if res and res.ok then
    
    if currentOrderId and tonumber(currentOrderId) == orderId then
      cleanupDrop()
    end
    notifyOrdersUpdated(orderId, 'canceled')
    cb({ ok = true })
  else
    cb({ ok = false, err = (res and res.err) or 'Cancel failed.' })
  end
end)

RegisterNetEvent('gs-blackmarket:client:orderReady', function(orderId, drop)
  cleanupDrop()
  currentOrderId = orderId
  currentDrop = resolveSafeDrop(drop)
  currentDropReady = true
  crateRevealed = false

  local cfg = lib.callback.await('gs-blackmarket:server:getConfig', false)
  SendNUIMessage({ type = 'toast', text = 'Order dispatched. Drop is ready.' })

  
  
  
  notifyOrdersUpdated(orderId, 'ready')
end)

RegisterNetEvent('gs-blackmarket:client:orderStatus', function(orderId, status, drop)
  status = tostring(status or '')
  if status ~= '' then
    notifyOrdersUpdated(orderId, status)
  end

  if status == 'processing' then
    SendNUIMessage({ type = 'toast', text = 'Order processing…' })
  elseif status == 'dispatched' then
    SendNUIMessage({ type = 'toast', text = 'Courier dispatched.' })
    if drop then
      currentOrderId = orderId
      currentDrop = resolveSafeDrop(drop)
      currentDropReady = false
      crateRevealed = false
      
    end
  elseif status == 'en_route' then
    SendNUIMessage({ type = 'toast', text = 'Courier en route…' })
  end
end)

RegisterNetEvent('gs-blackmarket:client:collectDrop', function()
  if collecting then return end
  collecting = true
  local function doneCollect()
    collecting = false
  end

  if not currentOrderId or not currentDrop then doneCollect(); return end
  local isCourier = true 

  
  
  
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  if courierPed and DoesEntityExist(courierPed) then
    local ccoords = GetEntityCoords(courierPed)
    local dist = #(coords - ccoords)
    local cfg = (Config.Delivery and Config.Delivery.codeCourier) or {}
    local maxDist = (cfg.targetDistance or 2.0) + 1.6
    if dist > maxDist then
      SendNUIMessage({ type = 'toast', text = 'Get closer to the courier.' })
      if lib and lib.notify then lib.notify({ title = 'BlackMarket', description = 'Get closer to the courier.', type = 'error' }) end
      doneCollect();
      return
    end
  end

  
  
  local enteredCode = nil
  if isCourier then
    
    if pendingCourierCode and pendingCourierCode ~= '' then
      enteredCode = tostring(pendingCourierCode)
      pendingCourierCode = nil
    else
      if lib and lib.inputDialog then
        local res = lib.inputDialog('Courier Verification', {
          { type = 'input', label = 'Enter Code', description = '6-digit handoff code', icon = 'hashtag', required = true },
        })
        if not res or not res[1] then
          SendNUIMessage({ type = 'toast', text = 'Canceled.' })
          doneCollect();
          return
        end
        enteredCode = tostring(res[1] or '')
      else
        
        SendNUIMessage({ type = 'toast', text = 'Code entry requires ox_lib.' })
        doneCollect();
        return
      end
    end
  end
  
  local def = getDropTypeDef(currentDrop and currentDrop.type)
  local baseMs = (def and def.unlockTimeMs) or (Config.Delivery and Config.Delivery.crate and Config.Delivery.crate.unlockTimeMs) or 6500
  local unlockMs = math.floor(baseMs * (unlockMult or 1.0) + 0.5)
  local did = true
  if lib and lib.progressCircle then
    did = lib.progressCircle({
      duration = unlockMs,
      position = 'bottom',
      label = (isCourier and 'Verifying code…' or 'Unlocking drop…'),
      useWhileDead = false,
      canCancel = true,
      disable = { move = true, car = true, combat = true },
      anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    })
  else
    Wait(unlockMs)
  end

  if not did then
    SendNUIMessage({ type = 'toast', text = 'Canceled.' })
    doneCollect();
    return
  end

  playTypeSound(def, 'unlockSound')

  local res = lib.callback.await('gs-blackmarket:server:claimOrder', false, currentOrderId, enteredCode)
  if res and res.ok then
    SendNUIMessage({ type = 'toast', text = 'Drop collected.' })
    local oid = currentOrderId
    cleanupDrop()
    notifyOrdersUpdated(oid, 'claimed')
    doneCollect();
  else
    SendNUIMessage({ type = 'toast', text = res.err or 'Failed to collect.' })
    doneCollect();
  end
end)


RegisterNetEvent('gs-blackmarket:client:orderClaimed', function(orderId)
  
  if currentOrderId and tonumber(currentOrderId) == tonumber(orderId) then
    cleanupDrop()
  else
    
    if dropEntity and DoesEntityExist(dropEntity) then
      if GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeLocalEntity(dropEntity) end)
      end
      DeleteEntity(dropEntity)
    end
    dropEntity = nil

    if dropBlip then RemoveBlip(dropBlip) end
    if dropRadiusBlip then RemoveBlip(dropRadiusBlip) end
    dropBlip, dropRadiusBlip = nil, nil
  end

  
  notifyOrdersUpdated(orderId, 'claimed')
end)

RegisterNetEvent('gs-blackmarket:client:orderCanceled', function(orderId)
  if currentOrderId and tonumber(currentOrderId) == tonumber(orderId) then
    cleanupDrop()
  end
  notifyOrdersUpdated(orderId, 'canceled')
end)


CreateThread(function()
  while true do
    Wait(120)
    if currentDrop and currentOrderId and not crateRevealed then
      local ped = PlayerPedId()
      local coords = GetEntityCoords(ped)
      local dist = #(coords - vector3(currentDrop.x, currentDrop.y, currentDrop.z))

      local r = (Config.Cinematic and Config.Cinematic.signal and Config.Cinematic.signal.radiusMeters)
      r = r or (Config.UI and Config.UI.pingRadiusMeters) or 140.0
      if dist <= r then
        signalStrength = math.max(0.0, math.min(1.0, 1.0 - (dist / r)))

        
        local aCfg = (Config.Cinematic and Config.Cinematic.signal and Config.Cinematic.signal.audio) or {}
        local minV = aCfg.minVol or 0.04
        local maxV = aCfg.maxVol or 0.22
        setSignalAudio(minV + (maxV - minV) * signalStrength)

        
        applyCinematicFx(signalStrength)

        
        if signalStrength >= 0.995 and not lockStingerPlayed then
          lockStingerPlayed = true
          local st = Config.Cinematic and Config.Cinematic.revealFx and Config.Cinematic.revealFx.lockStinger
          if st and st.name and st.set then
            PlaySoundFrontend(-1, st.name, st.set, true)
          end
          SendNUIMessage({ type = 'toast', text = 'SIGNAL LOCK ACQUIRED' })
        end

        local now = GetGameTimer()
        local beepCfg = (Config.Cinematic and Config.Cinematic.signal and Config.Cinematic.signal.beep) or {}
        local maxI = beepCfg.maxIntervalMs or 1200
        local minI = beepCfg.minIntervalMs or 120
        local interval = math.floor(maxI - (maxI - minI) * signalStrength)
        if now - lastBeepAt >= interval then
          lastBeepAt = now
          PlaySoundFrontend(-1, beepCfg.soundName or 'NAV_UP_DOWN', beepCfg.soundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
      else
        signalStrength = 0.0
        lockStingerPlayed = false
        stopCinematicFx()
        setSignalAudio(0.0)
      end

      revealCrateIfNeeded()
    else
      signalStrength = 0.0
      lockStingerPlayed = false
      stopCinematicFx()
      setSignalAudio(0.0)
      Wait(250)
    end
  end
end)


CreateThread(function()
  while true do
    Wait(0)
    if currentDrop and currentOrderId and not crateRevealed then
      drawSignalHud(signalStrength)
    else
      Wait(250)
    end
  end
end)


CreateThread(function()
  while true do
    Wait(0)
    
    if currentDrop and currentOrderId and crateRevealed and (not courierPed or not DoesEntityExist(courierPed)) and (GetResourceState('ox_target') ~= 'started' or not Config.Delivery.crate.useOxTarget) then
      local ped = PlayerPedId()
      local coords = GetEntityCoords(ped)
      local dist = #(coords - vector3(currentDrop.x, currentDrop.y, currentDrop.z))
      if dist <= (Config.Delivery.crate.pickupDistance or 2.0) + 0.3 then
        
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to collect drop')
        EndTextCommandDisplayHelp(0, false, false, 1)
        if IsControlJustPressed(0, Config.Delivery.crate.interactKey or 38) then
          TriggerEvent('gs-blackmarket:client:collectDrop')
        end
      end
    else
      Wait(250)
    end
  end
end)


CreateThread(function()
  while true do
    Wait(0)
    if opened and IsControlJustPressed(0, 322) then
      closeUI()
    else
      Wait(50)
    end
  end
end)
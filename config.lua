Config = {}

Config.Framework = {
  
  mode = 'auto',
}

Config.Inventory = {
  
  mode = 'auto',
  
  requireTabletItem = true,
  tabletItemName = 'blackmarket_tablet',
}

Config.Images = {
  
  mode = 'auto',
  oxPath = 'nui://ox_inventory/web/images/',
  qbPath = 'nui://qb-inventory/html/images/',
}

Config.UI = {
  allowCommandOpen = false,
  blipMode = 'exact',
  radiusMeters = 120.0,
  pingRadiusMeters = 140.0,
  theme = {
    accent = '#9b5cff',
    accent2 = '#22d3ee',
    glass = true,
  }
}

Config.Accounts = {
  enablePIN = false,                 
  allowMultipleAliases = false,       
  minUsernameLen = 3,
  maxUsernameLen = 18,
  minPasswordLen = 4,
  maxPasswordLen = 64,
  minAliasLen = 3,
  maxAliasLen = 20,
  aliasChangeCooldownHours = 72,      
}

Config.Orders = {
  minTotal = 250,                    
  cooldownSeconds = 20,              
  maxActiveAgeHours = 6,            
  cancelPolicy = 'fullBeforeDispatch', 
  deliveryFee = {
    mode = 'flat',                   
    flat = 150,
    percent = 0.05,
    min = 50,
    max = 2500,
  },
  
  processingDelaySeconds = {         
    min = 8,
    max = 18,
  },
  enRouteDelaySeconds = {            
    min = 12,
    max = 28,
  },

  
  dispatchDelaySeconds = {
    min = 10,
    max = 25,
  },
}

Config.Payment = {
  
  allowed = { 'cash', 'bank' },

  
  enableCryptoItem = false,
  cryptoItemName = 'bm_crypto',
}

Config.Delivery = { 
  types = { 'courier' },
  useFixedDrops = true,
  fixedDrops = {
    vec4(2048.78, 3205.02, 44.19, 187.09),
    vec4(677.63, 589.61, 129.46, 240.34),
    vec4(-903.98, -362.49, 37.96, 311.70),
    vec4(202.69, -2203.75, 4.95, 26.96),
    vec4(-1610.81, -1045.38, 4.99, 140.04),
  },
  
  dropTypes = {
    {
      key = 'crate',
      label = 'Wood Crate',
      prop = 'prop_box_wood02a_pu',
      unlockTimeMs = 6500,
      revealSound = { name = 'ATM_WINDOW', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
      unlockSound = { name = 'PIN_BUTTON', set = 'ATM_SOUNDS' },
      fx = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 0.7, durMs = 1400 },
    },
    {
      key = 'duffel',
      label = 'Duffel Bag',
      prop = 'prop_cs_heist_bag_02',
      unlockTimeMs = 4500,
      revealSound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
      unlockSound = { name = 'CONFIRM_BEEP', set = 'HUD_MINI_GAME_SOUNDSET' },
      fx = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 0.5, durMs = 900 },
    },
    {
      key = 'dumpster',
      label = 'Dumpster Stash',
      prop = 'prop_dumpster_01a',
      unlockTimeMs = 8200,
      revealSound = { name = 'TIMER_STOP', set = 'HUD_MINI_GAME_SOUNDSET' },
      unlockSound = { name = 'HACKING_SUCCESS', set = 'HUD_MINI_GAME_SOUNDSET' },
      fx = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 0.9, durMs = 1700 },
    },
    {
      key = 'toolbox',
      label = 'Toolbox',
      prop = 'prop_tool_box_04',
      unlockTimeMs = 5200,
      revealSound = { name = 'NAV_UP_DOWN', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
      unlockSound = { name = 'OK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
      fx = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 0.55, durMs = 1000 },
    },
    {
      key = 'rooftop',
      label = 'Rooftop Bag',
      prop = 'prop_cs_heist_bag_02',
      unlockTimeMs = 7200,
      revealSound = { name = 'FocusIn', set = 'HintCamSounds' },
      unlockSound = { name = 'FocusOut', set = 'HintCamSounds' },
      fx = { asset = 'core', name = 'exp_grd_grenade_smoke', scale = 0.75, durMs = 1400 },
    },
  },
  dropPools = {
    city = {
      { x =  123.1, y = -1034.8, z = 29.3, heading = 250.0, label = 'Alley Drop' },
      { x = -560.7, y =  282.9, z = 82.2, heading =  90.0, label = 'Parking Corner' },
      { x =  821.6, y = -233.5, z = 66.0, heading = 180.0, label = 'Underpass' },
    },
    desert = {
      { x =  1688.2, y =  3292.6, z = 41.1, heading =  10.0, label = 'Dusty Pull-off' },
      { x =  2583.3, y =  463.2,  z = 108.6, heading =  0.0, label = 'Scrub Drop' },
    }
  },

  poolMode = 'mixed',                
  minDistanceFromPlayer = 600.0,     
  maxAttempts = 25,
  revealDistance = 65.0,
  crate = {
    prop = 'prop_box_wood02a_pu',
    pickupDistance = 2.0,
    interactKey = 38,                
    useOxTarget = true,              
    targetLabel = 'Collect Drop',
    targetIcon = 'fa-solid fa-box',
    unlockTimeMs = 6500,
  }
}

Config.Cinematic = {
  enabled = true,
  
  signal = {
    
    radiusMeters = nil, 
    beep = {
      soundName = 'NAV_UP_DOWN',
      soundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
      maxIntervalMs = 1200,
      minIntervalMs = 120,
    },
    
    audio = {
      minVol = 0.04,
      maxVol = 0.22,
    },
  },
  
  fx = {   
    timecycle = 'MP_Bull_t',
    postfx = 'DrugsTrevorClownsFight',
    postfxStartAt = 0.35,
    postfxStopAt  = 0.20,
    maxTimecycleStrength = 0.85,
  },
  
  revealFx = {
    flashMs = 180,
    lockStinger = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
  },
  
  courier = {
    enabled = true,
    model = 'speedo',
    spawnDistanceMin = 35.0,
    spawnDistanceMax = 70.0,
    despawnAfterMs = 60000,
    hackTimeMs = 4200,
  }
}




Config.Vendors = {
  {
    id = 'tools',
    label = 'Tools & Utilities',
    icon = 'tool',
    priceMultiplier = 1.0,
    enabled = true,
  },
  {
    id = 'electronics',
    label = 'Electronics',
    icon = 'chip',
    priceMultiplier = 1.0,
    enabled = true,
  },
  {
    id = 'medical',
    label = 'Medical',
    icon = 'med',
    priceMultiplier = 1.0,
    enabled = true,
  },
  {
    id = 'parts',
    label = 'Weapon Parts / Ammo',
    icon = 'bolt',
    priceMultiplier = 1.0,
    enabled = true,
  },
  {
    id = 'weapons',
    label = 'Weapons',
    icon = 'gun',
    priceMultiplier = 1.0,
    enabled = true,
  },

}



Config.Catalog = {
  
  { name = 'lockpick',       label = 'Lockpick',            price = 250,  vendor = 'tools',       category = 'tools',      icon = 'lock' },
  { name = 'advancedlockpick',label= 'Advanced Lockpick',   price = 850,  vendor = 'tools',       category = 'tools',      icon = 'lock' },
  { name = 'repairkit',      label = 'Repair Kit',          price = 450,  vendor = 'tools',       category = 'tools',      icon = 'wrench' },
  { name = 'drill',          label = 'Compact Drill',       price = 1200, vendor = 'tools',       category = 'tools',      icon = 'drill' },

  
  { name = 'phone',          label = 'Burner Phone',        price = 300,  vendor = 'electronics', category = 'electronics', icon = 'phone' },
  { name = 'radio',          label = 'Encrypted Radio',     price = 950,  vendor = 'electronics', category = 'electronics', icon = 'radio' },

  
  { name = 'bandage',        label = 'Bandage',             price = 120,  vendor = 'medical',     category = 'medical',    icon = 'plus' },
  { name = 'firstaid',       label = 'First Aid Kit',       price = 500,  vendor = 'medical',     category = 'medical',    icon = 'kit' },

  
  { name = 'ammo-9',         label = '9mm Ammo Box',        price = 750,  vendor = 'parts',       category = 'parts',      icon = 'ammo' },
  { name = 'weapon_part',    label = 'Weapon Parts',        price = 1800, vendor = 'parts',       category = 'parts',      icon = 'parts' },
  
  { name = "weapon_knife",        label = "Knife",                price = 600,  vendor = "weapons", category = "melee",    icon = "knife" },
  { name = "weapon_bat",          label = "Baseball Bat",         price = 750,  vendor = "weapons", category = "melee",    icon = "bat" },
  { name = "weapon_switchblade", label = "Switchblade",          price = 1100, vendor = "weapons", category = "melee",    icon = "knife" },
  { name = "weapon_machete",     label = "Machete",              price = 1400, vendor = "weapons", category = "melee",    icon = "knife" },

  { name = "weapon_pistol",       label = "Pistol",              price = 4500, vendor = "weapons", category = "pistols",  icon = "pistol" },
  { name = "weapon_combatpistol", label = "Combat Pistol",       price = 6200, vendor = "weapons", category = "pistols",  icon = "pistol" },
  { name = "weapon_pistol_mk2",   label = "Pistol Mk II",        price = 8800, vendor = "weapons", category = "pistols",  icon = "pistol" },

  { name = "weapon_microsmg",     label = "Micro SMG",           price = 12000, vendor = "weapons", category = "smgs",    icon = "smg" },
  { name = "weapon_smg",          label = "SMG",                 price = 15500, vendor = "weapons", category = "smgs",    icon = "smg" },
  { name = "weapon_assaultsmg",   label = "Assault SMG",         price = 18500, vendor = "weapons", category = "smgs",    icon = "smg" },

  { name = "weapon_carbinerifle", label = "Carbine Rifle",       price = 26000, vendor = "weapons", category = "rifles",  icon = "rifle" },
  { name = "weapon_assaultrifle", label = "Assault Rifle",       price = 28500, vendor = "weapons", category = "rifles",  icon = "rifle" },

  { name = "weapon_pumpshotgun",  label = "Pump Shotgun",        price = 21000, vendor = "weapons", category = "shotguns",icon = "shotgun" },
  { name = "weapon_sawnoffshotgun",label="Sawn-Off Shotgun",     price = 24000, vendor = "weapons", category = "shotguns",icon = "shotgun" },

  
  { name = "pistol_ammo",         label = "Pistol Ammo",         price = 900,  vendor = "parts",   category = "ammo",     icon = "ammo" },
  { name = "smg_ammo",            label = "SMG Ammo",            price = 1200, vendor = "parts",   category = "ammo",     icon = "ammo" },
  { name = "rifle_ammo",          label = "Rifle Ammo",          price = 1600, vendor = "parts",   category = "ammo",     icon = "ammo" },
  { name = "shotgun_ammo",        label = "Shotgun Ammo",        price = 1400, vendor = "parts",   category = "ammo",     icon = "ammo" },

  
  { name = "armor",               label = "Body Armor",          price = 2500, vendor = "parts",   category = "gear",     icon = "armor" },
  { name = "heavyarmor",          label = "Heavy Armor",         price = 5000, vendor = "parts",   category = "gear",     icon = "armor" },

  
  { name = "binoculars",          label = "Binoculars",          price = 450,  vendor = "tools",   category = "tools",    icon = "tool" },
  { name = "advancedrepairkit",   label = "Advanced Repair Kit", price = 1200, vendor = "tools",   category = "tools",    icon = "wrench" },
  { name = "weapon_flashlight",   label = "Flashlight",          price = 350,  vendor = "tools",   category = "tools",    icon = "tool" },
  { name = "thermite",            label = "Thermite",            price = 2200, vendor = "tools",   category = "tools",    icon = "bolt" },
  { name = "electronickit",       label = "Electronic Kit",      price = 900,  vendor = "electronics", category = "electronics", icon = "chip" },
  { name = "trojan_usb",          label = "Trojan USB",          price = 2600, vendor = "electronics", category = "electronics", icon = "chip" },

}

Config.Debug = {
  print = true,
}

Config.Orders.timingTiers = {
  
  { maxTotal = 2500, maxItems = 6,  processing = { min = 20,  max = 60 },  enroute = { min = 40,  max = 120 } },
  
  { maxTotal = 10000, maxItems = 18, processing = { min = 60,  max = 180 }, enroute = { min = 120, max = 360 } },
  
  { maxTotal = -1,   maxItems = -1, processing = { min = 180, max = 600 }, enroute = { min = 300, max = 900 } },
}

Config.Delivery.codeCourier = {
  enabled = true,
  pedModel = 'g_m_y_mexgoon_02',
  scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
  invincible = true,
  useOxTarget = true,
  targetLabel = 'Enter Drop Code',
  targetIcon = 'fa-solid fa-key',
  targetDistance = 2.0,
}

Config.Delivery.guards = {
  enabled = false,
  count = 3,
  radius = 12.0,
  models = { 'g_m_y_lost_01', 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02' },
  weapon = 'WEAPON_PISTOL',
  accuracy = 35,
  armor = 40,
  relationshipGroup = 'BM_GUARDS',
}

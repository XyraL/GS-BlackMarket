# GS-BlackMarket  
### Tablet-Based Black Market System (QBox / QBCore)

GS-BlackMarket is a fully tablet-driven black market system built for RP environments.  

Players use a physical tablet item to access the market, place orders, and pick them up from courier NPCs once ready.

Everything runs server-side and persists through restarts.

---

## What This Script Does

- Opens from a usable item (`blackmarket_tablet`)
- Allows account creation with a custom alias
- Categorized shop (weapons, tools, etc.)
- Cart and checkout (cash / bank)
- Server-driven order processing system
- Live ETA countdown in the UI
- NPC courier drop system (fixed drop points)
- Blip-only navigation
- Persistent orders via oxmysql
- Restart-safe delivery recovery


---

## Order Flow

When a player checks out:

1. Payment Verified  
2. Processing  
3. Dispatched  
4. En Route  
5. Ready  
6. Claimed  

Once ready, a courier NPC spawns at a configured drop point.  
The player must enter the generated code to receive their items.

Timers are server-controlled and do not reset when reopening the UI.

---

## Dependencies

Required:
- ox_lib
- oxmysql

Framework:
- qbx_core (QBox)
- or qb-core (QBCore)

Inventory:
- ox_inventory
- or qb-inventory

Optional:
- ox_target (recommended for courier interaction)

---

## Installation

1. Place the resource in your server folder  
   Example: `gs-blackmarket`

2. Ensure dependencies before the script:

```
ensure ox_lib
ensure oxmysql
ensure ox_inventory
```

3. Ensure the resource:

```
ensure gs-blackmarket
```

---

## Required Item

Add this to your inventory system:

### ox_inventory example

```
['blackmarket_tablet'] = {
    label = 'BlackMarket Tablet',
    weight = 500,
    stack = false,
    close = true,
},
```

---

## Configuration

Everything is handled through `config.lua`.

### Framework Mode

```
Config.Framework.mode = 'auto' -- auto | qbox | qbcore
```

### Inventory Mode

```
Config.Inventory.mode = 'auto' -- auto | ox_inventory | qb-inventory
```

### Catalog

Add or edit items in:

```
Config.Catalog = {
    weapons = {},
    tools = {}
}
```

---

## Delivery Configuration (NPC Drops Only)

Drops use fixed coordinates for stability and immersion.

Example:

```
Config.Delivery.fixedDrops = {
    vec4(2048.78, 3205.02, 44.19, 187.09),
    vec4(677.63, 589.61, 129.46, 240.34),
    vec4(-903.98, -362.49, 37.96, 311.7),
    vec4(202.69, -2203.75, 4.95, 26.96),
    vec4(-1610.81, -1045.38, 4.99, 140.04)
}
```

Server owners can add or remove as many drop points as they want.

---

## Debug Mode

Debug output is controlled via:

```
Config.Debug = false
```

Enable it if you need console insight.  
Leave it off for production.

---

## Stability Notes

- Orders persist through restart.
- Only one processing ladder runs per order.
- Items are validated before being given.
- NPC-only drop system (crate and alternate drop types removed for stability).

---
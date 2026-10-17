# Machine ports and tier 2 machines (design draft for spec v0.3)

Status: partly built. Week 6 shipped the pyrolysis kiln, mushroom house, straw baler, and market stall with one input and one output each, so they run on the current simulation: the kiln flares its syngas instead of piping it, the mushroom house takes wet straw (soaked straw is how mushrooms are grown) instead of bales plus water, and the baler stands beside a paddy and hands its bales to the player. The simulation now supports several ports per machine: ProductionLine gives every port its own link, a recipe consumes PerCycle units at every In port and fills every Out port, and an Out port with Vent releases its units while nothing is connected. Catalog entries list ports beyond the primary IN (West 0) and OUT (East 0) in ExtraPorts. The kiln uses it for its syngas gas port (North +4, vented until gas pipes are Ready), and the buyer depot has three IN bays on its west wall. The mushroom house still runs on the single-port recipe until fluid pipes exist.

## Port rules

- A machine has one or more **ports**. Each port has a **direction** (In or Out), a **medium** (Item, Fluid, or Gas), the **item** it carries, and a **position** on the machine: side plus offset along that side, in studs, in the machine's unturned frame.
- Item ports connect with **conveyors**. Fluid ports (water, liquid fuel) use **fluid pipes**. Gas ports (steam, syngas, biogas) use **gas pipes**.
- A recipe consumes from several In ports and fills several Out ports. A machine starts a cycle only when **every** required input is present and **every** output has room (spec 4.3, applied per port).
- Starved and blocked reasons name the exact port: "Waiting for water", "Biochar output full".
- One output still feeds one line; a splitter (P1) is needed to branch.

## Port colors on models and in build mode

| Medium | Marker on the model | Line used |
| --- | --- | --- |
| Item | Yellow plate | Conveyor |
| Fluid | Blue flange | Fluid pipe |
| Gas | Gold flange | Gas pipe |

## Port layouts

Positions use Roblox axes before rotation: West is -X, East is +X, North is -Z, South is +Z. Offsets run along the side from its centre.

| Machine | Tier | Size (X, Y, Z) | Ports |
| --- | --- | --- | --- |
| Dryer | 0 | 16, 12, 14 | In Item: wet straw, West 0. Out Item: dry straw, East 0 |
| Shredder | 0 | 16, 10, 14 | In Item: dry straw, West 0. Out Item: shredded straw, East 0 |
| Pellet mill | 0 | 18, 14, 16 | In Item: shredded straw, West 0. Out Item: pellet crate, East 0 |
| Covered storage | 0 | 14, 10, 14 | In Item: one straw type, West 0. Out Item: same type, East 0 |
| Truck terminal | 0 | 20, 8, 14 | No ports. Trucks unload into the collection point |
| Baler | 1 | 10, 6, 8 | Picks up loose straw from a field in range. Out Item: straw bale, East 0 |
| Pyrolysis kiln | 2 Soil | 18, 14, 16 | In Item: shredded straw, West 0. Out Item: biochar, East 0. Out Gas: syngas, North +4 |
| Mushroom house | 2 Food | 20, 10, 14 | In Item: straw bale, West 0. In Fluid: water, North -5. Out Item: straw mushrooms, East 0. Out Item: spent straw, South +5 |
| Cooperative office | Research | 16, 10, 14 | No ports. Hire engineers here to earn research points |

## Tier 2 recipes (first pass, tune in playtests)

| Machine | Inputs per cycle | Outputs per cycle | Cycle | Catch |
| --- | --- | --- | --- | --- |
| Baler | 4 loose straw from the field | 1 straw bale (counts as 4 bundles, trucks carry 2x) | 15 s | Jams on wet straw during rain |
| Pyrolysis kiln | 3 shredded straw | 1 biochar + 1 syngas | 30 s | Slow; smoke unless sealed |
| Mushroom house | 1 straw bale + 1 water | 2 straw mushrooms + 1 spent straw | 120 s | Long batch, high value, needs a water line |

Syngas can feed a dryer's heat input later (Gas In), which speeds drying without diesel. Spent straw feeds a compost yard (tier 2 Food). Nothing simply disappears.

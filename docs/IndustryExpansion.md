# Industry expansion: from straw line to straw industry

Goal: give Burn or Build the depth of Roblox Industrialist (Mamytema Studios), where a single
factory (for example an oil to diesel line) takes hours of planning, power, piping and ratios,
while keeping our theme: everything starts from rice straw and the choice to burn it.

## 1. What Industrialist does (research summary)

Source: the official Industrialist wiki (industrialist.miraheze.org), read October 2026.

| Pillar | How Industrialist does it | Example numbers from the wiki |
|---|---|---|
| Extractors placed anywhere | Drills and pumps make resources from the ground where you place them (Ore Nodes is an optional harder mode) | Coal Drill: 50 money, 0.25 coal/s, needs 120 MF/s. Water Pump: 60 money, 1.35 L/s, needs 600 MF/s |
| Power is required | Almost every machine needs power (MamyFlux, MF). Sources go from hand crank and solar to coal generators, boilers and turbines, diesel engines, nuclear | Solar Panel 80 money, 120 to 240 MF/s. Coal Generator 160 money, 0.25 coal + 1.45 L water per second, 7 kMF/s plus 3 L/s steam. Steam Turbine 3 L/s steam |
| Power network | Poles with range and transfer limits, batteries for night and outages | LV Pole 5 money, range 10 tiles, 2.4 kMF/s per node. Rusty Battery 100 money, 1 MMF |
| Items and fluids are separate | Item pipes and fluid pipes, tiers with higher flow | Tier 1 pipe 2 money, 6 units/s |
| Long multi-machine chains | Oil: Oil Rig, Liquid Boiler (heats crude), Crude Oil Separator (diesel, gasoline, residue), Diesel Refinery, Filtration Plant, Liquid Truck Depot. Ratios matter (6.25 rigs per liquid boiler, 2 liquid boilers per separator) | Crude Oil Separator 1,500 money, 2.2 kMF/s |
| By-products must go somewhere | Residue, contaminated water and fission waste have negative value and must be dumped, burned or treated | Contaminated Water sells for minus 241 |
| Pollution changes the world | Pollution lowers income, darkens the world and music, lowers solar output. Scrubbers remove it using water and power | Scrubber 30,000 money, 15 kMF/s, minus 3.24 percent per hour |
| Research | Research stations turn power (and later items) into research points; nodes unlock machines | Research Station1 75 money, 2.1 kMF/s, RP/s = square root of station count |
| Selling | Depots sell in batches and return after a delay | Truck Depot 100 money, 10 items, returns in 15 s |
| Prices climb steeply | Tier 1 machines cost tens, tier 3 machines cost tens of thousands | Kiln 3,200, Paper Mill 80,000, Blast Furnace 60,000 |

The lesson for us: depth comes from (1) power that every machine needs, (2) fluids that need
their own pipes, (3) chains of 6 to 12 machines with ratios, (4) by-products that must be
handled, and (5) prices and research that take hours to climb.

## 2. Our version: the straw industry

Rice straw stays the heart of the game. The new depth comes from what real straw industries
need around it: water, heat, power, other farm wastes, and markets.

### 2.1 Resources

| Resource | Where it comes from | Notes |
|---|---|---|
| Rice straw | Fields, contracts, balers (existing) | Still the main input |
| Paddy grain | Player harvest (existing) | Now an input: the rice mill splits it |
| Rice husk | Rice mill (grain to milled rice + husk) | Excellent boiler fuel, ash gives silica |
| Water | Water pump, placed anywhere, faster beside the canal | Needed by soaking, boilers, digesters, pulping |
| Manure | Cattle pen (buy cattle, feed them straw) | Needed by digester and compost |
| Bought inputs | Supply depot: urea, caustic soda, enzymes, yeast, diesel | Cost money every cycle, like operating costs |

### 2.2 Power (new, required)

Every factory machine gets a `PowerKW` need. Without enough power it runs slower (brownout) or stops.

| Source | Input | Output | Notes |
|---|---|---|---|
| Hand crank | Player holds E | Small | Start-up only |
| Solar panel | None | Small, day only | Pollution and smog lower it |
| Diesel generator | Bought diesel | Medium | Costs money, adds smog |
| Straw boiler + steam turbine | Straw bales, pellets or husk + water | Large | Burning straw inside a boiler with a filter is the clean way to use it as fuel |
| Biogas engine | Biogas (pipe) | Medium | Closes the loop with the digester |
| Battery | Stores power | | Night and outages |
| Power pole | Range 10 cells | | Links generators to machines |

### 2.3 Logistics (new)

- Belts (existing), plus splitter, merger, and underground belt.
- Fluid pipes (water, steam, biogas, slurry, ethanol) with pumps and tanks. The kiln's Syngas port
  already uses the Gas medium, so the port system is ready.
- Storage silos for items and tanks for fluids.
- Liquid tanker depot to sell fluids, supply depot to buy chemicals.

### 2.4 Production chains by tier

Tier 1 (existing, rebalanced to need power)
- Pellets: dryer, shredder, pellet mill, storage, truck terminal, buyer.
- Cattle feed: baler, urea treatment tank (straw + urea + water), feed bales.

Tier 2 (food and soil)
- Mushrooms: soaking tank (straw + water), mushroom house, mushrooms + spent substrate.
- Compost: compost yard (spent substrate + manure + straw), compost, fertilizer that raises soil health
  on the player's paddies.
- Biochar: pyrolysis kiln, biochar, syngas piped to the dryer or boiler as fuel.
- Rice mill: paddy grain to milled rice + husk.

Tier 3 (energy and materials)
- Biogas: shredded straw + manure + water into an anaerobic digester, biogas (gas) + digestate (slurry).
  Biogas runs a gas engine for power or goes to an upgrader and bottler for bio-CNG. Digestate goes
  to a separator for liquid fertilizer and fibre.
- Pulp and paper: shredded straw + water + caustic soda into a pulper (needs steam), washer, paper
  machine (needs steam), paper rolls, then a box maker for packaging. Black liquor must go to a
  recovery boiler or it becomes negative-value waste.
- Husk power and silica: husk boiler, ash, acid leach tank, silica powder.

Tier 4 (the "oil refinery" of our game: straw bioethanol, built over hours)
1. Shredder, then pretreatment reactor (shredded straw + steam + dilute acid).
2. Neutraliser (lime), then hydrolysis tank (enzymes): sugar syrup + lignin cake.
3. Fermenter (yeast): "beer" (fluid) + CO2 (vented or bottled).
4. Distillation column (steam): 95 percent ethanol + stillage.
5. Dehydration unit: fuel ethanol, sold at the tanker depot.
6. By-products: lignin cake to the boiler as fuel, stillage to the digester. Unhandled stillage
   is negative value, like Industrialist's residue.
Ratios: about 3 pretreatment reactors per hydrolysis tank, 2 hydrolysis tanks per fermenter,
4 fermenters per distillation column, plus boilers for steam and power for all of it.

Tier 4 side line: straw particle board (shredded straw + resin, hot press, boards).

### 2.5 Pollution and the burn choice

- Smog stays the shared meter. Diesel generators, boilers without filters, and vented gases now
  add to it, so the factory itself can pollute.
- New machines: bag filter (boiler add-on), gas flare to biogas upgrade, and late game a scrubber.
- Burning a field stays the fast early option and still costs the village. In the late game the
  factory needs more straw than the player's own fields produce, so burning becomes a loss: the
  straw is worth more as fuel and feedstock than as ash.

### 2.6 Progression and session length

Industrialist factories take hours because worlds are saved. A 20 minute season cannot hold that.
Proposal: keep the 20 minute season as the "burn season" event, but save the player's factory,
money and research between sessions (DataStore) and let seasons repeat. Each new season brings new
straw, new contracts and a new smog risk, while the factory keeps growing.

### 2.7 Research

- Research lab needs power (like Research Station1) and later samples of products.
- Points per second grow with the square root of labs, like Industrialist.
- Three branches: Production (chains), Energy (power, steam, biogas), Utility (logistics, filters).

## 3. Build order (phases)

Status, October 2026: phases 1 to 3 are built, and phase 5 has its biogas half (cattle shed,
digester, biogas engine). Decisions taken with the developer: an endless sandbox with saving (no
results screen), power for every machine, biogas as the first big chain. Not built yet: compost and
fertiliser for soil, the rice mill and husk, pulp and paper, splitters and silos, bioethanol, filters
and the scrubber, and research stations that need power.

1. Power network: generators, poles, batteries, power need on every machine, power HUD. Rebalance
   tier 1. Hand crank and solar to start.
2. Fluids: water pump, fluid pipes, tanks, steam boiler and turbine. Connect the kiln's syngas port.
3. Save system and repeating seasons.
4. Tier 2 chains: soaking, compost and fertilizer, rice mill and husk.
5. Tier 3: biogas and pulp and paper, logistics extras (splitter, merger, silos).
6. Tier 4: bioethanol and particle board, filters and scrubber.
7. Research tree expansion and price curve.

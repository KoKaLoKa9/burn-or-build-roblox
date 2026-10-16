# Burn or Build Roblox Demo

This folder contains the editable Roblox and Rojo project for the Burn or Build: PM2.5 Factory demo.

## Current milestone

Week 4 P0 season loop, forecast weather, and the end of season results, built against `Burn_or_Build_Machines_Gameplay_Mechanics.docx` v0.2.

- Gate A was approved on 3 September 2026.
- Gate B (graybox map and one interactive rice field) is code complete.
- Week 2 adds the server-authoritative production simulation, free machine placement, conveyors, the factory intake, and pellet sales.
- Week 3 adds Farm B and Farm C commitments, the truck route terminal, covered buffer storage, staged unlocks, and burn source records.
- Week 4 adds the 20 minute season clock with the five phases of spec 2.3, one forecast weather event in the stress phase, and the result screen. The Week 2 and Week 3 lines still need their Studio play tests; run all three checklists below.
- Week 5 so far: Shift to run, the first batch tutorial checklist, walk-up sheaves on Farm B and Farm C, and a generated landscape (`EnvironmentService` and `Flora`): terrain grass, green and flooded paddies, the canal, northern mountains, a pine hill, laterite farm tracks, sugar palms and shade trees, field huts, power poles, and late-afternoon light. It is rebuilt from code on every Play, so it does not appear in edit mode.
- Week 5 replanting: once your field is clear (collected or burned), plant its nine rows one by one. Rice grows in two minutes, harvest pays grain and leaves a new batch of straw, and the burn or build choice comes back with every batch. Only the first batch has the deadline and counts as the field result in the season report; grain and seed show as "Rice harvest" in the profit causes.
- Week 5 paddy plots: three lots between the main road and the factory (`GameConfig.Plots`) are for sale at 300 credits each. Hold E at a lot's FOR SALE sign to buy it; it becomes a five-row paddy that runs the same cycle as your field (`PaddyField`), and only the buyer may plant, harvest, or burn it. Plots count as investment next to machines and belts in the season report.
- Balance pass (after Week 5): soil health. Burning a paddy drops its soil one level (Good, Fair, Poor), so rice grows slower (120, 145, 170 s) and pays less grain (30, 24, 18 credits a row). Each clean clear, by hand or by baler, restores one level. Until now repeat burns had no in-game cost; trust and exposure only showed in the season report.
- Week 6 research and tier 2: build one cooperative office and hire up to three engineers with T there (fee 200 x (1.5 - trust / 100), wage 5 credits per engineer every 30 s). Engineers earn a research point every 15 s. Press E at the office to open the research panel and pick a project: farm machines (the transplanter and combine are now research unlocks), straw baler, market stall, then the pyrolysis kiln and mushroom house. The baler stands beside a paddy and gathers its straw into bales (take them with E); the kiln turns 3 shredded straw into a biochar sack (syngas is flared for now); the mushroom house turns 2 wet straw into a basket of straw mushrooms; the placeable market stall buys pellets (135), biochar (240), and mushrooms (180).
- Week 5 farm machines, the first automation tier for rice: the rice transplanter (250 credits) plants one empty row every 4 s at the usual seed cost, and the combine harvester (400 credits) harvests one ripe row every 5 s for the usual grain. Both stand on the ground beside a paddy (Farm A or a plot you own, within 12 studs of its edge, never on the field or its sign) and work that paddy for their owner through `PaddyField`. Harvested rows still leave straw, and the transplanter waits until it is cleared, so the burn or build choice stays with the player. F pauses them; the Delete tool refunds them like any machine. They use part-built placeholder art (`FarmMachineArt`) until Blender models are imported.

### Week 4 scope

| Spec section | Status |
| --- | --- |
| 2.3 Server season clock from `GameConfig.Round.DurationSeconds`: Harvest (0 to 3 min), First line (3 to 8), Expansion (8 to 14), Weather stress (14 to 18), Closing (18 to 20), then Season results | Done, tested in Lune. Phases scale with the round length |
| 2.3 HUD shows the phase, its goal, the time left, and a timeline bar with phase notches | Done on the status card |
| 11.3 One weather event in the stress phase: Rain or Wind shift, rolled per season | Done, tested in Lune. Starts at minute 15, forecast at minute 13 |
| 11.3 Forecast about 2 minutes ahead on the HUD, with a countdown and the countermeasure | Done, plus a notice to every player |
| 11.3 Rain: dryer cycles take 50 percent longer, loose straw in fields stays wet | Done for 2.5 minutes of rain. Field and farm billboards say the straw stays wet; rain falls over the district |
| 11.3 Wind shift: wind turns West for the rest of the season, new plumes drift to open land, `WindDirection` and `WindDestination` update | Done through the shared `GameConfig.Wind` table that `SmokeService` reads at each burn |
| 12.3 Season profit (sales and bonuses minus processing, route, extension, and utility costs), ending cash, cooperative value = cash + 70 percent of owned infrastructure | Done, every credit change is tagged in a per-player ledger |
| 12.4 Clean Air: district exposure, exposure from your decisions, exposure from unserved farms, exposure prevented, smoke that drifted to open land, exposure by cause | Done from `ReplicatedStorage.BurnRecords` (new `Potential` attribute) |
| 12.4 Trust: accepted, completed, missed, rejected, never answered, with the trust change behind each | Done |
| 12.5 Replay: most important cause, first bottleneck (first machine backed up for 15 s), what went well, burns in time order | Done |
| 12.5 Soft failure: the season closes early when every field is settled and no straw is left anywhere | Done, from the stress phase onward, after 45 s of idle |
| 16.4 Exposure is never called measured PM2.5 | Done. The HUD meter reads "Village exposure", the result screen carries the teaching-scale disclaimer, and a Lune test scans every result string |
| 11.3 Rain turns uncovered dry straw back to wet, storage roofs close | Not started |
| 11.3 Rain lowers solar output | Not applicable until the P1 power layer |

Balance assumptions not fixed by spec v0.2 live in `SeasonDefinitions.luau`: the event starts one minute into the stress phase, rain lasts 150 s and multiplies dryer cycle time by 1.5, the wind shift turns West and stays, a bottleneck is a machine Blocked for 15 s in a row, and the idle soft end waits 45 s. The weather kind is rolled at random; results use the shared district state, so in a multiplayer test every player sees the same commitments and burns.

After the results appear, the world keeps running as a sandbox. Stop and start Play for a new season.

### Week 3 scope

| Spec section | Status |
| --- | --- |
| 10.1 Farm B (12 bundles, minute 10, 50 credit route, 35 exposure) and Farm C (16 bundles, minute 16, 80 credit route, 50 exposure) | Done, tested in Lune |
| 10.2 Available, Accepted, Rejected, In Progress, Completed, Missed, Extended states, one extension only | Done, tested in Lune |
| 10.3 Missed and unserved farms burn only the remaining straw through SmokeService | Done, exposure scales with the straw burned |
| 10.3 One source record per burn: field, quantity, time, wind, destination, exposure, responsibility | Done, mirrored to `ReplicatedStorage.BurnRecords` and the HUD |
| 10.4 Trust: complete +10, miss -15, reject 0, early burn on Farm A -5 | Done |
| 15.2 Loaded straw counts as collected; completing on the deadline tick wins over burning; rejected burns are not broken promises | Done, tested in Lune |
| 7.3 Covered storage: 12 bundles, 250 credits, type lock, material setting, output pause, all 7 operating states | Done in `ProductionLine`, tested in Lune |
| 7.4 Truck terminal: 500 credits, near a road, 8 bundles per trip, unloads into the factory intake, route fee per completed trip, cancel before departure | Done, trip logic tested in Lune |
| 12.2 Storage and truck terminal unlock after the first pellet sale | Done, checked by server and ghost preview |
| 7.3 Roof closing in rain, 11.3 weather event | Weather event done in Week 4; the roof animation is not started |
| 12.2 First completed commitment unlocks parallel tools | Not started |
| 12.4 Result screen separating exposure by responsibility | Done in Week 4 |

Balance assumptions not fixed by spec v0.2 live in `CommitmentDefinitions.luau`: one extension adds 3 minutes for 50 credits, reliability bonus is 100 credits for Farm B and 150 for Farm C, truck travel is 15 s (B) and 25 s (C) each way, loading takes 4 s, and the terminal must be within 20 studs of a road. Commitments are offered from the start of the round so Farm B's minute 10 deadline stays reachable, even though spec 13.3 ties neighboring contracts to tutorial completion.

### Week 2 scope

| Spec section | Status |
| --- | --- |
| 3.1, 3.2, 3.5 Free placement with ghost preview, rotate, optional grid, validation reasons | Done |
| 3.3 Typed port connections, one output feeds one line | Done |
| 3.4 Fixed placeholders become an optional see-through blueprint | Done |
| 4.2, 4.3 Recipe ratios, cycle logic, hold output when blocked, pause keeps progress | Done, tested in Lune |
| 4.5 Visible belt items match server counts, ordered queues | Done |
| 6.2 Straw collection point | Fixed factory intake for now, not yet player placeable |
| 8.4 Buyer depot, 150 credits per crate, pays once per crate | Done |
| 12.1 Processing cost of 30 credits per crate | Done |
| 13.3 Tutorial ends at first sale, refund drops from 100 to 70 percent | Done |
| 3.2 Move and copy | Not started |
| 15.1 Recovery crates on dismantle | Not started, dismantling requires an empty machine instead |
| 6.3 Baler | Not started |
| 7.3 covered storage, 7.4 truck routes, 10 Farm B and C commitments | Moved to Week 3, see above |

### Play controls

| Key | Action |
| --- | --- |
| E | Pick up a straw sheaf, deposit carried straw at the covered collection point, or (hold, at a row end of your field) plant rice for 5 credits and harvest ripe rice for 30 credits of grain |
| H (hold) | Allow burning on your own field |
| B | Open the inventory: drag items onto hotbar slots 1 to 9, or drag a hotbar item off to put it away |
| Shift (hold) | Run, about 2.5 times walking speed |
| E / T at the office | Open the research panel / hire an engineer (the fee drops as farmer trust rises) |
| E at a straw baler | Take the straw it has baled, then carry it to the collection point |
| C | Open or close the Stats panel (season clock, forecast, crates, wind, trust, exposure, farm contracts). Credits and carried straw always show at the top left |
| 1 to 5 | Select a machine (dryer, shredder, pellet mill, storage, truck terminal) |
| 6 | Conveyor: click to lay a tile, or hold and drag to lay a line that turns with the drag (5 credits per tile) |
| 7, 8 | Farm machines: rice transplanter and combine harvester, placed beside your paddy (the fluid and gas pipes for the energy update stay in the inventory) |
| R | Rotate the machine ghost, or turn the next conveyor tile |
| Right click | Remove the conveyor tile under the cursor (refunded) |
| G | Toggle grid snapping |
| Left click | Place the machine ghost, or lay conveyor tiles |
| Q | Leave build or conveyor mode |
| F | Pause or resume a machine |
| X | Delete tool: hover your machine or belt tile (outlined red) and click to delete it, or drag across belt tiles to clear a run. Refunded; anything still holding items is refused |

Machine IN and OUT ports only appear while placing a machine or laying conveyor. A belt carries items once its tiles run from a machine OUT to the next machine IN and the last tile points into that machine.
Build mode currently needs keyboard and mouse. Touch controls are not implemented.

## Tool versions

- Roblox Studio: locally installed
- Rojo: 7.7.0
- Selene: 0.31.0
- StyLua: 2.5.2
- Lune: 0.10.5

## Source ownership

- Roblox Studio owns `Workspace.BurnOrBuildWorld` and other map geometry.
- Rojo owns the scripted content under ReplicatedStorage, ServerScriptService, and StarterPlayerScripts.
- `Workspace` uses `$ignoreUnknownInstances` so syncing scripts does not remove Studio-edited map content.

## Development workflow

1. Open `BurnOrBuild.rbxlx` in Roblox Studio.
2. Start Rojo from this directory with `rojo serve`.
3. Open the Rojo Studio plugin and connect to port 34872.
4. Sync the project.
5. Use Play to test the field interaction and HUD.
6. Save the place after map edits.

The current controlled shell may not resolve Rokit launcher shortcuts. The pinned Rojo executable is installed at:

`C:\Users\User\.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe`

## Machine art

Low-poly machine models are made in Blender 5.2 at 1 Blender unit = 1 stud.

| Folder | Contents |
| --- | --- |
| `art/blender/` | Editable `.blend` sources for the pellet mill, dryer, and shredder |
| `art/export/` | FBX files to import into Studio |
| `art/renders/` | Preview renders |

Each colored piece is its own mesh (for example `PM_Housing`). `src/ReplicatedStorage/Shared/MachineArtPalette.luau` gives every piece its color and Roblox material by name, because Studio does not keep plain Blender material colors.

### Importing a model into Studio

1. Stop any Play session. In Studio, open **Home > Import 3D** and pick a file from `art/export/`.
2. In the import window, keep **Insert in Workspace** on. Check that the preview size is about 18 x 12 x 16 studs for the pellet mill, 16 x 12 x 14 for the dryer, and 16 x 9 x 14 for the shredder. If it is 100 times too small or too large, change the file scale setting and preview again.
3. Click **Import**. Roblox uploads the meshes to your account as assets. This does not publish the game.
4. In Explorer, make sure the imported Model is named exactly `PelletMill`, `Dryer`, or `Shredder`.
5. Create a Folder named `MachineArt` under **ServerStorage** (once) and drag the Model into it.
6. Optional: to preview the colors in edit mode, paste this into the Command Bar with the model selected:
   `require(game.ReplicatedStorage.Shared.MachineArtPalette).Apply(game.Selection:Get()[1])`
7. Save the place. Rojo does not remove Studio-made content under ServerStorage.

When you place that machine in Play mode, the server clones its art, paints it, and keeps the old box as an invisible collision and click target. Machines without art keep the graybox look.

## Graybox regeneration warning

`tools/GenerateGraybox.luau` is a one-time Studio Command Bar script. Running it deletes and recreates only `Workspace.BurnOrBuildWorld`. Do not rerun it after manual map edits unless those edits can be discarded.

## Verification

Before a checkpoint:

1. Format or check all Luau source with StyLua: `stylua --check src tools tests`
2. Run Selene with the generated Roblox standard library: `selene src tests`
3. Run the simulation tests: `lune run tests/ProductionLine.spec.luau` and `lune run tests/ConveyorGrid.spec.luau` and `lune run tests/Commitments.spec.luau` and `lune run tests/Season.spec.luau` and `lune run tests/FarmMachines.spec.luau`
4. Build the project with Rojo: `rojo build -o build-check.rbxlx` (delete the output afterwards)
5. Open the place in Studio and complete the relevant gameplay test.
6. Inspect the rendered map and HUD.

Everything under `src/ServerScriptService/Simulation` (`ProductionLine`, `FarmCommitments`, `TruckRoute`, `SeasonClock`, `SeasonResults`) must stay free of Roblox instances so Lune can test it.

### Week 2 Studio play test

1. Collect all 8 bundles at Farm A before the 4 minute deadline.
2. Place a dryer, shredder, and pellet mill on the factory floor. Confirm an invalid ghost turns red and names the reason.
3. Connect intake to dryer, dryer to shredder, shredder to pellet mill, and pellet mill to the pellet buyer.
4. Try connecting the dryer straight to the pellet mill and confirm the wrong port message.
5. Deposit the straw at the intake. Expect 4 crates sold, +600 sales, and -120 processing cost: 1,000 - 800 + 600 - 120 = 680 credits.
6. Pause a machine and confirm its status reads Paused, then resume it.

### Week 3 Studio play test

Start from a fresh Play session. Times are minutes since the server started.

1. Before the first sale, press 4 and 5. Confirm the catalog says locked and the ghost reads "Sell your first pellet crate to unlock this."
2. Walk to Farm B. Confirm the billboard and HUD show 12 bundles, the deadline countdown, 50 credits per trip, and 35 burn exposure. Repeat at Farm C (16 bundles, 80 credits, 50 exposure).
3. Hold T at Farm C to reject it. Confirm trust does not change and the HUD reads "Farm C: Rejected".
4. Press E at Farm B to accept. Collect 4 bundles by hand, then confirm the state reads In progress.
5. Hold Y at Farm B. Expect -50 credits, the state Extended, and the deadline 3 minutes later. Hold Y again and confirm it is refused.
6. Finish the Week 2 line and sell the first crate. Confirm the notice names storage [4] and the truck terminal [5] as unlocked.
7. Place a truck terminal far from any road and confirm the red ghost asks for a road within 20 studs. Place it beside the factory road (-500 credits).
8. Press E at the terminal until it reads Farm B, then hold F. Watch the truck drive the road, load at Farm B, and return. Its label must show state, cargo, and an arrival timer.
9. Pause the dryer and deposit carried straw until the intake is full. Confirm the truck shows Destination Full and the notice warns about unloading space, then unloads after you resume the dryer.
10. Confirm each completed trip charges exactly 50 credits and that Farm B reaches Completed: +10 trust and +100 credits, once.
11. Hold V while a truck is still on the way out. It must return empty with no route fee.
12. Place covered storage between the dryer and shredder (-250 credits). Confirm the count and text bar fill to 12, F pauses output while it keeps filling, and E cycles the material.
13. Set an empty storage to Dry straw while it is fed by wet straw. Confirm it reads Wrong Item and names both materials, and the bundle waits on the belt.
14. Let Farm C's minute 16 deadline pass. Confirm smoke drifts east, the notice and HUD name Distant farm C, 16 bundles, wind East, the Village, +50 exposure, and "Rejected by the cooperative, no promise broken". Trust must not drop.
15. In a second session, accept Farm B and let it expire with straw left. Confirm only the remaining bundles burn, exposure scales down, trust drops by 15, and the record says "Missed commitment".
16. Check `ReplicatedStorage.BurnRecords` in the Explorer: one Configuration per burn with Field, Quantity, Time, Wind, Destination, Exposure, and Responsibility.

### Week 4 Studio play test

Start from a fresh Play session. Times are minutes since the server started. To test the parts in a shorter session, use the server Command Bar (Studio Test tab, Server view): `workspace.BurnOrBuildWorld:SetAttribute("ForcedWeatherEvent", "Rain")` (or `"WindShift"`) any time before minute 13 picks the event, and `workspace.BurnOrBuildWorld:SetAttribute("EndSeasonNow", true)` jumps to the results. You can also lower `GameConfig.Round.DurationSeconds` before pressing Play; every phase scales with it.

1. At the start, confirm the status card shows "PHASE 1 OF 5", Harvest, its goal, and a clock counting down from 20:00. The bar fills left to right past four notches.
2. At 3:00, 8:00, 14:00, and 18:00, confirm the phase name and goal change (First line, Expansion, Weather stress, Closing) and a notice names the new phase. Under 2:00 left, the clock turns red.
3. Collect Farm A by hand and sell at least one crate, so the results have a kept field and a first sale.
4. Rain season (force "Rain"): at 13:00 a FORECAST box appears with "Rain in 2:00" counting down, and a notice gives the countermeasure.
5. At 15:00 confirm rain falls over the district, the box reads "WEATHER NOW Rain, 2:30 left", and the Farm B or C billboard (if straw is left) and Farm A billboard (if not cleared) say the loose straw stays wet.
6. Feed a dryer during the rain. Its status should count down from 11 s instead of 8 s. At 17:30 the rain stops, a notice says dryers are back to normal, and the next cycle counts from 8 s.
7. Wind season (second session, force "WindShift"): at 13:00 the forecast says the smoke will drift west. At 15:00 the wind tile changes from "WIND EAST, To village" to "WIND WEST, To open land".
8. After the shift, let Farm C's minute 16 deadline pass. Confirm the plume drifts west, the notice says Wind West to Open land with +0 exposure, and `ReplicatedStorage.BurnRecords` has the new entry with Wind West, Exposure 0, and Potential 50.
9. At 20:00 (or after `EndSeasonNow`), confirm the result screen opens with SEASON RESULTS, the end reason, the most important cause, and three separate columns: Profit, Clean Air, and Trust, each rated STRONG or NEEDS WORK in words.
10. Profit: season profit should equal pellet sales plus bonuses minus processing, route, and extension fees (machine purchases are not subtracted). Cooperative value must equal ending cash plus 70 percent of the infrastructure value listed under Causes.
11. Clean Air: district exposure equals the sum of the Exposure attributes in `BurnRecords`. A rejected farm's burn appears under "Unserved farms" and as its own cause; your own field burn or a missed commitment appears under "Your decisions". Exposure prevented lists the fields you collected.
12. Trust: the completed, missed, and rejected counts match the farm states, and each farm lists its trust change. The farmer trust value matches the HUD meter.
13. Season replay: the bottleneck line names a machine if one was backed up for 15 s (pause the shredder with F while the dryer runs to force it), "What went well" names a kept promise, cleared field, or first sale, and burns are listed in time order.
14. Check that no screen calls the points PM2.5. The only mention is the disclaimer in the result footer saying the points are not measured PM2.5 concentrations.
15. Close the results, confirm the SEASON RESULTS button at the top reopens them.
16. Soft end (third session): reject both farms, burn Farm A with H, and do not build. After minute 16 every field is settled and nothing is left to process; confirm the notice says the season closes in 45 s and the results open early with "Every field was settled and no straw was left to process."

### Week 5 farm machines Studio play test

1. Collect Farm A's opening straw by hand so the field reads READY TO PLANT.
2. Press 7 (rice transplanter) and move the ghost onto the field: it turns red with "Farm machines stand beside the paddy, not on it." Move it more than 12 studs away: "Place this beside a paddy". Move it onto the grass just beside the field (not on the sign or burn spot): it turns green, sits on the ground, and placing it charges 250 credits.
3. Within 4 s the transplanter's board reads "Planting" with a progress bar, and one row turns into seedlings every 4 s, 5 credits each, until "Every row is planted".
4. Press 8 and place the combine harvester beside the same field. Its board reads "Rice is growing". When rows ripen it harvests one every 5 s, pays 30 credits of grain each, and leaves a straw sheaf in the lane.
5. Once straw lies on the field the transplanter reads "Clear the straw first" and does not plant. Collect the sheaves (or burn with H): it starts planting again on its own.
6. Press F on a machine to pause it (board reads "Paused") and again to resume. Delete it with X and confirm the refund.
7. Buy a plot and place a transplanter beside it. In a two-player test, the other player's ghost beside your plot reads "This paddy belongs to another player." and the server refuses it.

### Week 6 research and tier 2 Studio play test

1. Press 9 and place the cooperative office on the factory plot (300 credits). Try a second one: "You already have a cooperative office."
2. Stand at the office: E reads "Research", T reads "Hire engineer (200 credits)". Hire three; a fourth says the office has room for 3. Credits drop by 5 per engineer every 30 s.
3. Press E: the panel lists five projects, with the kiln and mushroom house showing "NEEDS MARKET STALL". Start Market stall; with three engineers it finishes in about 15 s and the kiln and mushroom house open up. Points earned while no project runs are kept for the next one.
4. Open the inventory (B): the transplanter, combine, and baler show LOCKED until Farm machines and Straw baler are researched; their tooltips name the project. A locked ghost reads "Research ... at the cooperative office first."
5. Place a mushroom house and a market stall. The stall's board lists its three prices and it has a single IN port. Belt the collection point to the mushroom house and the house to the stall: each basket sells for 180.
6. Belt a shredder into a pyrolysis kiln and the kiln into the stall: a warm flare rises from the chimney while it works, and each biochar sack sells for 240.
7. Place a straw baler beside a paddy with straw on it: it lifts one sheaf every 3 s ("Baled straw: n/12") and stacks bales beside itself. Press E at the baler to carry the straw. When it empties the field, the soil recovers one level.
8. Burn a paddy with H: the notice says the soil is now Fair, and the board shows "Soil fair". Collect the next batch by hand to restore it.

## Publication

This project is local. Do not publish or change Roblox experience visibility without manager approval.


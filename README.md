# Burn or Build Roblox Demo

This folder contains the editable Roblox and Rojo project for the Burn or Build: PM2.5 Factory demo.

## Current milestone

Week 3 P0 farm commitments, truck routes, and covered storage, built against `Burn_or_Build_Machines_Gameplay_Mechanics.docx` v0.2.

- Gate A was approved on 3 September 2026.
- Gate B (graybox map and one interactive rice field) is code complete.
- Week 2 adds the server-authoritative production simulation, free machine placement, conveyors, the factory intake, and pellet sales.
- Week 3 adds Farm B and Farm C commitments, the truck route terminal, covered buffer storage, staged unlocks, and burn source records. The Week 2 line still needs its Studio play test; run both checklists below.

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
| 7.3 Roof closing in rain, 11.3 weather event | Not started, no weather system yet |
| 12.2 First completed commitment unlocks parallel tools | Not started |
| 12.4 Result screen separating exposure by responsibility | Not started, records already carry the responsibility |

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
| E | Pick up a straw sheaf in your field, or deposit carried straw at the covered collection point |
| B (hold) | Allow burning on your own field |
| 1 to 5 | Select a machine (dryer, shredder, pellet mill, storage, truck terminal) |
| 6 | Conveyor: click to lay a tile, or hold and drag to lay a line that turns with the drag (5 credits per tile) |
| 7, 8 | Fluid and gas pipes, reserved for the energy update |
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
3. Run the simulation tests: `lune run tests/ProductionLine.spec.luau` and `lune run tests/ConveyorGrid.spec.luau` and `lune run tests/Commitments.spec.luau`
4. Build the project with Rojo: `rojo build -o build-check.rbxlx` (delete the output afterwards)
5. Open the place in Studio and complete the relevant gameplay test.
6. Inspect the rendered map and HUD.

Everything under `src/ServerScriptService/Simulation` (`ProductionLine`, `FarmCommitments`, `TruckRoute`) must stay free of Roblox instances so Lune can test it.

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

## Publication

This project is local. Do not publish or change Roblox experience visibility without manager approval.


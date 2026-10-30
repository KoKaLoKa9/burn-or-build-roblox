# Prompt: Paddy field, rice and straw v2, high-end (Burn or Build: PM2.5 Factory)

For the same three.js agent that made `Dryer_v2.html`. In a **new chat**, attach
`art/blender/Interactive 3D dryer model/Dryer_v2.html` as the style and code reference, paste the
**Shared rules** block from `art/prompts/Environment_v2.md`, then paste everything below the line.

---

## Pack 5: Paddy field, rice and straw (`Env_Field_v2.html`)

These are the heart of the game. The player watches a rice row go from seedlings to golden grain,
harvests it, and is left with straw that they either **burn** (fast, but it makes PM2.5 smoke) or
**collect** for the factory. Everything here is seen close up, from 6 to 40 studs, so it has to be
the most believable thing in the game: central Thai paddy, jasmine rice (*khao hom mali*), dry
season, late afternoon light.

### How the game uses these

- A field is a block of **rice rows running along Z**, 9 studs apart, each 30 to 70 studs long.
  The game builds a row by **repeating one 8-stud segment end to end along Z**. So every row
  segment must **tile seamlessly**: plants run right up to both Z ends, nothing pokes past them,
  and no gap or seam shows where two copies meet. Make **two variants** (A and B) of each stage so
  the game can alternate them and the repeat doesn't show.
- When a row changes stage, the game swaps its segments for the next stage's segments.
- Straw sheaves stand **in the 9-stud lanes between rows**, so a segment never goes wider than
  6.4 studs.
- The ground under the rows is the game's terrain (the `Mud` texture from Pack 4), so the row
  segments have **no ground slab** except where a stage says so.

### Row segments (origin at the bottom centre of the segment, the ground at y = 0)

Budget **1,500 to 3,500 triangles per segment**. A field shows up to a hundred segments at once.
Use real geometry for stems and panicles near the base and **alpha cut-out cards** for leaf
masses. One shared rice texture set for all stages, recoloured per stage.

| Asset | Size (W x H x D, studs) | Description |
| --- | --- | --- |
| `RiceSeedling_A`, `_B` | 6.4 x 1 x 8 | Freshly transplanted seedlings in neat clumps (hills) about 0.8 studs apart in a grid, 3 to 5 thin leaves each, bright yellow-green. Include a thin **flooded-water sheet** at y = 0.15 the full size of the segment (separate mesh named `_Water`) with mud showing through and a few reflections. |
| `RiceGrowing_A`, `_B` | 6.4 x 2.2 x 8 | Tillering rice: dense, lush mid-green clumps, leaves arching outward, the water barely visible. Same hill grid as the seedlings, same `_Water` mesh. |
| `RiceHeading_A`, `_B` | 6.4 x 3.2 x 8 | Green rice with **panicles just coming out**, upright, pale green-gold tips. No water: the field has been drained. |
| `RiceRipe_A`, `_B` | 6.4 x 3.4 x 8 | Harvest-ready: golden yellow stems and leaves going dry, **heavy grain panicles bowing over** with individual grains readable up close. A few lodged (fallen) stems on B. This is the most important asset in the pack. |
| `Stubble_A`, `_B` | 6.4 x 1.2 x 8 | After the harvest: cut stems in their hills, about 1 stud tall, straw-yellow with grey-brown bases, and **loose straw strands scattered** on the ground between them (a thin ground mesh is fine here, named `_Litter`). |
| `StubbleBurnt_A` | 6.4 x 0.8 x 8 | After burning: charred black stubs, grey and white **ash drifts**, scorched cracked mud showing through, a few half-burnt straw strands. |
| `PreparedRow_A` | 6.4 x 0.4 x 8 | Ploughed and puddled, ready to plant: wet dark mud ridges along Z with water standing in the furrows (`_Water` mesh), boot prints and a few weeds. |

### Straw and the bund

| Asset | Size (W x H x D, studs) | Description |
| --- | --- | --- |
| `StrawSheaf_A`, `_B`, `_C` | 2.4 x 4.2 to 4.8 x 2.4 | A hand-tied sheaf of harvested rice straw standing upright on a flared foot, tied once at two-thirds height with a twisted straw band, the top loose and fanned. Real strands at the silhouette. A has a few empty panicles, B leans a little, C is more ragged. 1,200 to 2,500 triangles. |
| `StrawSheafBurnt_A` | 2.4 x 2.5 x 2.4 | The same sheaf after a fire: collapsed, black and grey, with the band burnt through. |
| `StrawWindrow_A` | 4 x 1 x 8 | A loose row of straw left by a combine harvester, tiling along Z like the row segments. |
| `StrawBaleSquare_A` | 3 x 1.8 x 2 | A rectangular baler bale with two twines, sheared ends and stray strands. |
| `Bund_A` | 2.2 x 1.7 x 8 | One 8-stud segment of the earth bank (*khan na*) around the field, tiling along Z: compacted earth sides with crumbled edges, a narrow grassy top worn bare in a footpath, a few weeds. |

### Small factory items (what rides inside the game's glass pipes and sits in storage)

Each fits inside **1.3 x 1.1 x 1.3 studs** (the pellet crate 1.5 x 1.4 x 1.5), origin at the
bottom centre, **300 to 1,200 triangles**, read clearly from 15 studs away.

| Asset | Description |
| --- | --- |
| `ItemWetStraw_A` | A small tied bundle of damp straw: darker gold-brown, a little green, clumped. |
| `ItemDryStraw_A` | The same bundle dry: bright gold and fluffy. |
| `ItemShreddedStraw_A` | A loose heap of short chopped straw (1 to 3 cm pieces) in a woven plastic sack with the top folded open. |
| `ItemPelletCrate_A` | A slatted wooden crate full of 6 mm brown straw pellets with a stencil "PELLET". |
| `ItemBiochar_A` | A tied white woven sack with black biochar dust smeared on it and a stencil "BIOCHAR". |
| `ItemMushrooms_A` | A shallow bamboo basket of straw mushrooms (*het fang*), the grey-brown egg-shaped kind. |

### Groups and checks

- Assets are `EV_<Asset>` groups as in the Shared rules (for example `EV_RiceRipe_A`,
  `EV_ItemPelletCrate_A`). Lay them out on a stage that also shows **a test field**: 4 rows of
  each stage built by tiling the segments to 40 studs, a sheaf in each lane, bunds around it, so
  the tiling and the stage-to-stage look can be judged together.
- Shots: the test field from a player's eye height (5 studs) and from above at 45 degrees, a
  close-up of the ripe rice, the stubble with sheaves, and the burnt stubble.
- In the note, list each asset's size and triangles, and confirm the row segments tile with no
  seam.

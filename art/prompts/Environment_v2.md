# Prompts: Environment v2, high-end (Burn or Build: PM2.5 Factory)

Four packs for the same three.js agent that made `Dryer_v2.html` and `Shredder_v2.html`. Run
**one pack per chat**, so each run stays short. For every pack, attach `Dryer_v2.html` as the
style and code reference, paste the **Shared rules** block, then paste that pack's block.

Suggested order: Pack 1 (trees, the biggest visual change), then Pack 4 (ground), Pack 2
(houses), Pack 3 (school).

---

## Shared rules (paste with every pack)

You are making high-end, game-ready environment assets for a Roblox game set in a **rice-farming
district of central Thailand in the dry season, late afternoon**. The player runs a straw
cooperative factory instead of burning the fields. Match the quality, code style and procedural
PBR canvas textures of the attached `Dryer_v2.html`: real proportions, wear, dust, and believable
Thai rural detail. It must not look stylised or toy-like.

- **Units and frame**: 1 unit = 1 Roblox stud (about 0.28 m). +Y is up. The origin of each asset
  is at the **bottom centre of where it meets the ground**. Buildings face **-Z** (the front door
  is on the -Z side).
- **One page, many assets**: lay every asset out side by side in the viewer. Each asset is one
  `THREE.Group` that is a **direct child of the pack root**, named `EV_<Asset>_<Variant>` (for
  example `EV_SugarPalm_A`). Inside an asset, name every mesh `EV_<Asset>_<Variant>_<Part>`.
- **Triangle budgets**: each asset stays inside the budget its pack gives, and **every single mesh
  stays under 20,000 triangles** (Roblox's hard limit).
- **Materials**: MeshStandardMaterial with canvas-made Base Color, Normal and Roughness maps (and
  Metalness where it is metal), 512 to 1024 px. **Reuse one texture set across assets** wherever
  the material is the same (bark, thatch, corrugated tin and so on). Leaves, grass and thatch
  fringes can use **alpha cut-out cards** (alphaTest 0.5); the game shows those properly.
- **Tintable parts**: where a pack says *tintable*, make that material's Base Color light grey
  (about 200, 200, 200) carrying only the detail (grain, stains, streaks), and name the mesh with
  the suffix `_Tint`. The game multiplies a colour onto it, so one model gives many colour
  variants.
- **No lights, cameras, helpers or ground planes inside the pack root.** Keep the stage outside it.
- **Deliver**: the page, an **"Export GLB" button** (GLTFExporter, binary, textures embedded, pack
  root only), a contact-sheet shot of the whole pack plus a close shot of each asset, and a short
  note listing every asset's size (W x H x D) and triangle count. Check in the page that every
  mesh is under 20k and every asset is inside its size range before you finish.

---

## Pack 1: Trees and plants (`Env_Flora_v2.html`)

The district is dotted with hundreds of these, so keep them efficient: the same mesh repeats many
times. Budget **1,500 to 6,000 triangles per asset**. Trunks are real geometry; foliage is
clustered alpha cards with a little real geometry at the core, so silhouettes read from 200 studs
away.

| Asset | Variants | Size (W x H x D, studs) | Notes |
| --- | --- | --- | --- |
| `SugarPalm` (Borassus, *ton tan*) | A, B, C | 14 x 26 to 40 x 14 | Tall straight grey trunk with ring scars and a slight lean. A crown of stiff fan leaves, a few dead brown hanging fronds, and a cluster of dark fruit on one. The icon of the Thai paddy, so make it perfect. |
| `RainTree` (*chamchuri*) | A, B | 36 to 44 x 18 to 24 x 36 to 44 | Short massive trunk forking low, with an enormous flat umbrella canopy, epiphytes on the branches and bark texture. |
| `UmbrellaPine` | A, B | 12 x 22 to 28 x 12 | Tall reddish pine with a flat-topped crown, for the dry hill. |
| `Frangipani` (*lantom*) | A | 10 x 9 x 10 | Thick candelabra branches, leaf tufts at the tips, white-yellow flowers. |
| `Banana` | A, B | 8 x 9 to 12 x 8 | A clump of 3 to 5 stems with large torn leaves and one hanging bunch. |
| `Bamboo` | A | 10 x 20 x 10 | A dense clump, arching culms and fine leaves. |
| `Bush` | A, B, C | 4 to 7 x 3 to 5 x 4 to 7 | Mixed shrubs, one flowering bougainvillea. |
| `Rock` | A, B, C | 2 to 6 x 1 to 3 x 2 to 6 | Weathered laterite and granite, half sunk. |
| `StrawStack` | A, B | 8 x 7 x 8 | A Thai field straw stack: a round stack with a domed top around a pole, sun-bleached on top. Real straw texture, not a smooth blob. |
| `FieldHut` (*thieng na*) | A | 10 x 9 x 8 | A raised bamboo platform with a thatch roof, ladder and hanging hammock. |
| `GrassClump` | A, B | 3 x 1.5 x 3 | Tall dry-season grass tufts for scattering on field edges. |

---

## Pack 2: Village houses (`Env_Houses_v2.html`)

Budget **6,000 to 15,000 triangles per house**. Walls and roofs are **tintable** (`_Tint`), so the
game can give every house its own colours. Every house has its front door on **-Z**, real
windows, doors and steps, and lived-in details: a water jar (*ong*), potted plants, a motorbike
or bicycle, laundry, a spirit house (*san phra phum*) on a post in front of two of them,
electricity meter and wires, satellite dish, plastic chairs, and rust streaks on the tin.

| Asset | Size (W x H x D, studs) | Description |
| --- | --- | --- |
| `StiltHouse_A` | 24 x 18 x 18 | Traditional teak house raised on 6-stud posts. Open space underneath with a bench and a hammock, steep roof, wooden louvred windows, front staircase. Wood is not tinted; the roof is `_Tint`. |
| `ConcreteHouse_A` | 22 x 12 x 16 | Modern single-storey rendered concrete house with a porch, sliding windows with steel grilles and a corrugated or tile roof. Walls and roof are `_Tint`. |
| `Shophouse_A` | 16 x 22 x 18 | Two-storey roadside shophouse with a folding steel shutter half open, a shop sign board (no real brands, a Thai-style "ร้านค้า" sign is fine), an awning and a drinks fridge. Walls are `_Tint`. |
| `Farmhouse_A` | 18 x 11 x 14 | Simple wooden farmhouse on short posts with a lean-to shed, a rice storage barn (*yung khao*) beside it, tools, sacks and a handcart. Roof is `_Tint`. |

---

## Pack 3: School campus (`Env_School_v2.html`)

One asset, `EV_School_A`, **80 x up to 16 x 44 studs**, budget **35,000 to 60,000 triangles**
split into several meshes (each under 20k). A Thai rural primary school:

- A two-storey classroom block along the back (+Z side) with an open corridor, railings, louvred
  windows and a cream and red colour scheme.
- A single-storey block on one side.
- A flagpole with the Thai flag on a small plinth in the front yard.
- A covered assembly area with a steel roof.
- A concrete front yard and an entrance gate on **-Z**, with a sign plate "โรงเรียนบ้านนา" (Ban Na
  School).
- A small football pitch with goals and a few trees in planters.

Keep the whole campus inside the footprint; the game's exposure zone for the school is that box.

---

## Pack 4: Ground materials (`Env_Ground_v2.html`)

Roblox terrain is voxel based, so the game cannot import ground as a mesh. Instead, make
**tileable PBR texture sets** that the game applies as Roblox MaterialVariants. Each set is
**1024 x 1024, seamless in both directions**, viewed from about 8 to 40 studs, covering about
**8 x 8 studs per tile**, with no obvious repeating features.

| Set | Replaces Roblox material | Look |
| --- | --- | --- |
| `Grass` | Grass | Dry-season paddy-edge grass, green going straw-yellow, some bare soil. |
| `LeafyGrass` | LeafyGrass | Lush green young rice field or irrigated grass. |
| `Ground` | Ground | Red-orange laterite dirt track, tyre ruts and pebbles. |
| `Mud` | Mud | Drained paddy mud, cracked and dried, with cut rice stubble. |
| `Sand` | Sand | Pale compacted yard soil. |
| `Rock` | Rock | Weathered laterite and granite. |
| `Asphalt` | Asphalt | Worn rural asphalt, patched and dusty at the edges. |
| `Concrete` | Concrete | Factory floor slab with saw-cut joints, stains and tyre marks. |

Each set has `<Set>_Color.png`, `<Set>_Normal.png` (OpenGL, Y+), `<Set>_Roughness.png` and, for
any metal, `<Set>_Metalness.png`. The page shows each set on a tiled 64 x 64 stud ground patch
next to its neighbours, so the transitions can be judged. It has a **"Download textures" button**
that saves every PNG (a zip is fine). This pack needs no GLB.

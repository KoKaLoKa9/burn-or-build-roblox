# Prompt: Dryer v2, high-end (Burn or Build: PM2.5 Factory)

Copy everything below the line into the 3D modelling agent (an agent with Blender access, for
example through the Blender MCP add-on). It replaces the low-poly `Dryer_v1` with a high-end,
fully textured model.

---

You are a senior hard-surface 3D artist making a **high-end, game-ready, physically based (PBR)
model** in Blender 5.2 for a Roblox factory game about rice straw in Thailand. Target the look of a
modern AAA industrial asset: real engineering detail, bevelled edges, baked normal maps, worn
painted metal, dust and straw grime. Not low poly, not stylised, not toy-like. It still has to run
in Roblox, so respect the technical limits in section 3 exactly. Check your own work with renders
before you report back. Accuracy to these numbers matters more than speed.

## 1. What the machine is

A **straw-fired rotary drum dryer** of the kind used by Thai rice cooperatives to dry wet rice
straw before shredding. Wet straw goes in at one end, tumbles through a slowly turning inclined drum
against hot air from a straw-fired furnace, and leaves dry at the other end. Use real rotary drum
dryers as reference for proportions and parts.

Parts it must have, all modelled as real engineering parts:

1. **Concrete foundation slab**: chamfered edges, anchor bolts, a painted yellow-and-black safety
   edge, oil stains, cracked and chipped corners, straw debris.
2. **Rotary drum**: a cylinder with **welded panel seams**, **flanged section joints with bolt
   rings**, an **inspection manway** with hinges and clamps, tilted **3 degrees** down from the feed
   end to the discharge end. Teal industrial paint with chips and edge wear showing steel, heat
   discolouration near the feed end, dust settling on top.
3. **Two riding rings (tyres)** with **two trunnion rollers** each, roller bearings in housings
   with grease nipples, roller frames bolted to concrete plinths.
4. **Drive train**: **girth gear** with real modelled teeth, a meshing **pinion**, a **gearbox**
   with cooling fins and a breather, an **electric motor** with fins, a fan cowl and a junction box,
   a **coupling** with a guard, and a perforated yellow **gear guard**.
5. **Feed end (west, low X side)**: a **feed hood** with a seal ring, a **hopper** with stiffening
   ribs, an inclined **feed chute**, and a **screw conveyor** tube with its own small motor. Two
   tied wet rice straw bundles in the hopper (straw modelled as clumps of strands with alpha cards
   or a dense strand mesh, not a plain box).
6. **Furnace**: a **straw-fired furnace** in **refractory brick** with a steel frame, a cast-iron
   **fire door** with hinges and a latch, a glowing **fire window**, soot around the door, and an
   **insulated hot-air duct** (cladding with banding straps) into the feed hood.
7. **Discharge end (east, high X side)**: a **discharge hood**, an **outlet chute** at the bottom,
   two dry golden straw bundles sliding out.
8. **Dust and exhaust**: a duct to a **cyclone** dust collector (cone on legs, cross bracing,
   rotary valve at the bottom), an **induced-draft fan** with a spiral housing and motor, and an
   **exhaust stack** with ladder rungs, a platform ring and a rain cap, soot-stained at the top.
9. **Control cabinet**: steel enclosure with door handle, screen, indicator lights, an emergency
   stop button, cable glands, cables in a **cable tray** to the motors.
10. **Access**: steel grating **walkway** (real grating pattern in the normal map) with
    **handrails, mid rails and toe boards** along the drum, and a **cage ladder** up to it.
11. **Details**: hex bolts and washers on every flange, pipe supports, a pressure gauge with a
    glass face, a temperature gauge, a hazard sign plate ("HOT SURFACE"), a nameplate ("COOP
    DRYER 01"), and pipe labels with flow arrows.

## 2. Hard numbers (1 Blender unit = 1 Roblox stud)

- **Bounding box: exactly 16 (X) x 12 (Y, height) x 14 (Z) studs**, measured over every mesh
  including the stack. Nothing may stick out beyond it.
- **Origin**: bottom centre of the slab, at (0, 0, 0). The slab underside sits on 0.
- **Orientation: copy `art/blender/Dryer.blend` (v1).** Open it, note which axis its feed end and
  its stack face, and build v2 in the same frame. Feed and input at the **low X side (west)**,
  discharge and output at the **high X side (east)**.
- **Game ports**: the game draws a 2 x 2 x 5 yellow plate just outside the walls. IN is at the
  centre of the west face, OUT at the centre of the east face, both centred **1.5 studs above the
  floor**. Leave a clear 2.5 stud wide, 3 stud tall gap at both, and make the feed chute and the
  outlet chute visibly end at them.
- **Stack top** at X = +5.6, Y = 11.7 (height), Z = -1.2 in the game frame (the game emits steam
  there). If your axes differ from the game frame, convert using the v1 file and say how.
- Drum: about 11 studs long, 4.4 studs diameter, axis 5.2 studs above the floor at its middle.

## 3. Roblox technical limits (must hold)

- **High-poly to low-poly workflow**: model a high-poly version with full bevels and detail, then
  a game mesh, and **bake normal and ambient occlusion maps** from high to low. Fine detail (weld
  beads, grating, bolts under 0.15 studs, panel lines, text) goes into the normal map, not the
  geometry.
- **Every game mesh is under 20,000 triangles** (Roblox's hard limit per mesh). Aim for **60,000
  to 90,000 triangles in total**, split into about **8 to 15 meshes** by material group and by
  moving part.
- Name meshes `DY_` + PascalCase, for example `DY_Drum`, `DY_DriveTrain`, `DY_Cyclone`,
  `DY_Walkway`, `DY_StrawBundles`. **Do not reuse the old `DR_` names**: the game repaints those.
- Keep `DY_Drum` (drum, riding rings and girth gear) as **one separate mesh with its origin on the
  drum axis**, so the game can spin it.
- **PBR textures for each mesh**: Base Color, Normal (OpenGL, Y+), Roughness and Metalness, at
  **1024 x 1024** (2048 only for the drum and furnace), PNG. Use a shared texture set where meshes
  share a material. Clean UVs: no overlaps except deliberate mirrored bolts, at least 4 px padding,
  consistent texel density.
- Glass and the fire window: a separate small mesh `DY_Emissive` (fire glow, screen, lamps) that
  the game makes Neon, and `DY_Glass` for gauge faces.
- No n-gons, all modifiers applied, normals facing out, smoothing from the low-poly hard edges.

## 4. Look

- Real materials: chipped teal industrial enamel over steel, galvanised grating, brushed steel
  shafts, cast iron, refractory brick with mortar, concrete, rubber, glass.
- Believable wear: edge chipping, rust streaks under bolts, heat discolouration near the furnace,
  soot on the stack and fire door, dust and straw fragments on horizontal surfaces, oil around the
  gearbox. Keep it a working machine, not a wreck.
- Every piece is supported and attached: no floating parts, no gaps at duct joints, no
  z-fighting.

## 5. Check your own work before reporting

1. Print the overall bounding box, each mesh's triangle count and the total. Fix anything over a
   limit.
2. Render, in Cycles with the textures, five 1920 x 1080 views: front three-quarter, back
   three-quarter, top-down, the feed end close up, and the drive train close up. Use a neutral HDRI
   or a sun plus sky on a light grey ground.
3. Look at the renders critically. Fix floating parts, gaps, stretched UVs, baking artefacts,
   and anything that does not read as real, then render again.

## 6. Deliver

- `art/blender/Dryer_v2.blend` (high-poly and game meshes in separate collections)
- `art/export/Dryer_v2.fbx`: game meshes only, FBX scale 1.0, apply transforms, the same axis
  settings as v1's export, no cameras or lights
- `art/export/Dryer_v2_textures/`: `<MeshName>_BaseColor.png`, `_Normal.png`, `_Roughness.png`,
  `_Metalness.png` for every textured mesh
- `art/renders/Dryer_v2_front.png`, `_back.png`, `_top.png`, `_feed.png`, `_drive.png`
- A short report: bounding box, triangles per mesh and in total, mesh list, texture list, the axis
  mapping you used, and anything you could not do.

# Prompt: Shredder v2, high-end (Burn or Build: PM2.5 Factory)

For the same agent that made `Dryer_v2.html` (three.js). Attach
`art/blender/Interactive 3D dryer model/Dryer_v2.html` as the style and code reference, then paste
everything below the line.

---

Build **Shredder_v2.html**, a companion to the attached `Dryer_v2.html`. Use the same code style
and helpers, the same quality bar, and the same procedural canvas textures (PBR maps, wear, dust).
Same game: a Roblox factory in Thailand that turns rice straw into fuel pellets instead of burning
it. This machine takes **dry rice straw bales** and shreds them into short chopped straw for the
pellet mill. Both machines stand side by side in the same factory, so it must look like it was
made by the same manufacturer as the dryer: the same teal enamel, yellow guards and concrete slab.

## The machine

A **straw hammer-mill shredder**, as used for biomass pelleting. Model real parts:

1. **Concrete slab** with a chamfered edge, anchor bolts and a yellow-and-black safety edge, as on
   the dryer.
2. **Infeed conveyor (west)**: an inclined rubber belt conveyor with side skirts and rollers. It
   carries a dry golden straw bale up into the feed throat. Add a hopper with stiffening ribs and
   a **feed roller pair** at the throat.
3. **Hammer-mill housing (centre)**: a heavy welded box with a curved top, bolted inspection
   doors with hinges and clamps, wear liners, and a **screen cassette** you can slide out on its
   handle.
4. **Drive**: a large electric motor on a slide base, a **V-belt drive** with a belt guard (one
   side mesh or cut away so the belts show), a big **flywheel pulley** on the rotor shaft, and
   **pillow-block bearings** with grease nipples.
5. **Dust and air**: a **discharge fan** with a spiral housing and its own motor, ducting to a
   **cyclone** on a braced stand with a rotary valve, and a short **vent stack** with a rain cap.
6. **Outfeed (east)**: a short outlet chute or screw conveyor carrying fluffy chopped straw (a
   loose pile of thin strands, not a block) out to the OUT port.
7. **Control cabinet** with a screen, indicator lamps and an e-stop. Add a cable tray to the
   motors, a guard-railed **service platform** with a short ladder at the housing, hazard plates
   ("ROTATING PARTS", "WEAR EAR PROTECTION") and a nameplate "COOP SHREDDER 01".

## Hard numbers (game frame, 1 unit = 1 stud)

- **Bounding box exactly 16 (X) x 10 (Y, height) x 14 (Z).** The origin is at the bottom centre
  of the slab and the slab underside sits on y = 0. Nothing may stick out, the stack included.
- **+X is east (OUT), -X is west (IN).** The game puts a 2 x 2 x 5 yellow port plate just outside
  the centre of each of those faces, centred **1.5 studs** above the floor. Keep a clear gap 2.5
  wide and 3 tall at both, and make the infeed conveyor start at IN and the outlet end at OUT.
- **The vent stack top is at (-4.4, 8.9, -4.6).** The game emits dust and steam there.
- About **60k to 90k triangles in total**. **Each named group must stay under 20k**: Roblox makes
  one mesh per group and material, with a hard limit of 20k.

## Groups (one THREE.Group each, direct children of the machine root)

`SH_Foundation`, `SH_Infeed`, `SH_Housing`, `SH_Drive`, `SH_Flywheel`, `SH_Fan`, `SH_Cyclone`,
`SH_Outfeed`, `SH_Platform`, `SH_Controls`, `SH_Details`, `SH_Straw`, `SH_Emissive`, `SH_Glass`.

- **`SH_Flywheel`** is the flywheel pulley and the visible shaft end. The game spins it. Put the
  group origin on the shaft axis, keep the **axis along Z**, and make its geometry **symmetric
  around the axis**, so the bounding-box centre is the axis. No belts in this group.
- **`SH_Emissive`**: the lamps, the screen and any lit labels. The game makes these neon.
  **`SH_Glass`**: gauge faces only. The game makes these see-through.
- **No lights, cameras or helpers inside the machine root.** Studio import turns them into
  warnings. Keep the stage lighting outside the root.
- Don't reuse the `DY_` names. Every name starts with `SH_`.

## Deliver

1. `Shredder_v2.html` with the same viewer as the dryer: orbit, a frame readout and a part list.
2. An **"Export GLB" button** that runs three.js `GLTFExporter` (binary) on the machine root only,
   with textures embedded, and downloads `Shredder_v2.glb`.
3. Shots in `shots/`: front three-quarter, back three-quarter, top, infeed close-up, drive
   close-up.
4. A short note: the bounding box, the triangles per group and in total, and anything you could
   not do.

Before you finish, check in the page itself that the bounding box is 16 x 10 x 14, every group is
under 20k triangles, and nothing floats or clips.

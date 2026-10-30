# Prompt: Pellet mill v2, high-end (Burn or Build: PM2.5 Factory)

For the same agent that made `Dryer_v2.html` and `Shredder_v2.html` (three.js). In a **new chat**,
attach `art/blender/Interactive 3D dryer model/Dryer_v2.html` and `Shredder_v2.html` as the style
and code reference, then paste everything below the line.

---

Build **PelletMill_v2.html**, the third machine of the line, after the attached `Dryer_v2.html`
and `Shredder_v2.html`. Use the same code style and helpers, the same quality bar, and the same
procedural canvas textures (PBR maps, wear, dust). Same game: a Roblox factory in Thailand that
turns rice straw into fuel pellets instead of burning it. This machine takes **shredded rice
straw** and presses it into **6 mm fuel pellets**, which it fills into wooden crates. It stands
next to the dryer and shredder, so it must look like the same manufacturer made it: the same teal
enamel, yellow guards and concrete slab. It is the biggest and most impressive machine of the
three, the one the player saves up for.

## The machine

A **ring-die biomass pellet line** on one slab, flowing west to east. Model real parts:

1. **Concrete slab** with a chamfered edge, anchor bolts and a yellow-and-black safety edge, as on
   the dryer and shredder.
2. **Infeed (west)**: a hopper with stiffening ribs receiving fluffy shredded straw (a loose
   heap of short strands showing over the rim), then an inclined **screw conveyor** in a round
   tube with flanged joints and a geared motor.
3. **Feeder and conditioner**: a variable-speed **feeder screw** with its own motor, over a long
   cylindrical **paddle conditioner** with a **steam inlet** (a lagged pipe with a valve,
   pressure gauge and a small steam trap). Inspection hatches with clamps.
4. **Pellet press (centre, the hero part)**: a heavy cast **gearbox housing** with cooling fins,
   driven by a big **main motor** through a coupling with a guard. On the front (-Z) face, the
   **die chamber door**, hinged, with a large round **inspection window**. Through it the
   **ring die** (a thick steel ring drilled with hundreds of small holes) and its two press
   rollers show. A thin stream of pellets drops from the die chamber into a chute.
5. **Cooling and screening**: a tall square **counter-flow cooler** with a level window and a
   rotary airlock, an exhaust fan and duct to a small **cyclone**, and a **vibrating screen**
   with a fines return pipe.
6. **Vent stack**: from the cooler cyclone, a stack with a rain cap. Its top is fixed (see below).
7. **Outfeed (east)**: a short pellet conveyor ending over a **slatted wooden crate** that is
   being filled with brown 6 mm pellets (real cylinders on top, a texture below), at the OUT
   port.
8. **Control cabinet** with a screen showing amps and die temperature, indicator lamps and an
   e-stop. Add cable trays, a guard-railed **service platform** with a ladder up to the feeder,
   a chain hoist on a small gantry over the die (for die changes), a spare ring die on a pallet,
   hazard plates ("HOT SURFACE", "ROTATING PARTS", "WEAR EAR PROTECTION") and a nameplate
   "COOP PELLET MILL 01".

## Hard numbers (game frame, 1 unit = 1 stud)

- **Bounding box exactly 18 (X) x 14 (Y, height) x 16 (Z).** The origin is at the bottom centre
  of the slab and the slab underside sits on y = 0. Nothing may stick out, the stack included.
- **+X is east (OUT), -X is west (IN).** The game puts a 2 x 2 x 5 yellow port plate just outside
  the centre of each of those faces, centred **1.5 studs** above the floor. Keep a clear gap 2.5
  wide and 3 tall at both, and make the infeed hopper start at IN and the crate sit at OUT.
- **The vent stack top is at (-2.4, 12.2, -5.2).** The game emits steam there.
- About **70k to 110k triangles in total**. **Each named group must stay under 20k**: Roblox
  makes one mesh per group and material, with a hard limit of 20k.

## Groups (one THREE.Group each, direct children of the machine root)

`PM_Foundation`, `PM_Infeed`, `PM_Conditioner`, `PM_Press`, `PM_Die`, `PM_Drive`, `PM_Cooler`,
`PM_Screen`, `PM_Outfeed`, `PM_Platform`, `PM_Hoist`, `PM_Controls`, `PM_Details`, `PM_Straw`,
`PM_Pellets`, `PM_Emissive`, `PM_Glass`.

- **`PM_Die`** is the ring die and its two rollers behind the window. The game spins it while
  the machine works. Put the group origin on the die axis, keep the **axis along Z**, and make
  the die **symmetric around the axis**, so the bounding-box centre is the axis. The rollers may
  sit inside it.
- **`PM_Emissive`**: the lamps, the screen and any lit labels. The game makes these neon.
  **`PM_Glass`**: the die window and gauge faces only. The game makes these see-through, so the
  die must be visible behind the window.
- **No lights, cameras or helpers inside the machine root.** Studio import turns them into
  warnings. Keep the stage lighting outside the root.
- Don't reuse the `DY_` or `SH_` names. Every name starts with `PM_`.

## Deliver

1. `PelletMill_v2.html` with the same viewer as the dryer: orbit, a frame readout and a part list,
   and a toggle that spins `PM_Die` to preview it.
2. An **"Export GLB" button** that runs three.js `GLTFExporter` (binary) on the machine root only,
   with textures embedded, and downloads `PelletMill_v2.glb`.
3. Shots in `shots/`: front three-quarter, back three-quarter, top, a die window close-up and an
   outfeed crate close-up, plus one shot with the dryer, shredder and pellet mill side by side.
4. A short note: the bounding box, the triangles per group and in total, and anything you could
   not do.

Before you finish, check in the page itself that the bounding box is 18 x 14 x 16, every group is
under 20k triangles, and nothing floats or clips.

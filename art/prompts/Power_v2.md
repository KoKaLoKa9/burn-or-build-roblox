# Prompt: Power pack v2, high-end (Burn or Build: PM2.5 Factory)

For the same three.js agent that made `Dryer_v2.html` and `Shredder_v2.html`. In a **new chat**,
attach both pages as the style and code reference, then paste everything below the line.

---

Build **Power_v2.html**: the six power machines of the same game, a Roblox factory in Thailand that
turns rice straw into fuel pellets instead of burning it. Use the same code style and helpers, the
same quality bar and the same procedural canvas PBR textures (wear, dust, rust streaks, oil
stains). They stand next to the dryer and shredder, so they must look like the same world: the
teal enamel and yellow guards of the factory machines where it fits, concrete pads with anchor
bolts and yellow-and-black safety edges, real industrial detail (bolts, cable glands, conduit,
nameplates, hazard stickers). Not toy-like.

The pack also tells the game's story: the player starts with cheap, clean, weak power and moves
up to strong power that pollutes. The **hand crank** and **solar panel** look humble and
home-made but clean. The **straw furnace** looks hot and smoky but filtered. The **diesel
generator** looks strong, loud and dirty (soot around the exhaust, oil under the skid).

## Shared rules (game frame, 1 unit = 1 stud)

- Each machine is **its own root**, named exactly by its game id: `HandCrank`, `SolarPanel`,
  `PowerPole`, `Battery`, `StrawGenerator`, `DieselGenerator`.
- The origin of each root is at the **bottom centre** and its underside sits on y = 0. **+X is
  east, -X is west** (the fuel side, where the game's IN port is).
- Inside each root, put the parts in **named groups**, each a direct child of the root, with the
  machine's prefix (see each machine). Name meshes `<Group>_<Part>`.
- **`<Prefix>_Emissive`**: lamps, displays and the fire glow; the game makes these neon.
  **`<Prefix>_Glass`**: gauge faces and windows only; the game makes these see-through.
- **Wire point:** every machine except the pole has one small hidden marker mesh named
  **`<Prefix>_WireTop`** (a 0.2 cube) at the spot where the power cable leaves the machine, an
  insulator or a terminal at the given position. The game strings the cable from there.
- **No lights, cameras, helpers or ground planes inside any root.** **Every mesh under 20,000
  triangles.** Share one texture set per material across the pack, 512 to 1024 px.
- **Bounding boxes are exact maximums.** Nothing may stick out, unless the machine says so.

## The machines

### 1. Hand crank (`HandCrank`, prefix `HC_`), 6 x 5 x 6, 6k to 15k triangles

The starting generator: a farmer's **hand-cranked dynamo** on a heavy timber base. A cast-iron
dynamo body with cooling slots and a brass nameplate, a belt or gear train to a big **spoked
flywheel** on the +X side with a **wooden handle** on its rim, a small analog voltmeter, a
knife switch, and a cable running up a short post to a porcelain insulator. Timber base with iron
straps and lag bolts, a worn patch on the ground where people stand to crank.

- **`HC_Wheel`**: the flywheel, its spokes and the handle. The game spins it while someone
  cranks. Put the group origin on the wheel axis, the **axis along X**, at about **(2.2, 2.6, 0)**,
  and make the wheel symmetric so the bounding-box centre is the axis (the handle may unbalance
  it slightly, that is fine).
- `HC_WireTop` at about **(-0.6, 4.4, 0)**.
- Groups: `HC_Base`, `HC_Dynamo`, `HC_Wheel`, `HC_Details`, `HC_Glass`, `HC_WireTop`.

### 2. Solar panel (`SolarPanel`, prefix `SP_`), 8 x 4 x 8, 8k to 18k triangles

A small **ground-mounted solar array**: two framed monocrystalline panels side by side on a
galvanised steel rack, **tilted 15 to 18 degrees toward -Z**, the low edge on -Z. Real cells
(dark blue-black squares with thin silver busbars and the white cell gaps), an aluminium frame,
a junction box with cables under the panel, a small **charge controller** box on a rack leg with a
green status LED, concrete foot blocks. A little dust and dried leaves on the low edge.

- **`SP_Cells`**: the cell surfaces only (glossy, slightly reflective glass look). The game
  dims them under smog.
- `SP_Emissive`: the controller LED. `SP_WireTop` at about **(2.8, 1.6, 2.8)** on the controller.
- Groups: `SP_Rack`, `SP_Frame`, `SP_Cells`, `SP_Controller`, `SP_Emissive`, `SP_WireTop`.

### 3. Power pole (`PowerPole`, prefix `PO_`), 6k to 12k triangles

A **Thai rural wooden distribution pole**: a tarred hardwood or concrete pole on a small concrete
collar, a **crossarm** with steel braces, two **porcelain insulators** on top of the crossarm and
a **copper coil or bus clamp** on each. A small danger sign ("อันตราย" with a lightning bolt), a
numbered tag, a grounding wire running down the side.

- The pole base fits in **2 x 2**. The crossarm may stick out to **z = +-2.6**. The top is
  **y = 14.8** at most.
- The two coils are **separate groups `PO_Coil1` and `PO_Coil2`**, centred at
  **(0, 14.2, -2)** and **(0, 14.2, 2)**, each about 1.2 across. The player clicks them to
  string wires, and the game hangs the wires from their centres.
- Groups: `PO_Pole`, `PO_Crossarm`, `PO_Insulators`, `PO_Coil1`, `PO_Coil2`, `PO_Details`.

### 4. Battery bank (`Battery`, prefix `BB_`), 6 x 6 x 6, 10k to 18k triangles

A **lead-acid battery bank** in a ventilated steel cabinet with the front (+Z) door open or
missing, so the cells show: three rows of large translucent green-grey **2 V cells** with visible
plates and electrolyte level lines, red and black terminals, copper bus bars between them, a
battery management box with a small display, a cable gland on top and a "NO SMOKING / ACID"
warning plate. Concrete pad, drip tray.

- **`BB_Level1` to `BB_Level4`**: four separate small lamp segments in a vertical bar on the
  cabinet front (bottom to top). The game lights as many as the charge allows. Keep them
  emissive green.
- `BB_WireTop` at about **(0, 5.7, 0)** on the top cable gland.
- Groups: `BB_Cabinet`, `BB_Cells`, `BB_Busbars`, `BB_Controls`, `BB_Level1`, `BB_Level2`,
  `BB_Level3`, `BB_Level4`, `BB_Glass`, `BB_WireTop`.

### 5. Straw furnace generator (`StrawGenerator`, prefix `SG_`), 14 x 12 x 12, 50k to 80k triangles

A small **biomass steam power unit** that burns bales of dry rice straw, flowing west to east:

1. **Fuel side (-X)**: a short sloped feed chute starting at the IN port, then a **bale feeder**
   (a ram or a pair of rollers) into a **firebrick furnace** with a steel casing, a fire door
   with a round sight glass showing flames, ash pit door, a pile of grey ash in a wheelbarrow.
2. **Boiler**: a horizontal fire-tube boiler drum on top of the furnace, lagged in grey cladding
   with steel bands, a pressure gauge, a water gauge glass, a safety valve.
3. **Flue gas cleaning**: a **cyclone** and a **bag filter house** with a rotary valve, then the
   **chimney**. The chimney top is fixed (see below). A light soot stain at the chimney top only.
4. **Power side (+X)**: a small **steam engine or turbine** coupled to a **teal generator** with
   cooling fins, a coupling guard, a control panel with an ammeter, voltmeter and a red lamp, and
   the cable going up to an insulator.

- **The chimney top is at (4, 12, 0)**, the very top of the box. The game emits smoke there.
- **-X is IN**: the game puts a 2 x 2 x 5 yellow port plate just outside the centre of the -X
  face, 1.5 studs above the floor. Keep a clear opening **2.5 wide and 3 tall** there and make
  the feed chute start at it.
- **`SG_Fire`**: the flames and glowing coals seen through the sight glass and fire door gaps.
  The game makes them neon and flickers them while it burns.
- `SG_WireTop` at about **(4, 8, -4)**.
- Groups: `SG_Foundation`, `SG_Feeder`, `SG_Furnace`, `SG_Boiler`, `SG_Filter`, `SG_Chimney`,
  `SG_Engine`, `SG_Generator`, `SG_Controls`, `SG_Details`, `SG_Fire`, `SG_Emissive`,
  `SG_Glass`, `SG_WireTop`.

### 6. Diesel generator (`DieselGenerator`, prefix `DG_`), 12 x 8 x 8, 30k to 55k triangles

A **skid-mounted diesel genset** in a **yellow sound-proof canopy**: louvred side panels with one
panel open (+Z side) so the engine, radiator and alternator show, lockable doors with hinges,
lifting eyes on the roof, a radiator grille on the +X end, a **base fuel tank** in the skid with
a filler cap and fuel gauge, a control panel behind a small window (hour meter, gauges, a key
switch, an emergency stop), a battery, a "DANGER HIGH VOLTAGE" plate and a manufacturer-style
nameplate "COOP GENSET 20 kVA". Oil drips and a dark stain under the skid, a jerry can beside
it.

- **The exhaust stack** with a rain flap rises on the -X end, its **top at (-4, 8, 0)**. The
  game puts smoke there. Heavy soot around the outlet.
- **`DG_Flap`**: the rain flap alone. The game rattles it while the engine runs. Put the group
  origin on its hinge.
- `DG_WireTop` at about **(3, 6.4, 0)** on a cable gland on the roof.
- Groups: `DG_Skid`, `DG_Canopy`, `DG_Engine`, `DG_Alternator`, `DG_Radiator`, `DG_Exhaust`,
  `DG_Flap`, `DG_Controls`, `DG_Details`, `DG_Emissive`, `DG_Glass`, `DG_WireTop`.

## Deliver

1. `Power_v2.html` with the same viewer as the dryer: a machine picker, orbit, a frame readout
   and a part list, plus toggles that preview the animations (spin `HC_Wheel`, flicker
   `SG_Fire`, rattle `DG_Flap`, step through the `BB_Level` lamps).
2. **An "Export GLB" button for each machine** (GLTFExporter, binary, textures embedded, that
   machine's root only) that downloads `<id>.glb`, for example `StrawGenerator.glb`, plus an
   "Export all" button that downloads the six files.
3. Shots in `shots/power/`: each machine at front three-quarter and back three-quarter, a
   close-up of the hand crank wheel, the solar cells, the battery cells, the straw furnace fire
   door and the diesel's open panel, and one line-up of all six at the same scale next to the
   attached dryer.
4. A short note: each machine's bounding box and triangles per group and in total, and anything
   you could not do.

Before you finish, check in the page itself that each bounding box is within its size (the pole
within 2.6 in Z and 14.8 tall), the chimney and exhaust tops and the coil centres are where
stated, every mesh is under 20k triangles, and nothing floats or clips.

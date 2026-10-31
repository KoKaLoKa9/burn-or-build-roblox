# Prompt: Water and steam pack v2, high-end (Burn or Build: PM2.5 Factory)

For the same three.js agent that made `Power_v2.html`. In the **same chat** that made the power
pack (or a new chat with `Power_v2.html`, `power_lib.js` and `Dryer_v2.html` attached), paste
everything below the line.

---

Build **WaterSteam_v2.html**: the four water and steam machines of the same game. Reuse the power
pack's code, helpers, viewer, checks and shared textures, at the same quality bar. These machines
are researched after the power pack: the player pumps groundwater, stores it, boils it with dry
rice straw and turns the steam into much more power than the straw furnace generator gives. They
must look like the same manufacturer as the dryer and the power machines: teal enamel, yellow
guards, galvanised steel, concrete pads with anchor bolts and yellow-and-black safety edges, and
real industrial detail. Not toy-like.

## Shared rules (game frame, 1 unit = 1 stud)

Everything from the power pack still applies: one root per machine named by its game id, origin
at the bottom centre with the underside on y = 0, **+X east, -X west**, **-Z north, +Z south**,
named groups with the machine's prefix, `<Prefix>_Emissive` and `<Prefix>_Glass`, a hidden 0.2
cube `<Prefix>_WireTop` where the power cable attaches, no lights, cameras or helpers, every mesh
under 20k triangles, one shared texture set, exact bounding boxes.

**Ports.** The game links the machines with the pipe and belt kit (`Conveyor_v2.html`). At each
port the game places a kit piece **flush against the machine wall**, so every port must meet it:

- **Pipe port (water or steam):** a short **flanged nozzle** whose flange face lies **exactly on
  the machine's outer face**, centred on the given spot, pipe **centre 1.5 studs above the
  floor**, pipe outer diameter **1.2**, flange about 1.8 across with bolts. Paint water nozzles
  with a blue band and steam nozzles with a red band. Name the nozzles `<Prefix>_Port<Name>`.
- **Belt port (straw):** keep a **clear opening 2.5 wide and 3 tall**, centred at 1.5 studs high,
  and start the feed chute there, as on the straw furnace generator.
- Nothing else may stick out of a face that has a port, within 1.5 studs of the port.

## The machines

### 1. Water pump (`WaterPump`, prefix `WP_`), 8 x 7 x 8, 12k to 25k triangles

A **borehole pump station** on a concrete pad: a steel **wellhead** with a cap and a flanged
riser, a **vertical multistage pump** with a teal motor on top (fan cowl, terminal box, cable
gland), a pressure gauge, a check valve and a gate valve, a **small pressure vessel** (blue
diaphragm tank), a starter box with a green run lamp, a tin roof on two posts to shade the motor.
Wet concrete and a little rust around the wellhead.

- **No IN port.** **OUT, water, East centre**: `WP_PortOut` nozzle at **(4, 1.5, 0)**.
- **`WP_Fan`**: the motor's fan behind the cowl grille, spinning about **Y**; group origin on
  its axis.
- `WP_WireTop` at about **(-1, 6.6, 0)** under the roof.
- Groups: `WP_Pad`, `WP_Wellhead`, `WP_Pump`, `WP_Motor`, `WP_Fan`, `WP_Piping`, `WP_Roof`,
  `WP_Controls`, `WP_Details`, `WP_PortOut`, `WP_Emissive`, `WP_Glass`, `WP_WireTop`.

### 2. Water tank (`WaterTank`, prefix `WT_`), 8 x 10 x 8, 10k to 20k triangles

A **raised water tank** typical of Thai villages: a round **corrugated galvanised steel tank**
(or a pale blue polyethylene one with moulded ribs) on a **steel stand** with cross bracing, a
ladder with a safety cage up to a roof hatch, an overflow pipe, a **sight-glass level gauge** on
the side, and two pipes running down the legs to the nozzles at the bottom.

- **IN, water, West centre**: `WT_PortIn` at **(-4, 1.5, 0)**. **OUT, water, East centre**:
  `WT_PortOut` at **(4, 1.5, 0)**.
- **`WT_Level`**: the water column inside the sight glass, a separate mesh **scaled from its
  bottom** (put its origin at the bottom of the gauge, full height when scale.y = 1). The game
  scales it with the stored water.
- No power, so **no WireTop**.
- Groups: `WT_Stand`, `WT_Tank`, `WT_Ladder`, `WT_Piping`, `WT_Gauge`, `WT_Level`,
  `WT_PortIn`, `WT_PortOut`, `WT_Details`, `WT_Glass`.

### 3. Straw boiler (`Boiler`, prefix `BO_`), 14 x 12 x 12, 50k to 80k triangles

A **straw-fired fire-tube steam boiler**, bigger and more serious than the straw furnace
generator's firebox. West to east:

1. **Fuel side (-X)**: a bale feed chute from the IN opening, a **hydraulic ram feeder**, the
   **firebrick furnace** with a fire door and sight glass, an ash door and a full ash bin.
2. **Boiler shell**: a big horizontal drum in grey lagging with steel bands, a manhole, a
   **water gauge glass**, two pressure gauges, **two safety valves** with drain pipes, a main
   steam valve with a handwheel, a feed water pump with a teal motor on the north side.
3. **Flue**: an economiser box and a **brick or steel chimney** (top fixed, see below), with a
   little soot at the top.
4. A control panel with a burner lamp, a low-water alarm lamp and a pressure display, a
   catwalk with a handrail and ladder along the top of the drum, a "HIGH PRESSURE STEAM" plate
   and a nameplate "COOP STRAW BOILER 01".

- **IN, dry straw (belt), West centre**: the clear 2.5 x 3 opening at x = -7.
- **IN, water, North centre**: `BO_PortWater` at **(0, 1.5, -6)**.
- **OUT, steam, East centre**: `BO_PortOut` at **(7, 1.5, 0)**. Run the steam line from the main
  valve down to it, lagged.
- **The chimney top is at (-3, 13, 3)**. It is the one part allowed above the 12-stud box (up to
  y = 13). The game emits smoke there.
- **`BO_Fire`**: flames and glowing coals behind the sight glass and door gaps (neon, flickered by
  the game).
- `BO_WireTop` at about **(5, 9, -4)**.
- Groups: `BO_Foundation`, `BO_Feeder`, `BO_Furnace`, `BO_Shell`, `BO_Fittings`, `BO_Pump`,
  `BO_Chimney`, `BO_Catwalk`, `BO_Controls`, `BO_Details`, `BO_PortWater`, `BO_PortOut`,
  `BO_Fire`, `BO_Emissive`, `BO_Glass`, `BO_WireTop`.

### 4. Steam turbine (`SteamTurbine`, prefix `ST_`), 14 x 8 x 8, 35k to 60k triangles

A **small single-stage steam turbine generator set** on a concrete bed, west to east: the
**steam inlet** with a stop valve and a governor valve, the **turbine casing** (split horizontally,
with a row of flange bolts along the joint, lagged in grey), a **gearbox**, a coupling under a
yellow guard, and a big **teal generator** with cooling fins and a terminal box. Add an oil
console with a small tank, filters and an oil pressure gauge, an exhaust steam pipe going down
into the bed, a local control panel with a speed display and a green run lamp, a "ROTATING
PARTS" plate and a nameplate "COOP STEAM TURBINE 50 kW".

- **IN, steam, West centre**: `ST_PortIn` at **(-7, 1.5, 0)**. No OUT port.
- **`ST_Shaft`**: the exposed shaft and coupling under the guard (visible through the guard
  mesh), spinning about **X**; group origin on its axis.
- `ST_WireTop` at about **(5, 6.4, 0)** on the generator's terminal box.
- Groups: `ST_Bed`, `ST_Inlet`, `ST_Casing`, `ST_Gearbox`, `ST_Shaft`, `ST_Guard`,
  `ST_Generator`, `ST_Oil`, `ST_Controls`, `ST_Details`, `ST_PortIn`, `ST_Emissive`, `ST_Glass`,
  `ST_WireTop`.

## Deliver

1. `WaterSteam_v2.html` with the power pack's viewer: machine picker, orbit, frame readout, part
   list, the checks, and preview toggles (spin `WP_Fan` and `ST_Shaft`, flicker `BO_Fire`, slide
   `WT_Level` from empty to full).
2. **An "Export GLB" button for each machine** that downloads `<id>.glb` (for example
   `Boiler.glb`), plus "Export all".
3. A **chain view**: pump, tank, boiler and turbine in a row with the attached conveyor kit's
   `PP_` pieces joining the ports (water blue, steam red), to prove the nozzles meet the pipes
   with no gap.
4. Shots in `shots/watersteam/`: each machine at front and back three-quarter, close-ups of the
   pump motor, the tank gauge, the boiler fire door and the turbine coupling, a close-up of one
   nozzle meeting a `PP_Port` piece, and the chain view.
5. A short note: each machine's bounding box and triangles per group and in total, and anything
   you could not do.

Before you finish, check in the page itself that each bounding box is within its size (the boiler
chimney up to 13), every port nozzle's flange face is on the outer face at the stated centre,
the boiler chimney top is at (-3, 13, 3), every mesh is under 20k triangles, and nothing floats
or clips.

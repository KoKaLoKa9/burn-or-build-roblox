# Prompt: Buyer depot and straw collection point v2, high-end (Burn or Build: PM2.5 Factory)

For the same three.js agent that made `Power_v2.html`. In the **same chat** (or a new chat with
`Power_v2.html`, `power_lib.js` and `Dryer_v2.html` attached), paste everything below the line.

---

Build **Depot_v2.html**: the two fixed buildings at each end of the factory line in the same game.
Reuse the power pack's code, helpers, viewer, checks and shared textures, at the same quality bar.
Wet rice straw comes **in** at the collection point, and crates of fuel pellets go **out** at the
buyer depot. Players see both all the time, so they must read clearly from a distance as "drop
straw here" and "sell pellets here", **without any floating sign**: the building itself says what
it is. Same world as the dryer and the power machines: teal enamel, yellow guards, galvanised
steel, concrete with anchor bolts and yellow-and-black safety edges, a rural Thai setting.

## Shared rules (game frame, 1 unit = 1 stud)

Everything from the power pack still applies: one root per building named by its game id, origin
at the bottom centre with the underside on y = 0, **+X east, -X west**, **-Z north, +Z south**,
named groups with the prefix, `<Prefix>_Emissive` and `<Prefix>_Glass`, no lights, cameras or
helpers, every mesh under 20k triangles, one shared texture set, exact bounding boxes.

**Belt ports.** The game links buildings with the conveyor kit (`Conveyor_v2.html`), whose port
pieces sit **flush against the wall**. At every belt port keep a clear opening **2.5 wide and 3
tall**, its bottom on the floor, centred on the stated spot, and nothing within 1.5 studs of it on
that face.

## 1. Straw collection point (`CollectionPoint`, prefix `CP_`), 12 x 10 x 12, 25k to 45k triangles

The farmers' drop-off where players carry bundles of **wet rice straw** from the fields. A
**covered intake shed**: a steel-framed **pitched roof** in teal corrugated sheet on four posts,
open on all sides so players walk in, over a concrete pad with a **receiving hopper** (a big
steel trough with a grid over it) half full of loose wet straw. A short inclined **belt** carries
straw from the hopper out through the east side. Around it: a few **straw bundles** tied with
twine stacked against a post, a **platform scale** with a dial, a chalkboard tally on a post
(blank, no words), a wheelbarrow, a hand cart, a hose reel, a water drum, rubber boots by a post.
The roof gutter drips a little; the pad is damp and darker near the hopper.

- **OUT, belt, East centre**: the clear opening at **x = 6**, centred on z = 0. The outgoing belt
  ends at it.
- The **front is south (+Z)**: the open side players walk in from, with a yellow painted walkway
  and a big painted **straw bundle symbol** on the pad (a pictogram, not words).
- **`CP_Straw`**: the loose straw in the hopper, a separate mesh **scaled from its bottom** (origin
  at the hopper floor, full when scale.y = 1). The game fills it as straw is deposited.
- **`CP_Emissive`**: a small amber beacon on the roof ridge that the game lights when the point is
  full.
- The roof ridge is at **y = 10**. The game puts a small counter board at about y = 11.
- Groups: `CP_Pad`, `CP_Frame`, `CP_Roof`, `CP_Hopper`, `CP_Belt`, `CP_Straw`, `CP_Props`,
  `CP_Details`, `CP_Emissive`, `CP_Glass`.

## 2. Buyer depot (`BuyerDepot`, prefix `BD_`), 44 x 20 x 36, 60k to 100k triangles

The regional **biomass fuel buyer**: the big landmark at the east end of the district where
players' pellet crates are sold. A **steel-framed warehouse** with a low-pitched roof, teal
cladding with a white band, roof skylights, gutters and downpipes, roof vents. Model:

1. **West face (the receiving side)**: a raised **loading dock** along the whole west wall, with
   **three receiving bays**, each a roller shutter door (half open), a **powered roller conveyor**
   coming out of the door down to floor level, dock bumpers, a yellow bollard pair and bay numbers
   1, 2, 3 painted above.
2. **Inside, visible through the open shutters**: rows of **pallets stacked with wooden pellet
   crates** and **bulging 1-tonne bulk bags** of brown pellets, a forklift, racking.
3. **North side**: a **truck loading bay** with a parked **flatbed truck** being loaded with bulk
   bags, and a weighbridge in front of it.
4. **South side**: a small **office annex** with windows, a door, an AC unit and a few potted
   plants, and a **big painted logo on the main wall**: a stylised flame inside a leaf (a
   pictogram, not words).
5. A **pellet silo** (a round galvanised bin on legs, about 6 across and 18 tall) beside the north
   east corner, with a ladder and a discharge spout.
6. Ground: a concrete yard with painted lines and safety edges, a few drums, a pallet stack, a
   lamp post at each corner.

- **IN, belt, West face**: three clear openings at **x = -22**, centred at **z = -8, 0 and 8**.
  Each bay's roller conveyor ends exactly at its opening, at belt height (top **y = 1.32**).
- The silo top is the tallest point, at most **y = 20**.
- **`BD_Emissive`**: the lamp post heads, the office windows and a green "receiving" lamp over
  each bay. **`BD_Glass`**: the skylights and office windows.
- **`BD_Shutter1`, `BD_Shutter2`, `BD_Shutter3`**: each bay's roller shutter alone, so the game
  can raise it. Group origin at the shutter's top roll.
- Groups: `BD_Yard`, `BD_Building`, `BD_Roof`, `BD_Dock`, `BD_Bays`, `BD_Shutter1`,
  `BD_Shutter2`, `BD_Shutter3`, `BD_Interior`, `BD_Office`, `BD_Truck`, `BD_Silo`,
  `BD_Details`, `BD_Emissive`, `BD_Glass`.

## Deliver

1. `Depot_v2.html` with the power pack's viewer: a building picker, orbit, frame readout, part
   list, the checks, and preview toggles (fill `CP_Straw` from empty to full, light
   `CP_Emissive`, raise the `BD_Shutter` groups).
2. **An "Export GLB" button for each building** that downloads `<id>.glb`
   (`CollectionPoint.glb`, `BuyerDepot.glb`), plus "Export all".
3. A **link view**: the collection point and the buyer depot with the attached conveyor kit's
   `CV_PortOut` and `CV_PortIn` pieces against their openings, to prove the belts meet them with no
   gap.
4. Shots in `shots/depot/`: each building at front and back three-quarter and from 60 studs away
   (to judge if it reads without a sign), close-ups of the collection point hopper and of one depot
   bay with its port piece, and the link view.
5. A short note: each building's bounding box and triangles per group and in total, and anything
   you could not do.

Before you finish, check in the page itself that each bounding box is within its size, every belt
opening is clear at the stated spot, the bay conveyors end at the openings at belt height, every
mesh is under 20k triangles, and nothing floats or clips.

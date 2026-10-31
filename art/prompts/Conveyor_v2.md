# Prompt: Conveyor and pipe kit v2, high-end (Burn or Build: PM2.5 Factory)

For the same three.js agent that made `Dryer_v2.html` and `Shredder_v2.html`. In a **new chat**,
attach both pages as the style and code reference, then paste everything below the line.

---

Build **Conveyor_v2.html**: a modular kit of belt conveyor and pipe pieces for the same game, a
Roblox factory in Thailand that turns rice straw into fuel pellets. Players lay these pieces one
grid cell at a time between the dryer, shredder and pellet mill, so they must look like the same
manufacturer made them: the same teal enamel, yellow guards, galvanised steel, wear and dust, the
same procedural canvas PBR textures. Real industrial detail (troughing idlers, bolted frames,
belt splices, flanges), not toy-like.

## How the game uses the pieces

- The factory floor is a grid of **4 x 4 stud cells**. Every tile piece fills exactly one cell,
  **4 (X) x 4 (Z)**, with its origin at the **cell centre on the floor** (y = 0).
- A belt or pipe always flows **toward +X** in the piece's own frame. The game turns pieces in
  90 degree steps. Seen from above with +X pointing right, **-Z is the left side** and **+Z is
  the right side**.
- Pieces sit next to each other with no gap, so every open end must **meet the cell edge exactly**
  (x = +-2 or z = +-2) at the same height and width, and line up with the neighbour's open end.
- Where a belt or pipe reaches a machine, there is a gap of **1, 2 or 3 studs** between the last
  cell edge and the machine wall. The **bridge** pieces fill that gap, and the **port** pieces
  finish the join against the machine wall. With them a line looks continuous from one machine to
  the next.
- The machines leave a clear opening at each port: **2.5 studs wide and 3 tall, centred 1.5 studs
  above the floor** in the middle of the wall.

## Belt conveyor pieces (prefix `CV_`)

Belt surface top at **y = 1.32**, inner belt width **3.0**, frame outer width **3.9**, side
guards up to **y = 1.9**. Straw bundles, sacks and crates up to 1.5 x 1.4 x 1.5 ride on the belt,
so keep the guards low enough to see them. Every belt piece has a yellow chevron printed on the
belt pointing +X, a dark rubber belt with a visible splice, idler rollers under it, a bolted teal
frame and galvanised legs with foot plates. Budget **800 to 2,500 triangles per piece**.

| Group | Open ends | Notes |
| --- | --- | --- |
| `CV_Straight` | -X in, +X out | Guards on both sides. |
| `CV_TurnLeft` | -Z in (left), +X out | A **curved belt** on a quarter turn, guard on the outside of the curve. |
| `CV_TurnRight` | +Z in (right), +X out | The mirror of TurnLeft, modelled, not just turned. |
| `CV_MergeLeft` | -X and -Z in, +X out | A side-feed merge: a short feeder joins the main belt with a transfer plate. |
| `CV_MergeRight` | -X and +Z in, +X out | The mirror of MergeLeft. |
| `CV_MergeSides` | -Z and +Z in, +X out | Two side feeders meeting into one belt. |
| `CV_MergeAll` | -X, -Z and +Z in, +X out | Three inputs. |
| `CV_Start` | +X out only | A tail pulley end with an end guard on -X. |
| `CV_Bridge1`, `CV_Bridge2`, `CV_Bridge3` | -X in, +X out | Straight belt **1, 2 and 3 studs long** along X (Z width 4), origin at the centre. No legs on Bridge1. |
| `CV_PortIn` | -X in | Sits **flush against a machine wall on its +X face**: a transfer chute that narrows the belt to the 2.5 opening, with a rubber curtain flap, a steel collar flange and bolts. **1 stud long (X)**, origin at the centre of its -X end on the floor. |
| `CV_PortOut` | +X out | The same idea at an output: a discharge lip and skirt flush against a machine wall on its **-X** face, feeding the belt. **1 stud long**, origin at the centre of its +X end on the floor. |

## Pipe pieces (prefix `PP_`)

One kit serves water and gas, so the pipe is **tintable**: name the pipe body meshes with the
suffix `_Tint` and make their Base Color light grey (about 200, 200, 200) carrying only the detail
(weld seams, stains, paint wear). The game colours them blue for water and yellow for gas. Flanges,
bolts, brackets and supports stay steel. Pipe **centre at y = 1.5**, pipe outer diameter **1.2**.
Every open end finishes in a **bolted flange at the cell edge**. Budget **600 to 2,000 triangles
per piece**.

| Group | Open ends | Notes |
| --- | --- | --- |
| `PP_Straight` | -X, +X | A pipe on a steel saddle support with a U-bolt. |
| `PP_Elbow` | -Z, +X | A long-radius 90 degree elbow. |
| `PP_Tee` | -X, -Z, +X | A welded tee. |
| `PP_Cross` | all four | A cross. |
| `PP_End` | +X | A blind flange on -X, with a drain valve. |
| `PP_Bridge1`, `PP_Bridge2`, `PP_Bridge3` | -X, +X | Straight pipe **1, 2 and 3 studs long**, origin at the centre. |
| `PP_Port` | -X | A machine nozzle **flush against a wall on its +X face**: a wall flange with bolts, a short spool and a hand valve with a wheel. 1 stud long, origin at the centre of its -X end on the floor. |
| `PP_FlowArrow` | none | A small separate arrow plate (white, about 0.8 long) that clamps on top of a pipe, pointing +X. The game adds it to show flow. |

## Rules

- Each piece is **one THREE.Group, a direct child of the kit root**, named as in the tables.
  Inside it, name meshes `<Group>_<Part>` (for example `CV_Straight_Belt`, `PP_Elbow_Tint`).
- Name the belt surface mesh of every belt piece `<Group>_Belt`, so the game can find it.
- **No lights, cameras, helpers or ground planes inside the kit root.** **Every mesh under 20,000
  triangles.**
- Share one texture set per material across all pieces (belt rubber, teal enamel, galvanised
  steel, pipe), 512 to 1024 px.

## Deliver

1. `Conveyor_v2.html` with the same viewer as the dryer: orbit, a part list and the checks.
2. A **test layout** on the page (outside the kit root): a short belt line with a straight run,
   both turns, a merge, bridges of each length and both port pieces against two grey 16 x 10 x 14
   stand-in machine boxes, plus a water line and a gas line with every pipe piece. It should look
   seamless end to end.
3. An **"Export GLB" button** (GLTFExporter, binary, textures embedded, kit root only) that
   downloads `Conveyor_v2.glb`.
4. Shots in `shots/conveyor/`: the test layout from above at 45 degrees and from eye height
   (5 studs), a close-up of each port piece against its machine box, and the pipe line.
5. A short note listing each piece's size and triangles.

Before you finish, check in the page that every tile piece's open ends meet the cell edges at
exactly x = +-2 or z = +-2, the bridges are exactly 1, 2 and 3 long, and every mesh is under 20k.

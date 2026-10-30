# Prompt: Environment v2 fixes (Burn or Build: PM2.5 Factory)

For the same three.js agent, in the chat that made each pack (or a new chat with that pack's page
and its `env_*_lib.js` attached). Paste only the block for that pack. Keep everything that is not
listed here exactly as it is: names, sizes, budgets, the export button and the checks all passed.

---

## Flora fixes (`Env_Flora_v2.html`)

Revise only these four assets. Keep their names, size ranges and triangle budgets.

1. **`EV_UmbrellaPine_A`, `_B` is the wrong tree.** It reads as stacked flat tiers on a straight
   pole, like a fir. Make a **Thai hill pine (*Pinus kesiya / merkusii*)**: a slightly crooked
   reddish trunk with plated bark, bare for the lower two thirds, a few long branches curving up
   and out, ending in a **broad, flat-topped, irregular canopy** of dense needle clumps (alpha
   cards). From the side the crown is an uneven umbrella, wider than it is tall, with sky showing
   through gaps.
2. **`EV_StrawStack_A`, `_B` reads as a round ball with banded rings.** A Thai field straw stack
   (*lom fang*) is built **around a tall central pole**: a near-vertical shaggy body for the lower
   two thirds, then a **cone-shaped top** tapering to the pole tip, which sticks out. The outline
   is loose and uneven with strands hanging off, the top is sun-bleached grey, there is a skirt of
   fallen straw on the ground around the foot, and on B a bite taken out of one side where cattle
   have eaten. No horizontal stripes.
3. **`EV_SugarPalm_A`, `_B`, `_C`: the trunk texture looks like stacked bricks.** Make the leaf
   scars **irregular and subtle** (uneven spacing, broken rings, lichen patches), the trunk a
   little thicker and darker at the base with a slight swelling. Make the crown **fuller and
   rounder**: 34 to 40 stiff fan leaves on long petioles with toothed edges, so the crown is a
   ball of fans, plus a skirt of 4 to 8 dead brown leaves hanging under it.
4. **`EV_RainTree_A`, `_B`: the canopy mixes faceted low-poly blobs with leaf cards.** The hard
   blob shells look like rocks in the tree. Replace them with **layered leaf-card clusters only**,
   so the canopy is one wide, soft, flat-topped dome, darker underneath and lighter on top, with
   a few gaps showing branches. Keep the trunk and branches, they are good.

Re-run the checks and re-shoot the contact sheet and these assets' close-ups.

---

## Ground fixes (`Env_Ground_v2.html`)

The seams pass, but at the game's viewing distance several sets show their repeat. Revise:

1. **No regular patterns anywhere.** Mud repeats one even crack cell size with dots on a grid,
   Rock reads as an orange checker, and Concrete and Sand show the same blotches every tile.
   Use **two or three noise scales** (large patches, medium clumps, fine grain), vary the crack
   cell size, and scatter details (pebbles, straw bits, stains) **randomly, never on a grid**.
2. **Horizontal banding lines** show at grazing angles on Mud, Sand and Concrete. Remove them
   (they come from the normal map or the height steps), and keep the normal maps **subtle**.
3. **`Rock`**: weathered grey-brown granite with patches of red laterite, cracks and a little
   lichen. No orange tile look.
4. **`Mud`**: drained paddy mud. Cracks of mixed sizes, darker damp patches, rice stubble bits
   and straw strands lying flat at random, not dots.
5. Add a **second view** that tiles each set over a **128 x 128 stud** patch seen from 40 studs
   high, so the repeat can be judged at the game's distance.

Re-run the checks and re-shoot the contact sheet and each set.

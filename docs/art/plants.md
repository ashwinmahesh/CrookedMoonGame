# Region plants (look lane, branch look-plants, 2026-11-01)

The engine's reference is `addons/dnd_core/docs/reference/art/plants.md` (leaf cards, plant models, what grows where, wind). This
page is what the Crooked Moon does with it. Plants are cosmetic only: the rules grid never sees them.

## What is done now (2D cards and data, no Blender)

**Leaf cards repainted in look P** (`tools/art/plant_cards.py` fits a painting from `tools/art/specs/plant_cards.json`, made on the
local image service, exactly into its cell's drawn box in `art/plants/cards.png`; every model that uses the card changes, and the
models' quads keep their shape). The atlas cannot grow without remapping every model's UVs (a Blender job), so a card changes in place:

| Card | Used by | Now | Grows in |
|---|---|---|---|
| `grass_dry` | grass_dry (the dry grass of every set) | long drooping dry corn-leaf blades in olive and straw gold | everywhere dry: the moors, the village, Foxwillow |
| `sedge` | sedge | a bunch of tall ripe cornstalks with husked ears and tassels | **Foxwillow only** (set `corn`) |
| `fern_brown` | bracken | glowing fungal fans: bracket fungi and ruffled caps in toxic teal and rot magenta, spore dots | **Hartsblight** (set `fungal`) and the Wytchwood |
| `vine_leaves` | vine | a thorny briar tangle: bruise-purple leaves, hooked red thorns, black berries | the Wytchwood (set `wytchwood`); the old vineyard set |
| `oak_leaves` | oak_a, oak_b | gnarled leaves in blood red, bruise purple and black with pale hanging strands | every oak: Wickermoor's, the corn's, the Wytchwood's wytch trees |
| `willow_strand` | willow_a | silver-green and lilac weeping strands | the lake shore and bayou willows (set `willows`), Maidenmist's |

**Sets and the mood map** (`art/plants/flora.json`): `moods` now names the Crooked Moon's own moods (the old Strahd names stay, unused)
and `sets` gains `wickermoor`, `corn`, `willows`, `wytchwood`, `fungal`, `maidenmist`, `moor` and `wreck`:

| Mood | Set | What it grows |
|---|---|---|
| `wickermoor`, `fools_day`, `crooked_estate` | `wickermoor` | oaks (wytch-leaved) among spruces and dead trees, dry grass, thistle and heather, cool violet tint |
| `foxwillow` | `corn` | rows of corn (sedge and dry blades), a few dead trees and oaks, harvest-gold tint |
| `memorys_rest`, `bayou` | `willows` | willows on the shore with reeds and cattails, mint tint |
| `hartsblight` | `fungal` | bracken as fungal fans everywhere, ferns, a teal tint |
| `wytchwood`, `crooked_tree` | `wytchwood` | dark oaks and dead trees, briars and fungal fans underneath, blood-to-violet autumn, dark bark |
| `maidenmist` | `maidenmist` | willows and dead trees among graves, silver tint |
| `moors`, `wickers_vigil` | `moor` | heather, dry grass and thistle, wicker-gold autumn |
| `gl_wreck` | `wreck` | spruce and oak with a teal tint round the wreck |
| `dawns_gate` | `mountain` | the engine's mountain set |
| `nightmare` | `sick` | the engine's twisted oaks |

Bracken (now fungal) and sedge (now corn) were taken out of every other set, so only their own regions grow them.
`tests/unit/test_region_flora.gd` checks the sets, the plants they name, their palette colours and that the cards are painted.

## The Crooked Moon's own plant models (`blender/plants_crooked_moon.py`, branch look-plants-v2)

Built in Blender on its hourly turns (`~/.crooked-moon/blender_queue/`, the scheduler's `tools/gpu/blender_batch.sh`), each a `.glb` with a
`_far` copy where it is a tree, listed in `art/plants/manifest.json` and named in a set. `python3 tools/art/plants_dry_run.py` builds
them outside Blender first (a stand-in mesh: it catches a bad grid and counts triangles). All stay under 5000 triangles.

| Model | What it is | Planted by |
|---|---|---|
| `corn_a`, `corn_b`, `corn_c` | a clump of three to five corn plants: jointed stalks, ten long arching leaves each, ears in husks, tassels | Foxwillow (set `corn`) |
| `wytch_a`, `wytch_b` (+ far) | a hunched oak with a heavy crown and long thin hag-hair strands | the Wytchwood |
| `fungal_a`, `fungal_b` | a rotting stump: root flare, fluted bark, jagged broken top, tiers of shelf fungi | Hartsblight (set `fungal`) |
| `briar_a` | long curving thorny canes with branchlets and bramble sprigs | the Wytchwood, the Crooked House's grounds |
| `cypress_a` (+ far) | a buttressed, fluted bald cypress with knees, feathery fronds and long Spanish moss | Murkwater Bend, the bayou (set `willows`) |

**A second leaf atlas.** The first atlas (`cards.png`, six rows) cannot grow without remapping every older model's UVs, so these plants'
cards live in `art/plants/cards2.png` (2048 x 1536, boxes in `cards2.json`, a model's `leaf2` material; engine `Flora.CARDS2_PATH`). The
cards are photoreal cut-outs on white (`tools/art/specs/photoreal/plant_cards3.json` through `tools/art/photoreal.py`, named by
`tools/art/photoreal_fetch.py`) fitted by `tools/art/plant_cards2.py`, which draws a plain stand-in for a card whose picture has not come
yet: corn blades (2), ear, tassel; moss and hair strands; cypress fronds (2); a bramble sprig; shelf fungus top and side. The wytch crowns
still use the first atlas's `oak_leaves`. Bark is the engine's procedural bark in each set's colours (`flora.json` `bark`).

Still not built: the pumpkin and gourd patch (jack-o'-lanterns and pumpkins exist as props), a stalked glowing mushroom, textured
(scanned) bark.

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

## Waiting on Ashwin's "the Mac is idle" word (Blender, `blender/plants_3d.py` is not copied yet; no Blender was run)

New models the cards cannot stand in for. Each would be a `.glb` (with a `_far` copy) listed in `art/plants/manifest.json` and then
named in a set:

- **Corn stalk**: a proper tall stalk with leaves in tiers and an ear (the corn is now crossed cards of sedge and dry blades), 3 variants.
- **Pumpkin and gourd patch**: vines on the ground with 2 to 3 pumpkins, some carved and glowing (open ground in Wickermoor, Foxwillow, the festival).
- **Wytch tree**: a stout oak with a face in the bark and drooping hag-hair strands (for `oak_a` and `oak_b` replacements in `wytchwood`).
- **Fungal growth**: giant bracket fungi up a trunk, a stalked mushroom with a glowing cap, a spore-puff patch (Hartsblight).
- **Briar hedge**: a thick arching bramble with thorns (the Wytchwood, the Crooked House's grounds).
- **Bayou cypress with moss**: a buttressed trunk with hanging moss (Murkwater Bend).
- **More leaf cards** (a Blender UV remap): the atlas to seven rows or a second atlas, so corn, pumpkin vine, fungal cap and briar get cards of their own instead of sharing the old plants'.

# The Crooked Moon's look: what is built, where it lives (look lane, 2026-11-01; plan section 8)

Look P ("Creature Feature Cel": Z-Image Turbo with the Giallo LoRA at 0.6 and `art/prompts/style_preamble.txt`) is drawn through the
local image service by `tools/art/generate_local.py`. This page lists the look's hooks so a map or a lane can use them.

## Set pieces (CrookedMoonLook, `world/look/crooked_moon_look.gd`)

A catalog entry in `art/sprites/props/catalog.json` `ids` names a prop by its id and may carry a `set_piece`; `place_special` builds it.
The entry's `art` stays the picture that stands in wherever the piece cannot be built, so it is always drawn. Never a plain box.

| `set_piece` | Prop ids keyed so far | What it makes |
|---|---|---|
| `oak` | `wm_oak` (the village), `wm_oak_roots_call` is an invisible spot | The Oak of Many Faces (`OakOfManyFaces`): the engine's bare dead tree grown 50 ft and stout, twelve face decals pressed into its bark (`art/props/oak_faces/face_0..7.png`), a cold light that breathes |
| `crooked_tree` | `ct_tree` | The Wytchwood's Crooked Tree (`CrookedTree`): the same tree grown stout and leaning, a carved grin glowing in the bark (`art/props/crooked_tree/tree_grin.png`), an ember light |
| `barrow_glow` | `ct_barrow_mouth` | The barrow's own picture plus a green-gold light |
| `wicker_man` | `wv_su_effigy`, `wv_st_effigy` | The painted Wicker Man (`art/sprites/props/wicker_man.png`, 9 units tall, a back view too) plus the lantern in his chest |

A set piece claims, moves and blocks nothing (`tests/unit/test_set_pieces.gd`). Lights go through `SetPieceLight` (no shadows, so a
place's lamp-shadow budget never pays for them). The R23 and R24 maps (`ct_*`, `wv_*`) are on the local branch `act4-finale-merge`:
the keys above are by prop id, so they take effect when those maps land. Their lights say `"color": "fire"`, which is not a palette
name (an assertion on entering the map): change it to `flame` (done for `nm_oven` and `nm_attic`).

## The Ghostlight Express's windows (`ExpressWindows`)

Every car map has `map.window_view` (`colours`, `streams`, `speed`, `strength`, `rise`: the engine's `WindowView`, schema in the
engine's `location.schema.json`). `CrookedMoonLook.dress_place` hangs a deco window (`art/props/express/train_window.png`, with
`train_window_glass.png` as the glass mask named `Decal_glass`) on each car's far wall every third square, and `WindowView.dress_with`
lays three banks of Shroud smoke streaming past over the panes. A car map without the key keeps the painting's own still smoke.

## The moon (engine `PaintedFinish`, `data/campaign.json` `painted`)

`moon_face` is a picture, or a list of `{when, face, size}`; the first entry whose condition holds is drawn, swapped within half a
second. See `docs/tasks/G8-moon-stages.md` for the flags (`flag.moon_grin`, `flag.moon_scowl`: set by G1, not built).

## The title, icon, travel map

`art/ui/title_backdrop.png` (1376 x 768; the grinning moon is composited by `tools/art/title_moon.py`), `art/ui/app_icon.png`,
`art/ui/map/wickermoor_hollow.png` (2528 x 1696: the layout sketch from `tools/art/travel_sketch.py`, painted over, graded to
moonlight by `look_finish.py map --night`; each place's `pos` in `data/travel/wickermoor_hollow.json` was nudged to its painted
landmark, and the content builders hold the same numbers).

## Towns' ground and walls

This repo has no `art/textures/village`, so `art/textures/manifest.json` gives the `village`, `dungeon` and `cave` board themes their
floors, walls and roofs from the engine's own textures (a board theme with no floor draws the grid's checker). Replace them with
Crooked Moon's own tiles when they are painted; a region's mood still swaps and tints the ground (`moods.json` `ground_swap`,
`ground_tint`).

## Vistas

`tools/art/build_vistas.py --generate --places` paints the landmarks in `tools/art/vista_recipes.json` (white ground), cuts them into
`art/vistas/<id>.png` and fills `art/vistas/vistas.json` (`places` for every location from the travel map, `landmarks`). The engine
shows vistas only when the camera tilts to the horizon past full zoom.

## Tools (all PIL-only or stdlib; macOS `/usr/bin/python3`)

`generate_local.py` (queue client; jobs run `generate_immediately`, ahead of the backlog), `look_finish.py` (title, icon, moon, map
`--night`, window), `oak_faces.py`, `title_moon.py`, `travel_sketch.py`, `build_vistas.py`; the specs are in `tools/art/specs/`.
`make capture SCENE=res://tools/capture/places_capture.tscn NAME=... ARGS='--places=a,b [--travel] [--sky] [--focus=x,z[,d]] [--later]'`
takes the play and whole-place shots at the Midnight Hour, the travel map with every place known, a clear sky with the moon ahead, a
close shot of a square, and the same view a moment later.

---
title: G8 The Crooked Moon's face by the ritual track (look lane, hook built; G1 sets the flags)
status: open
---

The sky's moon is the game's own picture (`painted.moon_face` in `data/campaign.json`, engine `PaintedFinish`). The picture is chosen
by the story: `moon_face` may be a list of `{"when": "<story condition>", "face": "res://...", "size": <radius>}`, the first entry whose
condition holds wins (an entry with no `when` always does), and a change shows within half a second, even while a place is open
(`PaintedFinish.follow_moon_face`). A plain path still means that one picture, so Curse of Strahd is unchanged. Engine branch
`moon-face-stages` (not on main yet): `world/look/painted_finish.gd`, test `tests/unit/test_painted_finish.gd`.

## What the look lane built

- Pictures (art/sky, look P on Z-Image with the Giallo LoRA, the full moon as a disc on alpha, its edge the square's edge):
  `moon_smirk.png` (narrow smirk: the start), `moon_grin2.png` (a wide grin), `moon_grin3.png` (the grin from edge to edge), and
  `moon_scowl.png` (the scowl after the ritual). Made by `tools/art/generate_local.py` from `tools/art/specs/moon.json` and
  `moon_stages.json`, fitted by `tools/art/look_finish.py moon`.
- Wired in `data/campaign.json` `painted.moon_face` once the pictures exist (a missing picture keeps the plain disc), keyed on:

| Flag | Meaning | Set by |
|---|---|---|
| `flag.moon_scowl` | the ritual has been undone: the moon scowls (wins over any grin) | **G1, not built** |
| `flag.moon_grin >= 2` | the seals have widened the grin to its most (the grin from edge to edge) | **G1, not built** |
| `flag.moon_grin >= 1` | a first seal: a wide grin | **G1, not built** |
| none of them | the narrow smirk | |

`moon_grin` is an integer flag counting the ritual track's steps (`StoryState.set_flag("moon_grin", n)`); the names are this lane's guess
at what G1 will want. **G1 (the ritual track and the Crooked Moon's gaze, plan section 6) renames or remaps the keys in
`data/campaign.json`; the engine needs no change.** Until then no flag is set and the sky shows the smirk.

## Left

- G1 sets the flags as the track moves; if it prefers a different counter, change the `when` strings only.
- The moon's face in the water and the title picture use the smirk; only the sky follows the story.

# Painted faces for the figures that have no head (look lane, branch `look-figure-faces`)

The Act 1 figures with no model of their own (the 47 crowd, child and background people on the hero bodies, and the nine
finished Tripo bodies made without a head) used to show a blank clay head. They now wear a **head painted in look P**: a rigid
head part the engine fits to the body's neck (`"fit": "head"`, the same hook the clay head used), with the body's own head shrunk
away (`"bones": {"Head": 0.01}`). Nothing in the engine changed.

## How a face is made

1. A **head sheet**: one head drawn three times on white (front, side, back, left to right).
   - The nine characters' own head sheets (`<asset root>/turnarounds/tpose/<id>-head-sheet.png`, made earlier from their character
     sheets) are used as they are: `face_doris_squire`, `face_wendel_somerton`, `face_mori_shade`, `face_weston_murdoch`,
     `face_mrs_oakum`, `face_theodora_mayville`, `face_dani_jenkin`, `face_gilly_jenkin`, `face_crooked_man`.
   - The 26 **generic** sheets (`face_m1`..`face_m9` men, `face_f1`..`face_f8` women, `face_c1`..`face_c9` children, in
     `<asset root>/faces/`) come from `tools/art/face_sheets.py`: the image service's Qwen edit redraws Weston's, Gilly's or Dani's
     head sheet for a new person (`tools/art/specs/face_sheets.json` says who: age, hair, beard, freckles), so the white ground,
     the three views and the art style carry over. No credits.
2. `tools/art/face_heads.py` cuts the front and back views, blanks the sheet's white either side of the head, and paints them onto
   the clay head's shape (an egg with a nose and two ears, `tools/art/clay_head.py`): the front view onto the front half, the back
   view onto the back half, one atlas, one embedded JPEG. The heads are `art/figures/heads/face_*.glb` (about 150 KB each, LFS).
   `tools/art/face_heads.json` gives each sheet and where its chin is.
3. `art/figures/manifest.json` has each face as a part, and each figure names its face in `layers`. Who wears which face is
   **data in that file** (one line each): change the `face_xx` in `layers` to change a face.

The body's colour is a flat picture (`art/figures/clay/<colour>.png`, the hero clay times the colour the figure had as a tint)
instead of a tint, because a tint multiplies everything the figure draws, the painted face included.

## Who wears which face

The assignment was made from each person's summary in `data/npcs/` (age, build, beard). Faces repeat across the crowds; children
share four boys' and five girls' faces, adults nine men's and eight women's. `tests/unit/test_act1_figures.gd` checks that every
reused person has a face of the right sort (boy, girl, man, woman) and that children have children's faces.

| Face | Wears it |
|---|---|
| c1 | pip_oakum, lark_wells |
| c2 | margery_heyling, violet_aster |
| c3 | charlotte_murdoch, sheridan_heyling |
| c4 | peter_murdoch, jay_wells |
| c5 | algernon_heyling, ulf_harga |
| c6 | eddie_wainwright, zachariah_wainwright |
| c7 | lavender_aster, wren_wells |
| c8 | robin_wells, sofia_roderick |
| c9 | rose_somerton, victoria_wainwright |
| m1 | howie_butterman, pim_fenwick |
| m2 | amos_dority, brother_spore, rk_mob_b |
| m3 | brother_elias |
| m4 | haldor_vane |
| m5 | gaston_doray, tobias_dibbs |
| m6 | george_hickock |
| m7 | sgt_gaunt, rk_posse_b |
| m8 | branden_wells, rk_mob_round, wynn_carter |
| m9 | cecil_marl, ronald_wainwright |
| f1 | lilian_vale, rk_mob_a |
| f2 | hester_bolton, myrtle_somerton, wilma_wainwright |
| f3 | olwen_pike |
| f4 | granny_orla_pike |
| f5 | bess_crumley, rk_mob_c |
| f6 | rk_posse_a |
| f7 | marta_dunn |
| f8 | ottilie_reed |

The two ghosts on the haint body (Petunia, Arthur) keep their tinted ghost heads.

Five people changed body to fit who they are (the earlier pass guessed from names): George Hickock, Brother Spore, Cecil Marl and
Haldor Vane are men and Hester Bolton and Myrtle Somerton are women. Zachariah and Victoria Wainwright are a boy and a girl.

## Reverting to the 2D walker

Point an NPC's `sprite` in `data/npcs/<id>.json` back at `"villager"` (the manifest entry is then unused). Nothing else depends on
the faces.

## Not done / next

- A face is a painted egg: the sheet's hat or hair outline is painted on the head, so a brim does not stick out. A real head model
  (Tripo, from the same sheet, about 95 credits each) would replace `face_<id>` for the nine characters one by one: add the head as
  a part the same way and name it in the figure's `layers`.
- The generic faces are the same two art-style references redrawn; a character whose face matters (a quest giver) should get a
  head of their own.

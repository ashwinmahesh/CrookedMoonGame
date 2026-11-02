# The pack people (branch `pack-rig`)

Ashwin's Quaternius packs are the base for the game's people (his rule, 2026-11-02): the **Universal Base Characters**, the
**Modular Character Outfits - Fantasy** and the **Universal Animation Library** (all three Source editions, CC0). This note is
how they became figures the engine draws, and what is still open.

## One skeleton, so no retargeting

The bodies, the outfits, the hairstyles and the animation library are all on the same 65-joint skeleton (root, pelvis,
spine_01..03, neck_01, Head, clavicle_l, upperarm_l ... ball_r). I compared the joint names and rest poses of
`UAL1.glb` and the Regular bodies: the 65 names are identical and the rest poses match (the female's toe-ball differs by a few
degrees). So the clips play on the bodies **as they are**: no retarget, no bone map to bake through, and no copy of the
characters pack's `DefaultBoneMap.tres` (a map to Godot's humanoid profile, which is for retargeting a *different* skeleton).
I did not retarget the game's Tripo clips (Mixamo rig) onto this rig: the pack's own clips are made for it, so there is no
rest-pose mismatch to correct, and the pack has 120 of them against the Tripo set's ten.

The clips are baked into the body files, once, by `tools/art/pack_figures.py` (30 clips, about 7 MB of the 9.5 MB body file).
`pack_male.glb` and `pack_female.glb` are the Regular FullBody skeleton and mesh (the mesh has no picture: a head and an outfit
are laid over it and hide it, `hides: ["*"]`, but it still gives the figure its height) with the clips.

## What a pack figure is

```
pack_man_peasant   base pack_male   layers: pack_male_head, pack_male_peasant, pack_male_hair_parted
pack_woman_peasant base pack_female layers: pack_female_head, pack_female_peasant, pack_female_hair_buns
```

Each layer is a skinned part that joins the body's skeleton by bone name (the engine's layers). The head is the pack's OnlyHead
(head, eyes, eyebrows), the outfit is the pack's Peasant (arms, body, legs, feet, with the light skin on the hands), the hair
one of its hairstyles rigged to the head bone, tinted a brown in the bake (the pack's hair picture is nearly white and the pack's
engine materials colour it). Skin is the light one. To change a person, change the names in `layers`. The other two Peasant
colourings are `pack_figures.py outfits`; the other outfits (Noble, Knight, Ranger, Wizard), hairstyles and bodies (Teen,
Superhero, the dark skins) are in the packs on the asset root and are added the same way.

## The rig (manifest `rigs.quaternius`, engine branch `pack-rig`)

The engine looked bones up by Mixamo names (`Neck`, `HeadTop_End`, `RightHand`). The manifest's `rigs.quaternius` says what this
skeleton calls them (`neck_01`, `hand_r`...), that it has no head-top bone (so `head_top` says where the top of the head is,
`[0, 0.12, 0]` in figure heights above the Head bone), and which pack clip plays which role. Figures name their rig with
`"rig": "quaternius"`; a figure with no rig is found by the engine's own names exactly as before (Curse of Strahd, the Tripo
figures). The head made apart (`fit: head`), a held weapon and the entry's `bones` scales all go through the rig.

## Clips by role

| Role | Clip (pack name) | Note |
|---|---|---|
| idle, walk, run | Idle, Walk, Jog_Fwd | Godot's importer reads the pack's `_Loop` suffix: a looping clip with the suffix stripped |
| attack | Sword_Attack | window `from 0 to 1.45, hit 0.45, speed 1.25` (from the pilot; the capture catches the lunge at the hit) |
| cast | Spell_Simple_Shoot | |
| hurt, die | Hit_Chest, Death01 | Hit_Head, Hit_Stomach and Death02 are in the file |
| talk (in turn) | Idle_Talking, Yes, Idle_No | |
| greet (in turn) | Interact, Yes | |
| agree, complain, defeat | Yes, Idle_No, Death02 | data the engine does not read yet (no such roles); in `rigs.quaternius.clips` for when it does |
| sit | Sitting_Enter, Sitting_Idle, Sitting_Exit | data for a game that seats people |

**What the pack lacks** (the library has 120 clips, but none of these): *agree*, *complain*, *wave*/*greet* and *bow*. The two
the game needs for dialogue come from the free Universal Animation Library 2 (`Yes` for agree and a nod, `Idle_No_Loop` for a head
shake); greeting is `Interact`, which reads as a gesture with the hands, not a wave. A **bow** and a **wave** are missing. To fill
them I would bake two clips by editing keys on this skeleton: a bow is the spine_01..03 and neck_01 pitching forward 25 to 35
degrees and back over about 1.6 seconds on top of Idle (a few keys in a script), and a wave is the upperarm_r and lowerarm_r
raised with the hand_r oscillating on top of Idle. Neither needs a retarget.

## Not done

- A sword is held in `hand_r` through the rig, but `Sword_Attack` is a swing for a one-handed blade with the hand empty here; held
  weapons on a pack figure need the parts' offsets tuned per hand (the pilot's villager has them).
- The body files carry the clips twice (male and female): 19 MB. A shared clip library the engine merges in (`clips_from`) would
  halve it.
- The NPCs still wear their old figures; moving the 47 reuse villagers onto these is the figures and world-rebuild lanes' work.

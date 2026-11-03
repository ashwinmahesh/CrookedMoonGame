# Monster models still to make (2026-11-03)

Ashwin (2026-11-03): *Generate 3D models for complex or unique monsters. If they are basic, we can find a free model online.* This sorts the 88 spawned monsters that have no 3D model yet (`make figure-audit`, the 'sprite' and 'none' tiers) by where their stat block comes from: the Crooked Moon's own creatures are the unique ones to generate, the Monster Manual creatures are basic ones to source free, and the Monster Manual humanoids wear the animation pack's people.

| Route | Monsters |
|---|---|
| Generate (Tripo) | 48 |
| Free model | 32 |
| Pack figure (dressed) | 8 |

## Free packs to take from (CC0, none downloaded yet; the project rule is a typed yes from Ashwin for each download, kept untouched with its licence in art/sourced/ and credited)

- [Quaternius: Ultimate Monsters Pack](https://quaternius.com/) (50 animated monsters with attack, death and walk clips; glTF; CC0): the first choice for most of the Free list.
- [Quaternius: LowPoly Animated Monsters](https://quaternius.itch.io/lowpoly-animated-monsters) and [Animated Easy Enemies](https://quaternius.itch.io/animated-easy-enemies) (CC0; FBX, OBJ and Blend, so a Blender conversion to glTF).
- [Quaternius animals](https://opengameart.org/content/animated-animales-low-poly) (CC0; wolf and others), for the dogs, bears, rats and birds.
- KayKit skeletons, already in `art/sourced/`, for the skeletons.

A pack has to be opened to see which of its creatures match; I have not downloaded anything. Each match is rigged onto the figure pipeline (`tools/art/figures.py`), given a height and a facing turn, and checked by `make validate`.

## The list

| Route | Monster | CR | Size | Type | Book | Drawn now as | Seen in |
|---|---|---|---|---|---|---|---|

| Generate (Tripo) | The Vermintoll Abomination (`vermintoll_abomination_dream`) | 14 | large | fey | CM2024 | an old 2D sprite | crooked_house, rk_dovecote_r1, nm_attic |
| Generate (Tripo) | The Lord of Fools (`lord_of_fools`) | 13 | huge | fiend | CM2024 | nothing (plain placeholder) | fd_ring_of_fools |
| Generate (Tripo) | Pigeon Hag (`pigeon_hag`) | 13 | medium | fey | CM2024 | an old 2D sprite | crooked_house, rk_dovecote_r1, nm_attic |
| Generate (Tripo) | Yorgrim, the Chained Reaper (`chained_reaper_harrowing`) | 11 | gargantuan | undead | CM2024 | nothing (plain placeholder) | mm_tomb |
| Generate (Tripo) | Festerhulk (`festerhulk`) | 11 | huge | undead | CM2024 | an old 2D sprite | rk_roost_swamp, rk_roost_prairie, rk_roost_lakeshore |
| Generate (Tripo) | Invader Out of Space (`invader_out_of_space`) | 11 | medium | aberration | CM2024 | nothing (plain placeholder) | nm_crater |
| Generate (Tripo) | Wisp, the dream cat (`wisp_nightmare`) | 11 | gargantuan | fey | CM2024 | an old 2D sprite | rk_roost_foothills, nm_bookshelf |
| Generate (Tripo) | The Beast of Blight (`beast_of_blight`) | 10 | gargantuan | fey | CM2024 | an old 2D sprite | mm_burial_mounds, hb_den, hb_fungal_grove |
| Generate (Tripo) | Dream Eater (`dream_eater`) | 10 | large | monstrosity | CM2024 | an old 2D sprite | rk_roost_foothills, crooked_house, mm_mausoleum_lanes |
| Generate (Tripo) | Gloomwood (`gloomwood`) | 10 | huge | plant | CM2024 | an old 2D sprite | mm_burial_mounds, hb_den, hb_fungal_grove |
| Generate (Tripo) | Herald of Fools (`herald_of_fools`) | 10 | medium | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Necrolisk (`necrolisk`) | 10 | huge | dragon | CM2024 | nothing (plain placeholder) | mm_necropolis_depths |
| Generate (Tripo) | Drakkenhob (`drakkenhob`) | 9 | large | dragon | CM2024 | nothing (plain placeholder) | nm_wedding |
| Generate (Tripo) | The Grinning Sinner (`grinning_sinner_boss`) | 9 | large | humanoid | CM2024 | nothing (plain placeholder) | dc_casino |
| Generate (Tripo) | Phantom Hearse (`phantom_hearse`) | 9 | huge | undead | CM2024 | nothing (plain placeholder) | mm_cremation_gardens |
| Generate (Tripo) | Reveler of Stories (Great Beast) (`reveler_of_stories_great_beast`) | 9 | large | fiend | CM2024 | nothing (plain placeholder) | fd_festival, fd_ring_of_fools |
| Generate (Tripo) | Reveler of Stories (Hero) (`reveler_of_stories_hero`) | 9 | large | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Reveler of Stories (Witch) (`reveler_of_stories_witch`) | 9 | large | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Gobblegeist (`gobblegeist`) | 8 | huge | monstrosity | CM2024 | an old 2D sprite | nm_dark_wood |
| Generate (Tripo) | Kackle (`kackle`) | 7 | medium | undead | CM2024 | an old 2D sprite | mm_gravestones_b, mm_potters_field |
| Generate (Tripo) | Alpengrendel (`alpengrendel`) | 6 | large | giant | CM2024 | nothing (plain placeholder) | mon_pass |
| Generate (Tripo) | Fleshdobbin (`fleshdobbin`) | 6 | large | monstrosity | CM2024 | an old 2D sprite | sk_upper, mm_gravestones_a, sk_hills_trail |
| Generate (Tripo) | The Harvest Terror (`harvest_terror`) | 6 | large | fiend | CM2024 | an old 2D sprite | fw_maze_dead1, fw_maze_dead2, foxwillow |
| Generate (Tripo) | Keeper of the Blight (`keeper_of_the_blight`) | 6 | large | fey | CM2024 | an old 2D sprite | hb_druid_commune, hb_patient_commune |
| Generate (Tripo) | Reveler of Song (Bell) (`reveler_of_song_bell`) | 6 | medium | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Reveler of Song (Drone) (`reveler_of_song_drone`) | 6 | medium | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Reveler of Song (Drum) (`reveler_of_song_drum`) | 6 | medium | fiend | CM2024 | nothing (plain placeholder) | fd_festival |
| Generate (Tripo) | Wormhost Surgeon (`wormhost_surgeon`) | 5 | medium | aberration | CM2024 | an old 2D sprite | mr_ground, dc_boat_promenade, mm_gravestones_b |
| Generate (Tripo) | Corrupted Soulfire Stoker (`corrupted_soulfire_stoker`) | 4 | medium | elemental | CM2024 | nothing (plain placeholder) | ghostlight_g8_tender |
| Generate (Tripo) | Adelaide, Raum's puppet (`corvodaemon_adelaide`) | 4 | medium | fiend | CM2024 | an old 2D sprite | fw_circle, fw_maze_j1, fw_maze_j2 |
| Generate (Tripo) | Corvodaemon (split from Raum) (`corvodaemon_split`) | 4 | medium | fiend | CM2024 | an old 2D sprite | fw_circle, fw_maze_j1, fw_maze_j2 |
| Generate (Tripo) | Ketgrinn (`ketgrinn`) | 4 | medium | fey | CM2024 | nothing (plain placeholder) | crooked_house |
| Generate (Tripo) | Lurker in the Dark (`lurker_in_the_dark`) | 4 | medium | fey | CM2024 | nothing (plain placeholder) | crooked_house |
| Generate (Tripo) | Shrouded (Devourer) (`shrouded_devourer`) | 4 | medium | undead | CM2024 | an old 2D sprite | mm_balefire_chamber, mm_corpse_road, mm_gravestones_b |
| Generate (Tripo) | Shrouded (Reaper) (`shrouded_reaper`) | 4 | medium | undead | CM2024 | an old 2D sprite | mm_balefire_chamber, mm_corpse_road, mm_gravestones_b |
| Generate (Tripo) | Weasel Hag (`weasel_hag`) | 4 | medium | fey | CM2024 | an old 2D sprite | crooked_house, rk_dovecote_r1, nm_attic |
| Generate (Tripo) | Crowstorm (`crowstorm`) | 3 | large | fiend | CM2024 | an old 2D sprite | fw_maze_dead3, rk_dovecote_r1, wickermoor_village |
| Generate (Tripo) | Marble Peacock (`marble_peacock`) | 3 | medium | construct | CM2024 | an old 2D sprite | rk_roost_foothills, crooked_house, mm_mausoleum_lanes |
| Generate (Tripo) | Petunia Lockwood (`petunia_lockwood`) | 3 | medium | undead | CM2024 | an old 2D sprite | crooked_house, mm_gravestones_b |
| Generate (Tripo) | Pumpkin Head (`pumpkin_head`) | 3 | medium | fiend | CM2024 | an old 2D sprite | fw_maze_dead1, fw_maze_dead2, foxwillow |
| Generate (Tripo) | Vermin Infestation (`vermin_infestation`) | 3 | medium | fey | CM2024 | an old 2D sprite | mr_ground, crooked_house, nm_attic |
| Generate (Tripo) | Boogleswarm (`boogleswarm`) | 2 | large | fey | CM2024 | an old 2D sprite | mr_ground, crooked_house, nm_attic |
| Generate (Tripo) | Dancing Herald (`dancing_herald`) | 2 | medium | fiend | CM2024 | nothing (plain placeholder) | fd_ring_of_fools |
| Generate (Tripo) | Vermin Familiar (Pigeon) (`vermin_familiar_pigeon`) | 2 | tiny | fey | CM2024 | an old 2D sprite | crooked_house, rk_dovecote_r1, wickermoor_village |
| Generate (Tripo) | Vermin Familiar (Weasel) (`vermin_familiar_weasel`) | 2 | tiny | fey | CM2024 | an old 2D sprite | crooked_house |
| Generate (Tripo) | Quasit (Antlered Bunny) (`quasit_bunny`) | 1 | tiny | fiend | CM2024 | an old 2D sprite | sk_upper, crooked_house |
| Generate (Tripo) | Rotweaver (`rotweaver`) | 1 | medium | fey | CM2024 | nothing (plain placeholder) | hb_altar_of_rot, hb_den, hb_druid_commune |
| Generate (Tripo) | Squabswarm (`squabswarm`) | 0.5 | medium | fey | CM2024 | an old 2D sprite | fw_maze_dead3, rk_dovecote_r1, wickermoor_village |
| Free model | Treant (`treant`) | 9 | huge | plant | MM2025 | an old 2D sprite | mm_burial_mounds, hb_den, hb_fungal_grove |
| Free model | Oni (`oni`) | 7 | large | fiend | MM2025 | an old 2D sprite | rk_roost_swamp, rk_roost_prairie, rk_roost_lakeshore |
| Free model | Chimera (`chimera`) | 6 | large | monstrosity | MM2025 | an old 2D sprite | mr_ground, dc_boat_promenade, mm_gravestones_b |
| Free model | Mammoth (`mammoth`) | 6 | huge | beast | MM2025 | an old 2D sprite | hb_altar_of_rot, hb_druid_commune, hb_noxious_hollow |
| Free model | Wyvern (`wyvern`) | 6 | large | dragon | MM2025 | an old 2D sprite | rk_roost_foothills, nm_bookshelf |
| Free model | Giant Crocodile (`giant_crocodile`) | 5 | huge | beast | MM2025 | an old 2D sprite | rk_roost_swamp, dc_trail2 |
| Free model | Mutated patient (`mutated_patient`) | 5 | medium | aberration | MM2025 | nothing (plain placeholder) | mr_ground |
| Free model | Soulfire Engineer (`soulfire_engineer`) | 5 | medium | undead | MM2025 | nothing (plain placeholder) | dc_boat_promenade |
| Free model | Troll (`troll`) | 5 | large | giant | MM2025 | an old 2D sprite | rk_roost_swamp, rk_roost_prairie, rk_roost_lakeshore |
| Free model | Chuul (`chuul`) | 4 | large | aberration | MM2025 | an old 2D sprite | sk_camp, sk_upper, rk_roost_lakeshore |
| Free model | Ettin (`ettin`) | 4 | large | giant | MM2025 | an old 2D sprite | rk_roost_swamp, rk_roost_prairie, rk_roost_lakeshore |
| Free model | Owlbear (`owlbear`) | 3 | large | monstrosity | MM2025 | an old 2D sprite | hb_altar_of_rot, hb_druid_commune, hb_noxious_hollow |
| Free model | Ankheg (`ankheg`) | 2 | large | monstrosity | MM2025 | an old 2D sprite | sk_camp, sk_upper, rk_roost_lakeshore |
| Free model | Gibbering Mouther (`gibbering_mouther`) | 2 | medium | aberration | MM2025 | an old 2D sprite | mr_ground, crooked_house, hb_oozing_ravine |
| Free model | Minotaur Skeleton (`minotaur_skeleton`) | 2 | large | undead | MM2025 | an old 2D sprite | mm_gravestones_a, mm_gravestones_b |
| Free model | Ochre Jelly (`ochre_jelly`) | 2 | large | ooze | MM2025 | an old 2D sprite | mr_ground, crooked_house, hb_oozing_ravine |
| Free model | Ogre Zombie (`ogre_zombie`) | 2 | large | undead | MM2025 | an old 2D sprite | mr_ground, dc_boat_promenade, mm_gravestones_b |
| Free model | Swarm of Venomous Snakes (`swarm_of_venomous_snakes`) | 2 | medium | beast | MM2025 | an old 2D sprite | mr_ground, crooked_house, nm_attic |
| Free model | Vermin Familiar (Centipede) (`vermin_familiar_centipede`) | 2 | tiny | fey | CM2024 | an old 2D sprite | sk_upper, crooked_house |
| Free model | Death Dog (`death_dog`) | 1 | medium | monstrosity | MM2025 | an old 2D sprite | hb_pine_barrens |
| Free model | Giant Vulture (`giant_vulture`) | 1 | large | monstrosity | MM2025 | an old 2D sprite | rk_roost_foothills, crooked_house, mm_mausoleum_lanes |
| Free model | Quasit (`quasit`) | 1 | tiny | fiend | MM2025 | an old 2D sprite | wickermoor_orchard |
| Free model | Quasit (Round Crow) (`quasit_crow`) | 1 | tiny | fiend | CM2024 | an old 2D sprite | crooked_house, rk_dovecote_r1, wickermoor_village |
| Free model | Quasit (Stuffed Goat) (`quasit_goat`) | 1 | tiny | fiend | CM2024 | an old 2D sprite | crooked_house, wickermoor_village |
| Free model | Crocodile (`crocodile`) | 0.5 | large | beast | MM2025 | an old 2D sprite | rk_roost_swamp, dc_trail2 |
| Free model | Skitterswarm (`skitterswarm`) | 0.5 | medium | fey | CM2024 | an old 2D sprite | sk_upper, rk_dovecote_r1, wickermoor_village |
| Free model | Swarm of Bats (`swarm_of_bats`) | 0.5 | medium | beast | CM2024 | an old 2D sprite | mon_bell_tower |
| Free model | Warhorse Skeleton (`warhorse_skeleton`) | 0.5 | large | undead | MM2025 | an old 2D sprite | sk_upper, mm_gravestones_a, sk_hills_trail |
| Free model | Giant Centipede (`giant_centipede`) | 0.25 | small | beast | MM2025 | an old 2D sprite | sk_camp, sk_upper, rk_roost_lakeshore |
| Free model | Mud Mephit (`mud_mephit`) | 0.25 | small | elemental | MM2025 | an old 2D sprite | mm_mausoleum_lanes |
| Free model | Violet Fungus (`violet_fungus`) | 0.25 | medium | plant | MM2025 | an old 2D sprite | mm_burial_mounds |
| Free model | Stirge (`stirge`) | 0.125 | tiny | monstrosity | MM2025 | an old 2D sprite | dc_shack_approach |
| Pack figure (dressed) | Hunt Knight (`hunt_knight`) | 3 | medium | humanoid | MM2025 | an old 2D sprite | dawns_gate, mon_ground, mon_stables |
| Pack figure (dressed) | Hunt Knight (unarmoured) (`hunt_knight_bare`) | 3 | medium | humanoid | MM2025 | an old 2D sprite | dawns_gate, mon_ground, mon_stables |
| Pack figure (dressed) | Inquisitor Cromwell (`prior_cromwell`) | 3 | medium | humanoid | MM2025 | an old 2D sprite | dawns_gate, mon_ground, mon_stables |
| Pack figure (dressed) | Warrior Veteran (`warrior_veteran`) | 3 | medium | humanoid | MM2025 | an old 2D sprite | mon_ground, mon_pass, wickermoor_village |
| Pack figure (dressed) | Cultist Fanatic (`cultist_fanatic`) | 2 | medium | humanoid | MM2025 | an old 2D sprite | wickermoor_orchard, mon_ground, mon_pass |
| Pack figure (dressed) | Houndmaster Jaeger (`prior_jaeger`) | 2 | medium | humanoid | MM2025 | an old 2D sprite | mon_ground |
| Pack figure (dressed) | Friar Olaf (`prior_olaf`) | 2 | medium | humanoid | MM2025 | an old 2D sprite | mon_ground |
| Pack figure (dressed) | Spy (`spy`) | 1 | medium | humanoid | MM2025 | an old 2D sprite | wickermoor_village |

## How the Generate list is made

The project's way (CLAUDE.md): a turnaround picture of each creature, approved by Ashwin, becomes a rigged Tripo model, which `tools/art/figures.py` copies in at 2K textures. I can make the turnaround pictures on the local image server (paused while Ashwin plays); the Tripo step needs his Tripo account. I have not started either.

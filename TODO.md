# TODO

Ashwin's requests and the merge queue. Each item shows its status. Items in progress link to the thread handling them. Finished items get a done mark and a one-sentence summary.

## In progress

| Item | Status | Thread |
|---|---|---|
| WASD controls the camera while the arrow keys move the character (Ashwin, 2026-11-02) | In progress | [Camera follows the party](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg) |
| The camera gets fully free tilt | In progress | [Camera follows the party](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg) |
| Portraits for the 144 missing NPCs: 148 photoreal portrait jobs are queued at normal priority (the image server is paused) | In progress (queued, waiting on the server) | [Portraits](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoMVcF4yx8zrzvExbupWQsVL) |
| Build out Act 2 and the open todos | In progress | [Act 2](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoPPR4UsoGK7bQTEnN8LobsA) |
| Audit all visual effects: each gets a selection room and its own colour, size and speed settings (melee hit effects are landed; the other effects are next) | In progress | [Melee hit effects](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoHUCbLptUKMrnux7PbW3KTT) |
| Real 3D multi-floor grid, starting with the Crooked House, built in the DnDGameEngine-3D fork; houses rebuilt at the pack's true size | In progress (Ashwin said go) | [Rebuild the worlds](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoC7g6BsCwnrPHakr5kpoBPD) |
| Weapons and pack animations (Rook's switch to pack clips waits on Ashwin's verdict) | In progress | [Weapons/pack animations](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoWHuBM7pdpdhmz86LEs2vUs) |
| Cel cutscene stills (docs-cutscenes-cel 28081e80 queued) | In progress | [Look/title](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCPX3moU1VgdtYuw77oSqT) |

## In progress

| Item | Status | Thread |
|---|---|---|
| Narrator becomes the Strahd voice on Higgs at full quality (VoiceGen PR #19 merged, local VoiceGen server restarted) | In progress | [Voices](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCmcjA1nT898YLNaBWaBba) |
| Re-record all existing lines, starting with Act 1 | In progress | [Voices](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCmcjA1nT898YLNaBWaBba) |

## Open

| Item | Status | Thread |
|---|---|---|
| Engine bug: atmosphere_weather._window_light pushes a SpotLight3D into an OmniLight3D array, which errors when the party arrives at Wickermoor | Open (small, for the engine batch) | [Builder](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo885PDotQZrvX69iv4FXMtz) |
| Narrator graininess | Open | — |
| Camera follow | Open | [Camera follow](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg) |

## Merge queue (landing in batches)

- wild-pilot (877f3a8): rebase needed; its finishes overlap look-full-3d.
- village-kit (0edb978).
- docs-cutscenes-cel (28081e80), which replaces 76aa675.
- Dice sounds (db0c335, LFS WAVs).
- Dialogue portraits (6cace2b, from the bundle on the Mac).
- Voice wire.
- Animation speed 1.5x (game b916cc1 needs engine 0d1e575d first).
- Melee hit effects (game 9cdb0e4 needs engine 99eb0835 first).
- Spellcasting (game 6ff60ce needs engine d51fb938 first).
- pack-rig (93738fa, engine 1dd92ff9), then weapons and pack animations (ea618d40).
- Engine branches waiting on their own pushes: look-full-3d is landed; anim-speed, melee-hit-fx, cast-anim, and engine-land-6 (f6f0fc4f) still need pushing.

## Done

- **Per-floor settings, cellars inside the walls, the monastery's west stair** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoRPZu9NaNNbtWXmE9YAURC7)): each floor of a multi-floor building keeps its own mood, sound bed, footsteps, rest, theme and open air (the Crooked House attic's darker mood is back), the cellars lie under their building's walls, and the monastery's west stair is a real stair. (Engine 1107ab06, game cb23186d.)
- **Festival of Fools night and no edge blur** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCPX3moU1VgdtYuw77oSqT)): the Festival of Fools gets a moonlit night, the engine's depth blur is off in this game (`depth_blur: false`), and the place captures stand up the real 3D party; Foxwillow's moonlit night was already on main. (Engine 770bc149, game aac5bb9f.)
- **Myrtle Somerton and Hester Bolton on the female pack body**: both villagers move onto pack_female. (Game c6a18002.)
- **Multi-floor windmill, inns, cellars and monastery** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoRPZu9NaNNbtWXmE9YAURC7)): the windmill, the Green Queen, the Briar, the barber shop, the funeral home, the trading post, the monastery and the inns are one place each with floors over each other, and saves gain an optional `story.merged_places` so old saves are mended. (Engine b8297659, game 276faba1.)
- **Rest of the free models and the test_figures dressing check** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoQCFNvm6cQtDuSEztHsi468)): 26 more pack parts (Noble outfits, colourings, nine hairstyles), the 47 background villagers moved onto the pack bodies, the warhorse drawn as the pack's horse, and the villager dressing check fixed. (Game 56d629ab to f694fbf2.)
- **Wickermoor lighting and the playable gate**: a lit window's spotlight no longer errors going into the night lights, and the subclasses and the Veil no longer grant spells that have lost their level, so test_playable_gate passes. (Engine 1a51719d, game 04b5b5c7.)
- **Spellcasting animations**: every figure's cast is the animation pack's spell (gathered, held, thrown from the left hand, followed through), with a glow gathering in the casting hand, and the pack bodies rebaked with the Enter and Exit clips. (Engine 768b5b42, game f2acd771, 46a964a7.)
- **Multi-storey camera**: the floor you climb to comes in slightly see-through and holds there, then turns solid. (Engine eceee5a0, game 7c92dce0.)
- **Dialogue portraits for the six haints**: the daydreamer, harlequin, jailbird, mariner, songstress and sweetheart have faces in dialogue, and tools/art/portrait_gaps.py lists the speakers still missing one. (ff11a92b.)
- **Trees cost less frame time**: the EZ trees are about 7 times lighter, which cuts the 40% frame-time cost at the wreckage. (595c0686.)
- **The Crooked Moon's own plants**: 12 Blender-built plant models (corn, wytch trees, fungal stumps, briar, mossy cypress) placed by region in flora.json, with 6 leaf cards repainted photoreal. (6e38d1cd, b8663ef6.)
- **The title's moon is a thin sickle**: the title picture shows a thin sickle with sharp horns. (63b95c1d.)
- **GPU scheduler shares the GPU with headless Blender**: the Blender-aware scheduler scripts are now in tools/gpu. (d147926b.)
- **Moonlit nights and gnarled set-piece trees**: a realistic moonlit night for the wild regions, gnarled EZ-Tree set pieces with 240 dead_tree props routed to them, and cheaper ground clutter. (4778fdec, 72a7f738.)
- **Terrain3D speed fixes on the walk maps**: no shadows under the walk maps, and the land past a map's edge is light enough to draw. (547e7f0c, 5c48a7d7.)
- **Whole travel map as 3D land, with gamepad controls**: the 3D overworld holds the whole travel map, places that share a spot are told apart, and the 12 MB bake is refreshed for the realistic trees. (1e6a518b, 26cad78a, aec3d548.)
- **Engine forked into DnDGameEngine-3D**: the Crooked Moon engine is its own repo, the submodule URL is switched, and all lanes and your local copy use it. (Game f354a706; engine main b19bc8ea.)
- **Animation speed 1.5x**: every figure animates 1.5x faster, set in data/campaign.json. (Engine 1ddc44cd, game b4ee3def.)
- **Weapons and the other six heroes on the pack clips**: fitted hand sockets and re-angled dagger, spear, staff and greataxe. (09937420.)
- **Village kit**: houses rebuilt at the pack's true size, with house styles for Dawn's Gate and Murkwater. (e2445742.)
- **Melee hit effects**: new effects from Ashwin's picks, each with its own colours, size and length in data/melee_fx.json. (Engine 7845e466, game 09684c22 and 460cb354.)
- **Crooked House as one multi-floor building**: storeys in one grid with stairs and a floor above that fades in, in the DnDGameEngine-3D multifloor. (Engine e2395cc3, game c0aa73f0.)
- **Game-ready trees and plants that sway**: EZ-Tree oaks, ash, aspens and pines, realistic ground plants, and wind on the trees and plants. (plants-live d444dee8.)
- **Cutscene stills rule**: every cutscene still, existing and new, stays cel. (86cb7d71.)
- **Dice sounds**: the d20 plays die_throw, with the dice recordings. (dc5b7f5d, 1deefeba.)
- **Pack people and sources**: Ashwin's four source packs and a male and a female Quaternius body in a peasant outfit. (4bc26a2f, 53406635.)
- **Sword re-angle and Rook on the pack clips**: Rook plays the animation pack's moves, holds his greatsword, and the blade clears his body. (8693a592, 96302554.)
- **3D overworld replaces the travel map (Wickermoor)**: the Wickermoor stretch is a 3D Terrain3D overworld, with an enabled switch in art/overworld/overworld.json. (5b846a8a.)
- **Realistic ground and rocks on every wild map**: the 46 wild maps have Poly Haven ground and rocks (8b6704e5, in 5b846a8a).
- **Terrain3D past the edges of playable maps**: Barrow Hill and five more open maps show Terrain3D land past their edges (80937571, 007dd3f5).
- **Terrain3D overworld pilot**: a standalone 3D overworld scene on Terrain3D with polyhaven grounds, pack_terrain.py and capture tools; the travel screen is unchanged. (bd096698, with wild-pilot's commits rebased in; the Barrow Hill boarding map is held, 64fba072.)
- **Corrupted Passenger faces his walk and the first car is staged**: Phantom and Corrupted Passenger turn to face where they walk, the fight starts at the far end after a banter beat, and foes start at the front. (Game 87d60bc1 and ed339c40, rebased onto main.)
- **Every figure faces the way it walks**: a rig facing check runs in make validate, the import tool sets the turn automatically, and ghost_crawler is fixed. (ed339c40.)
- **Train fixes**: the Vagrant's talk waits for the party to walk up, the floating vent is gone, and the mist between cars works both ways. (Batch 44c90ec6.)
- **Creature heights**: 61 villager figures have heights, fixing wynn_carter and zachariah_wainwright. (78460a35.)
- **Talking pout**: the jaw glides forward as it opens. (4f4ec935.)
- **Character glow**: figures no longer glow, since the engine's shader draws a rim. (00a410fc.)
- **Thinner crescent moon on the title**: the title picture's crescent is thinner and sits in open sky. (ccdbe04, in 2e7127b and 3baac817.)
- **Fully 3D look with Title A**: Modern finish only, and the photoreal title, vistas, loading pictures, Oak faces, travel map and app icon. (2e7127b, 3baac817.)
- **Corrupted Passenger max HP drain removed**: the drain no longer lowers a hero's maximum. (24e6665.)
- **Act 1 fix pair**: the Phantom's fight is the book's again, plus the drain riders and search-again fixes. (Engine 25c74b8b, game e6262b3.)
- **Act 1 voice**: the hero voices and all Act 1 lines are wired. (Engine 69a83f59, game 20250bb and 06d30f1.)
- **Docs**: the photoreal art rules in CLAUDE.md. (e1a76ef, 618007d.)
- **Lanes cleanup**: 44 landed lanes removed. (Local, not git.)

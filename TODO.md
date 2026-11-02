# TODO

Ashwin's requests and the merge queue. Each item shows its status. Items in progress link to the thread handling them. Finished items get a done mark and a one-sentence summary.

## In progress

| Item | Status | Thread |
|---|---|---|
| Fork the engine into DnDGameEngine-3D for Crooked Moon only (no Strahd support), with the submodule switch | In progress | [Fork the engine](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoVaJeDKhUy4UUtLtcYitgai) |
| Real 3D multi-floor grid, starting with the Crooked House, built in the DnDGameEngine-3D fork; houses rebuilt at the pack's true size | In progress (Ashwin said go) | [Rebuild the worlds](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoC7g6BsCwnrPHakr5kpoBPD) |
| Audit all visual effects: each gets a selection room and its own colour, size and speed settings | In progress | [Melee hit effects](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoHUCbLptUKMrnux7PbW3KTT) |
| Weapons and pack animations (Rook's switch to pack clips waits on Ashwin's verdict) | In progress | [Weapons/pack animations](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoWHuBM7pdpdhmz86LEs2vUs) |
| Cel cutscene stills (docs-cutscenes-cel 28081e80 queued) | In progress | [Look/title](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCPX3moU1VgdtYuw77oSqT) |
| Portraits for the 144 missing NPCs | In progress | [Portraits](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoMVcF4yx8zrzvExbupWQsVL) |

## In progress

| Item | Status | Thread |
|---|---|---|
| Game-ready trees | In progress (waiting on Ashwin's approval of an npm install) | [Terrain3D](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo9HDaCnEx5Du9CKzyerk5Dv) |
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

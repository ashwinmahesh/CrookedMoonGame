# TODO

Ashwin's requests and the merge queue. Each item shows its status. Items in progress link to the thread handling them. Finished items get a done mark and a one-sentence summary.

## In progress

| Item | Status | Thread |
|---|---|---|
| Rook's head still looks too big for his body: make his body a little broader (shoulders and torso) (Ashwin, 2026-11-03) | In progress (needs a capture to judge; waits for the Mac to be free) | — |
| Overworld pathing: in places like the Ghostlight wreckage the party gets stuck, walks in circles or steers round obstacles that aren't there; movement should look natural (Ashwin, 2026-11-03) | In progress (code first; Mac testing waits for Ashwin to finish playing) | — |
| Slow the walking speed and its animation to about 0.8 of what they are (Ashwin, 2026-11-03) | In progress (code first; Mac testing waits for Ashwin to finish playing) | — |
| Casting a spell from the character sheet (out of combat): a casting sound effect, and a visual effect for the spell when the sheet closes back to the game; the visual options are offered in a demo selection room with their own settings (Ashwin, 2026-11-03) | Queued: waits for the Mac to be free to test | — |
| A distinct floor texture for each train car (circus flooring in the circus car) and metal walls and floor in the Soulfire Stoker's engine room (Ashwin, 2026-11-03); in flight with the props work (lane/props-statues), not ready to land, waiting on Ashwin's OK | In progress | Improve props and fix Barrow Hill train (thread link to come) |
| The casting room is empty: the visual-effects selection rooms need their choices (Ashwin, 2026-11-03) | In progress | — |
| Chill Touch gets Disadvantage with a foe within 5 ft (Ashwin, 2026-11-03): could not reproduce on current main (the spell is a melee touch attack and a wizard's and Cordelia's casts, and Shocking Grasp, roll without it; new test_melee_spell_attacks_in_melee.gd); waiting on Ashwin's screenshot or log, or a pull of main | Open | — |
| Portraits for the 144 missing NPCs: 148 photoreal portrait jobs are queued at normal priority (the image server is paused) | In progress (queued, waiting on the server) | [Portraits](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoMVcF4yx8zrzvExbupWQsVL) |
| Audit all visual effects: each gets a selection room and its own colour, size and speed settings (melee hit effects are landed; the other effects are next) | In progress | [Melee hit effects](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoHUCbLptUKMrnux7PbW3KTT) |
| The full 3D grid build, lane 1: the grid rules (Ashwin's go, 2026-11-02; four parallel lanes, this comes first) | In progress (phase 1, floors and layers in three dimensions, and the aura fix across floors, are landed) | [Build the full 3D grid](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoEP6W92Q8En8FU5Ua72qWcK) |
| The full 3D grid build, lane 2: layered places in Act I | Landed (captures to come) | [Build layered places in Act I](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo9STS4ZhgYZszF24W7LcF77) |
| The full 3D grid build, lane 3: layered places in Act II | Landed (captures to come) | [Build layered places in Act II](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo4fZ26frPet33HksJfHHDy9) |
| The full 3D grid build, lane 4: fights work across floors | Mostly done: picking, previews, the cutaway, enemies on stairs and the pad's storey look (hold the radial, tab buttons) are landed; the capture is still to come | [Make fights work across floors](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoHbeq9yV8Dzht48g6u97Fnc) |
| Weapons and pack animations (Rook's switch to pack clips waits on Ashwin's verdict) | In progress | [Weapons/pack animations](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoWHuBM7pdpdhmz86LEs2vUs) |
| Cel cutscene stills (docs-cutscenes-cel 28081e80 queued) | In progress | [Look/title](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCPX3moU1VgdtYuw77oSqT) |

## In progress

| Item | Status | Thread |
|---|---|---|
| Narrator becomes the Strahd voice on Higgs at full quality: in the game for the 969 narrator lines re-recorded so far; about 2,185 more narrator lines are queued (generation is paused while Ashwin plays) | In progress | [Voices](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCmcjA1nT898YLNaBWaBba) |
| Re-record all existing lines: Act I and Wickermoor's first batches are done and in the game; the rest (about 4,250 lines, narrator and characters) are queued, paused while Ashwin plays | In progress | [Voices](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoCCmcjA1nT898YLNaBWaBba) |

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

- **The train's Corrupted Soulfire Stoker has the Stoker model** (Ashwin, 2026-11-03: placeholder in the tender car): the Stoker model was on main and imported all along, but the tender car's fight spawns the Corrupted Soulfire Stoker, which had no figure of its own. It now wears the Stoker's model with its own portrait (the audit shows 30 spawned monsters with a model).
- **The Wormhost surgeons wear their model** (Ashwin, 2026-11-03): the six surgeon entries in Memory's Rest (mr_ground) no longer ask for the zombie art, so they are drawn with the finished surgeon model (the audit now shows 29 spawned monsters with a model).
- **A search no longer cuts off the Narrator** (Ashwin, 2026-11-03: a search check interrupted dialogue that was playing): a passage that comes while the Narrator's voice is still speaking now waits and is shown (and voiced) once the line is done, or after 20 seconds at most; the game root already ignores keys during a conversation. (test_narration_waits_for_the_voice.)
- **Spell effects line up with the cast** (Ashwin, 2026-11-03: a delay between the action and the effect): a cast took about 0.74 s to leave the hand (0.36 s gathering, a 0.3 s hold, 0.09 s to the throw's hit frame), and now takes about 0.34 s: the gather ends early (0.3 s of its clip) and the hold is 0.05 s; test_cast_windup keeps it under 0.45 s. A weapon swing's effect already lands on the clip's hit frame, about 0.24 s after the swing starts for a hero; if a weapon effect still feels late, tell me which one.
- **The camera no longer detaches** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg); Ashwin, 2026-11-03: it came back, several times, at random): the rig follows a node and, if that node was freed (a token rebuilt for a swapped leader, a changed figure or gear) or a fight left the follow cleared, it simply stopped moving. Outside a fight and the free camera, the exploration view now points it at the leader's token again each frame. I found no logs of his sessions to confirm the exact trigger, so this fixes the whole class; if it still happens, a screenshot or the time would narrow it. (Engine camera-follow commit; test_camera_stays_on_party.)
- **Camera: speeds in Settings, closer zoom, level tilt** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg)): Settings, Game has Camera turn and Camera tilt (Slow, Normal, Fast, Faster) that the keys, mouse drag, trackpad and controller stick all follow; the camera zooms in closer (4.5 from 7), and tilts from level with the ground (0) to straight down (90), sitting at least 0.9 over what it follows so a level view never starts inside the ground. Fights and indoors keep their 25 degree floor. (Engine camera commit, game pin.)
- **A menu's lead-in line is said once** (Ashwin, 2026-11-03: the NPC repeated the line before the menu, text and voice, every time a choice led back): the lines before a node's first choice list are now said the first time the conversation comes to it and skipped on every return; a new conversation starts afresh, and the rest of the node (flags, conditions) still runs. (Engine fe9cccda; test_dialogue_lead_in_once.)
- **Stranded monster models brought to main** (Ashwin, 2026-11-03: the Wildpyre and the Soulfire Stoker showed placeholders): `make figure-audit` lists every spawned monster and NPC by what it is drawn with. The 71 NPCs in places all have models. For monsters, 14 finished models that were left on the old `figures-final` branch are now on main (otyugh, specter, ghoul, crimson clergy, ferryman, hospital horror, wormhost surgeon, serum brute, deepdreck, night creature, blood elemental, blood effigy, crimson abbot, centipede hag, weeping widow, bayou beast, bat hound), with their heights and the monster art that points at them: 26 spawned monsters have a model now (12 before), 51 are still on an old 2D sprite and 25 have nothing at all (the list is in the audit). The Soulfire Stoker has had a model on main all along, so its placeholder is probably his checkout's missing import.
- **Ladder fixes** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo885PDotQZrvX69iv4FXMtz)): ladders are no longer walkable (the exploration walk takes them out of its pathfinding, so the only way up or down is clicking one), a click on a floor picks the square on the floor the party stands on instead of the one under it, and the train cars' roofs are railed decks (they had no walls). (Engine a20ab0b1.)
- **Haint quest items findable** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo885PDotQZrvX69iv4FXMtz)): Jakob Braun's letter (the Mail Car's pink envelope) and the toad-faced stone (the Circus Car's marionette chest) were Investigation finds that the F key's Perception roll never counted, and a miss shut the hero out; now the F search finds them, a miss can be retried, and a small pulsing glint marks each until found. (Engine e8b4ec03; the steak and eggs are ordered in the Dining Car.)
- **Characters no longer bloom** (Ashwin, 2026-11-03: Phillip's face and shirt blown out white-orange in the lounge car close-up): several nearby lights each lit a character up to the per-light cap and the sum crossed the bloom threshold, so figures now cap their lights lower (`figures.light_cap` 0.85 to 0.5) and the bloom is a little softer (intensity 1.4 to 1.2, threshold 0.8 to 1.1); the dialogue capture tool takes `--location`, `--dialogue` and `--speaker` so the shot can be repeated.
- **Act III plays end to end** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoJ6oZfYVoFQJfnjMy151uen)): `make qa-act3` plays Act II then Hartsblight to the Crooked Nightmare, the Act III blockers and journal stages are fixed, the Silent Church's choir loft and the Crooked Bookshelf's upper shelf are decks, and Act III has eight magic finds usable in a fight. (Game 5 commits, the last 979812d5's replay.)
- **The Wildpyre has its real model** (Ashwin, 2026-11-03: a placeholder was showing in the baggage car): the finished Wildpyre model and its texture, with figure entries for both sizes and their heights, were only on the old `figures-final` branch (commit 7a4fbfcd) and never reached main, so main drew a placeholder. Brought over; the baggage car fight shows it now.
- **Ladders can be used** (Ashwin, 2026-11-03: he couldn't climb the train cars' ladders): a ladder between floors is now something to point at and click ("Climb up the ladder"); the party walks to its foot, or its top coming down, and climbs it, with the right-click menu offering it too. Before, ladders were only drawn and used by the pathfinding, and the floor above is out of sight from below, so there was nothing to click. It applies to the train cars, the stable loft, the bookstore gallery and every other layered place; a pull of main is needed for it. (Engine f20e65b9, game below.)
- **Wider layers, no long narrow decks** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo9STS4ZhgYZszF24W7LcF77)): the village footbridge is nine squares by two, Dawn's Gate's road bridge and the other Act I decks are wide enough to stand and fight on, and Act II's casino balcony, dovecote walkway, grotto bridge and tomb platforms are three squares deep, with a test that no layer is a narrow strip. (Game 661a4bb9 and 9804318d.)
- **Act I re-recorded and in the game**: all 1,144 Act I lines (441 narrator in the Strahd voice, 703 characters at full quality) replace the old takes, along with the re-recorded Wickermoor, Foxwillow, banter and names batches; `make voice-wire` now prefers the `-full`, `-fill` and `narrator-gaps` batches. 2,275 old clips replaced (969 narrator, 1,306 character), 54 new lines wired. (Game ed43f2e2.) Still without a clip in Act I: nine of the baby's noises, six car-banter lines and the narrator folder's 147 shared lines.
- **Upper-floor walls full height, ladders climbable** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo9STS4ZhgYZszF24W7LcF77)): a storey's walls now run up to the floor over it (a band the cutaway hides with that floor, so the party is never shut out), the stable loft stands unfurnished, ladders reach a floor, bridge ramps climb by treads, and the cutaway keeps the party in sight on bridge places. (Engine 54f90d9c, game below.)
- **Merchants sell items, magic items and spell scrolls**: every non-story item is buyable, with 15 NPC files stocked (5 of them new shops) from data/treasure/shop_stock.json by tools/content/build_shop_stock.py, and Haint Hooch goes from 0 to 400. (Game 26d6ea13.)
- **More magic items to find in the world, all usable in combat (Acts I and II)**: 15 containers of magic finds in Act I and II places, from data/treasure/world_finds.json by tools/content/place_world_finds.py (rerun it, with `--check`, after a build script rewrites a place; the clock chamber and captain finds sit on their merged floors). (Game 208256f3.)
- **Layered places in Act I** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo9STS4ZhgYZszF24W7LcF77)): the stable's hay loft, the bookstore's gallery, the dovecote's perches, the windmill's stone floor, the village footbridge and the Dawn's Gate bridge are decks over the ground, with ladders, ramps and rails; the mayor's house and its clock chamber are one place; the Ghostlight Express's cars g1 to g7 have walkable roofs. (Engine a6857fa5, game 4886146e to e3dd04e2.)
- **Layered places in Act II** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo4fZ26frPet33HksJfHHDy9)): the riverboat's four decks, the dovecote, Memory's Rest, the casino balcony and the tomb platforms are stacked places of their own. (Game 504b04c9 to 346d34fa.)
- **Cheat codes from Curse of Strahd**: a code for every item (899), listed in docs/cheat_codes.md by `make cheat-codes`, with a validate check and tests; rerun it if the merchants batch adds items. (Game 3fc2dc9b.)
- **Fights across floors (part one)** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoHbeq9yV8Dzht48g6u97Fnc)): you pick, aim and preview on every storey, the cutaway follows whoever is acting, the = and - keys move the view a storey, and enemies climb to a hero upstairs and archers shoot down a stairwell. (Engine ed6679c1, game fa4e7789.)
- **Auras across floors**: each square is measured where it stands in the building, and an aura reaches another floor only with a line of effect (past a bridge's edge, never through the boards). (Engine cf80a98a, game dac1a050.)
- **Full 3D grid rules, phase 1** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoEP6W92Q8En8FU5Ua72qWcK)): the engine's grid has floors and layers in three dimensions, with deviations for railings, flying and climbing between floors, and areas across floors, giving lanes B1 and C a base. (Engine e7049dad, game 6debb5dd.)
- **An NPC in Wickermoor Hollow raises dead heroes for a price** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoPPR4UsoGK7bQTEnN8LobsA)): Mori Shade at the funeral home, exactly 1,000 gp per dead hero, with no goodwill discount (was 100 gp per party level; Ashwin, 2026-11-02), open 07:00-23:00. (Engine b6ae441d and the `fixed_price` flag 494b1b63, game fdff89cf to 966d2eef.) Do not rerun `tools/content/build_wickermoor.py` over data/npcs: it is out of date and would reset the sprite ids.
- **The 12 subclass spell swaps**: Ashwin reviewed and approved the swaps that replace spells which left the game (2026-11-02).
- **Free camera tilt, WASD camera and the free-camera toggle** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoSzp46E7B1MJ2tH6jYEQUCg)): the camera tilts from 10 to 85 degrees (fights and indoors stay at 25 or more), WASD turns and tilts it while the arrow keys move the party, and the Y key or a bar button toggles a free camera. (Engine 1a8eb54d, game 6a46ed4c.)
- **The Crooked Moon's plants rebuilt**: the 12 Blender plants read as real up close on a second leaf atlas and Poly Haven CC0 bark (credited), with the engine's textured-bark and `leaf2` paths off by default. (Engine d2d5a171, game 00d52b77.)
- **Act I plays end to end** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfoPPR4UsoGK7bQTEnN8LobsA)): Wickermoor and the Crooked House run from the wreck to Vessla at level 4 under `make qa-act1`, with a playthrough test and the arrival quest reaching its dinner stage. (Game 5080d71c to 94cd5b82.)
- **Act II plays end to end** ([thread](#cmsg_01F8aEzyaJ5ZJPFSJdcmHFfo8gwgSE3UZCbXg1Buprugch)): `tools/qa` is back with `make qa-act2`, and the Memory's Rest dock, the Bloody Sanctum softlock, the level 8 milestone in either order, repeat fights, quest stages stepping backwards, the sealed otyugh and 31 reinforcements' side are fixed. (Game 1fef2c59 to 5ca569ff.)
- **Cellar light**: the cellars have brighter, warmer moods of their own and three lanterns on the far walls of each. (Game 9d512488, 3b620c4a.)
- **No battle tuning tests**: CLAUDE.md, the QA guide and the Makefile now say never to run battle tuning, difficulty or party-performance runs unless Ashwin explicitly asks. (Game db94f109.)
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

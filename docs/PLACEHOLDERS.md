# Placeholders to replace

The foundation (Lane A, 2026-10-29) copied the host contract's files from Curse of Strahd so the game boots, and stripped
the old campaign's content wherever it is only data. **Everything below is a placeholder.** Each row says what the file is
now and what replaces it; the plan's phases and workstreams (W0 to W11) name the lane. When a placeholder is replaced, delete its
row. `tests/unit/test_host_contract.gd` keeps the contract met meanwhile.

The engine handbook's list of the host contract is `addons/dnd_core/docs/handbook/new_game.md` section 3.

## Look and art (W7, W8)

| File | Now | Replace with |
|---|---|---|
| `art/palette/palette.json`, `ui_palette.json`, `palette.png`, `palette.gpl` (built by `make palette` from the list in `tools/art/build_palette.py`) | The old game's 49 world colours and 20 menu colours, unchanged (the engine's own screens ask for names such as `void`, `parchment`, `vampire_red`) | The eighties-anime-cel palette (about 50 vivid names: pumpkin orange, witch purple, slime green, deep indigo for black); keep every name the engine asks for |
| `art/plants/` (`cards.png`, `cards.json`, `flora.json`, `manifest.json` and 43 `.glb` plants) | The old game's leaf cards and tree and plant models, copied unchanged | A plant set for the folk-horror valley (corn, turnip lanterns, willows, wytch trees) in the new look |
| `art/ui/map/barovia.png` | A neutral indigo painting at the old map's size (2528 x 1696), generated; the engine preloads this fixed name | The Wickermoor Hollow travel map; rename after the engine's key (plan E1) lets a game name its own |
| `art/ui/title_backdrop.png`, `art/ui/app_icon.png` | Generated indigo pictures with a pale crescent | Title art and the app icon |
| `art/atmosphere/moods.json` | The old game's six generic moods (woods, indoors, crypt, chapel, tavern, cave); the test hillside and its region use `woods` | A mood for every place and region, the hours of the eternal night (plan 8.3, E2) |
| `art/vistas/vistas.json` | The old styles; the test hillside has a ring of woods and mountains. `castle` and `lake` are the engine's required keys (it assumes both) and point far off the map with `within: 0` | The painted backdrops past each map's edge; ask the engine to make `castle` and `lake` optional |
| `art/sprites/props/catalog.json` | The old catalog cut to the art the engine itself has (props, models, rooms, floors, clutter); every place-keyed rule is gone | Rules for the new places; the Halloween props |
| `art/credits.json` | The engine's rules, icon, controller and sound-effect credits | Add every artist, track and tool as they arrive |
| `art/sprites/ilse_varga`, `tamsin_tealeaf`, `hedda_ironvow`, `silvain_aster` (walk and attack sheets), `art/sprites/villager`, `art/portraits/` for the ten pregens and `hero_01` | The old game's class looks, which the engine borrows for any hero without a look of its own (`CombatToken.default_look`), and its gray-box villager | The six companions' sprites and portraits (W8); the borrowed class looks stay as the engine's fallback |

## Data (W2, W3, W6)

| File | Now | Replace with |
|---|---|---|
| `data/pregens/*.json` (ten) | The old game's ten heroes. The engine's own 150 unit tests build them by id, so they stay while those tests need them | Add the six companions (`tools/data/pregen_specs.json` and `make_pregens.gd`); the placeholder party of four is `ilse_varga`, `tamsin_tealeaf`, `hedda_ironvow`, `silvain_aster` (`world/game_root.gd` `PLACEHOLDER_PARTY`). Their `roster: true` flags (the six on the title screen) go to the companions |
| `data/weather/barovia.json` | The generic climates, one region; the engine reads this fixed name | The valley's weather by hour; rename once the engine names it in `data/campaign.json` (plan E1) |
| `data/progression/xp.json`, `chapters.json` | The 2024 level and budget tables kept; no milestone quests, no villain withdrawal pay; one chapter, `new_game` | Milestone quests per chapter; one chapter per package |
| `data/treasure/levels.json` | The rarity tables kept; one region (`test_grounds`, level 1) | The party's level in every region |
| `data/ai/profiles.json`, `data/busts/facing.json`, `narrative/combat/bosses.json` | Empty | Boss titles, AI wants, which way each bust faces |
| `data/camp/night_visitors.json` | The old game's land-based groups (forest, marsh, mountain, town, indoors), the castle ones dropped; only `test_grounds` is mapped | Visitors by the valley's lands, tuned on a tired party (see the engine's camp doc) |
| `data/loading/cards.json` | The tips only; no region has a picture | A picture per region, once the cutscene art exists |
| `data/glossary/terms.json` | The old game's rules glossary with the entries that name its campaign dropped | Add the book's own terms |
| `data/achievements/e1.json` | The engine's generic hidden achievements | The campaign's achievements through the campaign module |
| `narrative/combat/barks.json` | The old game's battle cries, the lines that name its campaign dropped | Barks for the Crooked Moon's foes (W9) |
| `data/encounters/arena_wolves_and_zombies.json` | The first fight: the placeholder party against three scarecrows and a swarm of ravens in a clearing. The file keeps the engine's fixed arena id (`CombatArena.ENCOUNTER_ID`) | Keep a fight here until the engine makes the arena's id a key |
| `data/locations/test_hillside.json`, `data/flags/test_grounds.json`, `data/schedule/test_grounds.json` (the engine reads `data/schedule/`, so a file must be there), `narrative/narrator/test_hillside.dialogue` | The foundation's natural test place | Delete once the Ghostlight Express (R10) is the first place; keep as a capture fixture if useful |

## Code (W0, W2)

| File | Now | Replace with |
|---|---|---|
| `story/tarokka.gd`, `world/tutorial/tutorial_session.gd` | Two stubs: the engine names a game class `Tarokka` (its dialogue screen draws a reading card through it) and a game class `TutorialSession` (its touch controls), so a game must have both even with no reading and no tutorial | The Fated Tarot (plan G1, engine E22) and, if wanted, a tutorial in the new world; the engine lane should make both duck-typed |
| `story/crooked_moon_campaign.gd` | An empty `CampaignModule`: no reading, no villain's attention, ordinary spells, no ending | Plan G1: the Fated Tarot, the ritual track and the Crooked Moon's gaze, Adela's visions, endings, the parley, barks, defeat text, achievements |
| `world/look/crooked_moon_look.gd` | An empty `CampaignLook`: no set piece | Plan G8: the Crooked Moon in every sky, the Oak of Many Faces, the Crooked House, the Express, the Wicker Man, the Crooked Tree |
| `world/game_root.gd` | A copy of the old game's root with its villain visits, Tarokka and tutorial taken out. `_visit`, `_visit_on_road`, `visit_after_rest` and `_night_visit_over` are marked stubs; `FIRST_LOCATION` is `test_hillside` | The campaign module's visits (G1); defeat that continues the story (E10); the Express as the first place |
| `story/endings.gd`, `ui/screens/ending_screen.gd` | The data-driven endings mechanism and screen, with the old game's parley, heir gift and villain-destroyed flag emptied (`PARLEY_ENDS`, `HEIR_GIFT`, `CAPTURE_FLAGS`) | The six story endings and four of Moonfall (`data/endings/`) |
| `ui/menu/main_menu.gd`, `difficulty_page.gd` | The old title with this game's name and plain placeholder lines; the tutorial offer and the animated title (`TitleAmbience`) are gone | The title and its look; a tutorial in the new world (the engine's Skirmish and lab remain) |
| `scenes/test/graybox_room.tscn`, `sprite_gallery.tscn`, `scenes/skirmish.tscn`, `scenes/combat/arena.tscn` | The engine's own gray-box room, gallery, Skirmish and arena, as thin roots | Keep |
| `tools/data/validate_data.py` | The old game's Tarokka and villain-visit checks are still there, dormant (no such data exists here); `magic_prices.py`, `cheat_codes.py` and `respell.py` were left out | Rewrite the dormant checks for the Fated Tarot and the Crooked Moon's gaze with the campaign module (G1); the final-battle rules were removed and come back with the book's own |
| `tools/data/data_sources.py` | Still words its notes for the old game's sources | Reword when it is next run |

## Engine leftovers that still carry the old campaign's names

These are in the public engine and are not this repo's to fix, but the game works around each; the engine lane (W1) removes them
and this game then drops the workaround (`tests/unit/test_engine_names.gd` counts Crooked Moon names in the engine, not these).

- `art/ui/map/barovia.png` and `data/weather/barovia.json` are fixed paths; `art/tarokka/<card>.png` is where the dialogue UI looks
  for reading cards; `CombatArena.ENCOUNTER_ID` is `arena_wolves_and_zombies`.
- `ui/dialogue/dialogue_ui.gd` names the game class `Tarokka` and `ui/common/mobile_controls.gd` names the game class `TutorialSession`
  (a game that has neither does not compile; neither is in the handbook's host contract). `Schedule` pushes an error when
  `data/schedule/` is missing, and `Vista` needs `castle` and `lake` in `vistas.json`.
- `LongRest.STRAHD` and `LongRest.waits_on_strahd` name a visit that broke a rest; `world/game_root.gd` calls them.
- `CombatToken.default_look` borrows the looks of four of the old game's heroes by id, and the engine's unit tests build ten of its
  pregens by id.

## Engine tests that need Curse of Strahd's content

`tools/run_tests.py` `EXCLUDED_ENGINE_TESTS` lists the engine's own tests that play the old game's places and people (they pass only in
that game). The full run leaves them out; `make test FILES=<name>` still runs one. The engine lane (W1) makes each host-independent and
takes it off the list.

## Left out of the foundation on purpose

The art, voice, wiki, release and iOS tools, `blender/`, the Barovia capture scenes, `tools/disk`, `tools/balance` and the cheat-code,
magic-price and respell tools. Later lanes copy and retarget what they need (the art and voice tools to the local image and voice
services).

# The Crooked Moon — agent rules
Godot 4.7.2 (typed GDScript) · Blender 5.2 (only when Ashwin says the Mac is idle) · macOS, the Mac Ashwin works on
Plan: ~/Documents/Obsidian Vault/Crooked Moon/Crooked Moon Game Plan.md, with Crooked Moon - Chapter Packages.md, Crooked
Moon - Engine and Systems Work.md and Book Digests/ beside it (status updates are fine; scope changes go through the plan thread)
Build logs for Ashwin: ~/Documents/Obsidian Vault/Crooked Moon/Build/ ("Build Log NN - <title>.md"). Markdown notes live in the vault, not here.
Bug reports from Ashwin (F12 or the pause menu in dev builds): ~/Documents/Obsidian Vault/Crooked Moon/Bug Reports/<date>T<time>-<title>/
with report.md (front matter `status: open`), screenshot.png, save.json (env CROOKED_MOON_BUG_REPORTS moves it)
Decisions: docs/adr/ · Tasks: docs/tasks/ · Rules coverage and deviations: docs/rules/ · Placeholders to replace: docs/PLACEHOLDERS.md
Engine handbook: addons/dnd_core/docs/README.md (process, testing, pipelines, gotchas, the look). Narrator's rules: addons/dnd_core/docs/design/narration.md

## Commands (add new ones to the Makefile)
make run (the edge build) | run-main | test [ONLY=substr FILES=a.gd,b.gd JOBS=n] | golden-saves | validate | lint |
check [DRY=1] [DEPTH=n] | ci | capture [SCENE=… NAME=… FRAMES=… LOCATION=…] | smoke [SCENE=… FRAMES=n] | arena | import | lfs-quiet |
palette | hooks | voice-wire [DRY=1 PRUNE=1 LIST=1] | lane / lane-done / lane-seed [NAME= BRANCH= SSD=1] | edge-* | slots-test | tools-test | sketch HEIGHT=… LAYOUT=… SIZE=WxD [LOC=… PREVIEW=…]
Not copied yet (later lanes retarget them to the local services): the art, voice, wiki, release and iOS tools and blender/.
The engine is the git submodule addons/dnd_core (public repo DungeonsAndDragonsGameEngine): after a fresh clone or a lane,
`git submodule update --init` and `git lfs pull` inside it; to change it, edit and commit inside addons/dnd_core, push the
engine first, then commit the new submodule commit here (its path shows as the change).

## Who does what (Ashwin's model rules)
- Plans, design calls, lane briefs, reviews: Opus 5.5, extra effort. Implementation (engine systems, the campaign module, chapters,
  companions, options, bestiary, look): Sonnet 5.5, extra effort; smaller tasks (data fixes, single fights, art and voice batches):
  Sonnet 5.5, high. Building, merging and testing: Haiku 5.5, high. Pass model and effort at every lane start.
- Lanes run in `make lane` worktrees on the SSD image (below). Only the builder pushes main. Ashwin is the only commit author.

## Godot windows (Ashwin works on this machine)
- Never open a Godot window that can take focus or cover his work. Checks without pixels run headless (`make test`, `make smoke`);
  screenshots only through `make capture`, which draws off screen. Batch screenshots. Any other windowed run goes through `tools/godot`.
- At most 3 import editors and 8 headless test processes run at once across all lanes AND both games: the slot folder
  /tmp/strahd-godot-slots-<uid> is shared with Curse of Strahd on purpose (tools/godot_slot.sh, tools/run_tests.py). The build
  lane keeps part of it (`BUILD_LANE=1`, only the build thread sets it). A run past the cap waits its turn and says so.
- Stop only your own processes, by PID: never `pkill` by pattern. A Godot `--script` tool with a script error before `quit()` idles
  forever: log it and kill your own PID. The shell is zsh: `${=VAR}` splits words, `${h}:path` dodges modifiers, there is no `timeout`.
- `make run` is for Ashwin to play: run it only when asked.
- Curse of Strahd (~/Documents/CurseOfStrahdGame, its saves, settings, lanes and the StrahdLanes image) is read-only to this game.

## GPU, images, voices, dialogue (local services; nothing costs money)
- One GPU. ImageGen-Service (port 5742, ~/Documents/models/ImageGen-Service/docs/api.md) and VoiceGen-Service (port 5743, README.md and
  API.md beside it) never run together; both queues stay on. Before using either, `mkdir ~/.crooked-moon/gpu.lock` (atomic; if it exists
  read its `owner`, check every 2 minutes, never wait over 45 minutes without telling the plan thread), write your lane and the time
  into `owner`, switch with `/opt/homebrew/bin/python3 ~/Applications/"Daemon Monitor.app"/Contents/Resources/control.py stop|start image|voice`
  (stop the other first), and remove the lock when your batch is done. Never stop a generator that is busy with someone else's job.
- The look (Ashwin, 2026-11-02, plan 8.1): fully 3D with realistic lighting and textures; no toon, no cel, no HD-2D. The game offers only
  the Modern finish (data/campaign.json). Curse of Strahd stays HD-2D on the shared engine, so wherever this game diverges the change
  lives in this repo, never in the engine's defaults.
- Images (cutscene stills, loading pictures, title, travel map, vistas, the moon, decals): photorealistic. Z-Image Turbo with no style
  LoRA; append the words in art/prompts/photoreal_preamble.txt (the look lane writes it; until then plan 8.1) to every prompt. Never
  the Giallo LoRA or the old look P cel style. For a cut-out, ask for a plain flat white background; the pipeline removes it. Fix a
  finished picture with an edit model (FLUX.2 Klein, Qwen-Image 2.1 Turbo) rather than re-rolling.
- Voices: VoxCPM2 designs voices (always three options per character), Higgs reads the lines. Pinned in audio/voice/casting.json,
  each line's delivery in audio/voice/directions.json. A clip is keyed by its text, so editing a voiced line silences it until re-read.
  Finished takes reach the game through `make voice-wire` (copies them into audio/voice and counts the lines still without a clip).
- Dialogue and character writing: drafted by Gemini 4 Argon medium through ai-bridge (http://127.0.0.1:8765, ~/.crooked-moon/bridge.py,
  run with `/opt/homebrew/bin/python3 -I`; read the ai-bridge skill; never print the token; don't start or restart the bridge). Keep the
  brief and the raw reply in docs/plans/gemini_*/. Every Narrator line follows the Narrator's rules (second person, present tense, one
  or two sentences, no game terms, no unearned facts; the engine's docs/design/narration.md) and the voice guide of the game's persona,
  the Vagrant (folksy, warm, wry, a Southern drawl).

## The book is paid content
- The campaign book, its PDF and text live only in ~/.crooked-moon/book: never in a repo, a commit, a capture or a hand-off. Every data text,
  summary and dialogue line is our own words. This repo is private; the public engine never gets a book name or number (the game's
  features module and campaign module hold them). Notes and digests: ~/Documents/Obsidian Vault/Crooked Moon/Book Digests/.

## Code
- Static types everywhere; `untyped_declaration` is an error.
- The engine's `rules/`, `combat/` and story engine are pure libraries: no nodes, scenes, autoloads or UI. They take a DiceRoller argument.
  Scenes and the HUD only show combat and send it commands.
- Every die roll goes through DiceRoller (Dice.roller in game code). Cosmetic randomness uses its own RNG.
- The player controls every party member and guest; AI only drives enemies and neutrals.
- Scenes are built in code; .tscn files are thin roots. 1 world unit = one 5 ft square.
- After adding a class_name, `make import` before `make test`. Commit the `.uid` Godot writes beside every script.
- A change to what a save holds bumps `GameState.SAVE_VERSION` and adds a `SaveSystem.upgrade` step; then `make golden-saves` adds the new
  version's saves beside the old ones in tests/saves, which every test run loads. Tell Ashwin before a save version bump.
- Campaign facts reach the engine through `Campaign.module()` (story/crooked_moon_campaign.gd, named in data/campaign.json) and set pieces
  through `CampaignLook` (world/look/crooked_moon_look.gd); per-creature or per-campaign facts go in data or the module, never in the engine's
  files. tests/unit/test_engine_names.gd fails when an engine file gains a Crooked Moon name (its own baseline only shrinks).
- A lane's folder: `make lane NAME=<name> BRANCH=<branch> SSD=1`; `make lane-done NAME=<name>` once merged. Never write into the main
  checkout, never `git stash` (the stash is shared by every worktree), and clean up your own folders, captures and logs.

## The world: a natural place first, the grid laid over it
- Design every place as a real place: land with height (hills, hollows, banks, ledges, cliffs, steps, creek beds), water, woods, buildings where
  they would stand, paths worn where people walk, fences, carts, gardens, scattered leaves and pumpkins. Never think about squares while
  designing. Then lay it into the `map.rows` and `map.elevation` rows; the battle grid is an overlay held on a key, never painted into the
  ground. Whatever gives the grid away (a square pond, rows of trees, a flat-topped block, a cliff as a slab) is a bug. Engine docs:
  addons/dnd_core/docs/design/game_design_principles.md sections 1.6 and 5.1.
- The book's layouts hold (rooms, paths and features sit where the book puts them), richly dressed with Halloween everywhere. Unmapped
  places get maps of ours. Give every outdoor place some height. Never move an existing walkable square, spawn or exit (the bots are
  path-sensitive): extend a map, don't redraw it.
- The camera looks about 30 degrees down at the party (Curse of Strahd's was 40): campaign data, plan E28; every sprite is drawn for it.

## Rules engine
- Data is read through `Compendium.shared()` (the engine's data root and this game's; a game entry replaces the engine's of the same id).
  Modifiers follow the engine's modifiers contract: add a stat to the contract and the engine together, never only in data. Every number the
  UI shows is a `Breakdown`.
- A character is its `build` (keyed choices); `refresh()` derives the rest. The UI never computes rules.
- Rules source: the 2024 PHB, DMG and 2025 MM as the engine has them, plus the book's own options, bestiary and treasury. Rule deviations go
  in docs/rules/deviations.md; a rule is "done" only when coverage.md says so. `make validate` checks both docs against the data.
- Data `text` and `summary` are our own words, never copied. Engine changes sit behind keys that default to Curse of Strahd's behaviour
  and run the engine's tests and both games' quick checks.

## Art
- Colours only from art/palette/palette.json, plus art/palette/ui_palette.json for menus (via Look); run `make palette` after editing the list in
  tools/art/build_palette.py. Palette names tint lights, moods and code-built props; textures and pictures keep their own colours.
- Asset packs from the internet: CC0 or clearly free licences only, kept untouched with their licence in art/sourced/<pack>/, listed in the
  credits (art/credits.json), each download after Ashwin's typed yes. Credit every artist.
- Every character and monster is a 3D figure (Ashwin, 2026-10-30): a rigged Tripo model from its turnaround,
  listed in art/figures/manifest.json (its `source` under the asset root's tripo/models) and copied in with 2K textures by
  `python3 tools/art/figures.py`; the engine draws it wherever the art id would be a sprite (docs/reference/art/figures.md in
  the engine). A figure without a model falls back to its 8-direction sprite. Capture them with
  `make capture SCENE=res://tools/capture/figures_capture.tscn`. Set dressing comes
  from the props catalog; never fall back to plain boxes for new content. UI draws on CanvasLayers so the palette pass never touches it.
- Git LFS for new or changed images, voice and sound clips (see .gitattributes). Never `git lfs migrate` or `git add --renormalize`; stage
  only files you changed (`make lfs-quiet` clears timestamp noise). Force-add new art's `.import` files (`git add -f`): *.import is ignored.

## Keys and Ashwin's files
- Never ask for, store or echo a key. Tools read keys from his environment. Never touch his saves or settings; tests and captures use
  their own folders. Never write into Curse of Strahd's repo, saves or lane image.

## Done means
- Hand off with `make check` green and a clean log: lint, a compile of every script, `make validate` when data, dialogue or the rules docs
  changed, and the test files you added or changed, never the whole suite. Run the tests your change is about with `make test FILES=...`
  while you work. The build thread runs the full suite once per batch.
- A new screen or panel goes into tests/integration/test_layout.gd. A capture for anything visual (`make capture`).
  Never weaken tests to pass; never mark a sign-off of Ashwin's as passed.
- Never push main: push your own branch, if anything. Only the build thread pushes main, with CM_PUSH_MAIN=1; the pre-push hook
  `make hooks` installs refuses anyone else.
- Commits: Ashwin is the only author. No co-author, session or "generated with" lines, in any commit. Small commits, plain-English messages.

# The Crooked Moon: the one set of commands. Godot 4.7.2 on macOS (Blender 5.2 later, with the art tools).
# Copied from Curse of Strahd's Makefile and trimmed: the art, voice, wiki, release and iOS targets are left out for now
# (later lanes retarget them to the local image and voice services).
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c
GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
G       := $(GODOT) --path .
## run and arena: Godot started by a tool skips its extra "unbundled activation hack" when the bundle id matches and no
## standard stream is a terminal; from the owner's terminal the game still comes to the front.
NOFOCUS := env __CFBundleIdentifier=org.godotengine.godot $(G)
## Agent runs that open a window go through tools/godot, which keeps Godot from ever taking focus (CLAUDE.md).
UNSEEN  := GODOT=$(GODOT) tools/godot --path . --resolution 1x1 --position 100000,100000 --max-fps 60 --audio-driver Dummy
LOGCHK  := tools/logcheck.sh
## Imports with the editor's window kept off screen, so textures import several at once (tools/import.sh: about twice
## as fast; headless outside a desktop session or with IMPORT_HEADLESS=1). Its own notes go to stderr, shown here; a
## refused import (exit 75: a full one with under 20 GB free) or a stopped one stops FRESH without marking it done.
IMPORT  := GODOT=$(GODOT) tools/import.sh
STAMP   := .godot/.last_import
FRESH   := if [ ! -f $(STAMP) ] || [ -n "$$(find . \( -path ./.godot -o -path ./captures -o -path ./builds \) -prune -o \
             \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.png' -o -name '*.ogg' -o -name '*.wav' \
             -o -name '*.mp3' -o -name '*.glb' \) -newer $(STAMP) -print -quit)" ]; then \
             echo "Files changed since the last import: importing first."; $(IMPORT) > /dev/null; s=$$?; \
             case $$s in 75|129|130|137|143) exit $$s ;; esac; touch $(STAMP); fi
## The import before a game the owner plays (run-main, arena) never waits for a Godot slot or takes one: he is at the
## terminal, so it must not queue behind lane imports and tests (tools/godot_slot.sh).
## It also brings the engine core up to the commit this checkout names first (tools/core_sync.sh): git pull doesn't.
PLAYFRESH := export GODOT_SLOTS=off; tools/core_sync.sh; $(FRESH)

.PHONY: run run-main arena anim-demo smoke import test lint validate ci check lfs-quiet palette capture sketch hooks golden-saves tools-test voice-wire cheat-codes icons

## make run plays the edge build (tools/edge/edge.py): main plus every lane branch that has been handed off but not merged
## yet, assembled in a throwaway worktree (CrookedMoonGame-edge, in the SSD lanes' image), so lane work can be tried as soon
## as it is handed off. It runs on its own user data folder, "The Crooked Moon Edge", but its saves/ and settings.cfg lead to
## yours (symlinks), so make run and make run-main share one set of saves and settings. The branches are listed in ~/.crooked-moon/edge/branches.txt, kept out of git: make edge-add
## BRANCH=<branch> · make edge-remove BRANCH=<branch> · make edge-list · make edge-prune (drops the merged ones) ·
## make edge-reset (removes the worktree; the next run makes it again) · make edge (assembles and imports, no window) ·
## make edge-test (the script's tests). EDGE_BASE=origin/main starts from the last ci-green main instead of main.
run:
	@python3 tools/edge/edge.py run

## This checkout's own code, as it is. Imports first when scripts or assets changed since the last import (a merge can add a
## class_name or images that the editor cache doesn't know yet, and the game then stops at a parse error).
run-main:
	@$(PLAYFRESH)
	$(NOFOCUS) < /dev/null

.PHONY: edge edge-list edge-add edge-remove edge-prune edge-reset edge-test slots-test
edge:
	@python3 tools/edge/edge.py build
edge-list:
	@python3 tools/edge/edge.py list
edge-add:
	@python3 tools/edge/edge.py add $(BRANCH)
edge-remove:
	@python3 tools/edge/edge.py remove $(BRANCH)
edge-prune:
	@python3 tools/edge/edge.py prune
edge-reset:
	@python3 tools/edge/edge.py reset
edge-test:
	python3 -m unittest discover -s tests/tools -p 'test_edge*.py' -v

## The Godot slot pools and the slots the build lane keeps (tools/godot_slot.sh, tools/run_tests.py); no Godot, no lane.
## The slot folder is shared with Curse of Strahd, so the two games never oversubscribe the Mac.
slots-test:
	python3 -m unittest discover -s tests/tools -p 'test_godot_slots.py' -v

## Recorded voice takes into the game: copies each finished take whose line is still spoken from the asset root's voice batches to
## audio/voice/<speaker>/<key>.mp3 (Git LFS) and prints how many spoken lines have a clip (tools/content/wire_voice.py).
## DRY=1 copies nothing; PRUNE=1 deletes clips no line speaks any more; LIST=1 names the lines with no clip yet.
voice-wire:
	python3 tools/content/wire_voice.py $(if $(DRY),--dry-run) $(if $(PRUNE),--prune) $(if $(LIST),--list)

## Every Python tool test (the edge build, the Godot slots, the quick check's engine tests); no Godot.
tools-test:
	python3 -m unittest discover -s tests/tools -p 'test_*.py'

## The combat arena: the four placeholder heroes against scarecrows in a cornfield (data/encounters/arena_wolves_and_zombies.json,
## the engine's fixed file name).
arena:
	@$(PLAYFRESH)
	$(NOFOCUS) res://scenes/combat/arena.tscn < /dev/null

## The animation speed bench: heroes and enemies walking, swinging, casting, flinching and falling, with a slider that sets
## how fast every figure animates (data/campaign.json `anim_speed`, WalkPace.anim). Skeletons only by default.
anim-demo:
	@$(PLAYFRESH)
	$(NOFOCUS) res://tools/anim_speed/anim_speed_demo.tscn < /dev/null

.PHONY: qa qa-story qa-fights qa-report qa-act1 qa-act2 qa-act3 qa-perf
## Headless QA (tools/qa/qa.py; no window, its own user data folder, output in captures/qa or OUT=dir).
## qa-story: the story bot plays the whole campaign from a new game with no script, and reports where it stuck
## (DICE=high|seeded SEEDS=1,2 STEPS=n). ## Which monsters and NPCs the places spawn have a finished 3D model, and which fall back to a stand-in, an old sprite or the plain
## placeholder (tools/qa/figure_audit.gd; headless, writes captures/qa/figure_audit.json or OUT=dir).
figure-audit:
	@$(FRESH)
	$(G) res://tools/qa/figure_audit.tscn -- --out=$(CURDIR)/$(or $(OUT),captures/qa)/figure_audit.json 2>&1 | grep -vE "^Godot Engine|WARNING|^ +at:" | $(LOGCHK)
qa-fights: every fight in the places' data played by the party autopilot at each
## difficulty, on SEEDS (1-8), at the level the story bot reached it at (ONLY=loc:id,id REGIONS=a,b MODES=... JOBS=n).
## qa-report: both into captures/qa/report.md. qa: all three.
## Never run qa-fights, or any battle tuning, difficulty or party-performance run, unless Ashwin explicitly asks (CLAUDE.md).
QA_OUT := $(or $(OUT),captures/qa)
qa-story:
	@$(FRESH)
	GODOT=$(GODOT) python3 tools/qa/qa.py story --out $(QA_OUT) --dice $(or $(DICE),high) --seeds $(or $(SEEDS),1) $(if $(STEPS),--steps $(STEPS),) \
		$(if $(ORDER),--order $(ORDER),)
## qa-act2: Act II's five chapters played by the story bot from a new game, in two orders (the book's and its reverse);
## each run must finish all five at level 8 (ORDERS="r13,r14,r15,r16,r17 r17,r16,r15,r14,r13" to pick others).
QA_DEFAULT_ORDERS := r13,r14,r15,r16,r17 r17,r16,r15,r14,r13
QA_ORDERS := $(or $(ORDERS),$(QA_DEFAULT_ORDERS))
qa-act2:
	@$(FRESH)
	@for o in $(QA_ORDERS); do GODOT=$(GODOT) python3 tools/qa/qa.py story --out $(QA_OUT) --dice $(or $(DICE),high) \
		--seeds $(or $(SEEDS),1) --steps $(or $(STEPS),12000) --order $$o || exit 1; done
## qa-act3: from a new game through Act II (ORDERS as qa-act2, the book's by default), then Act III's chain from Hartsblight
## to the Crooked Nightmare's end; each chapter must finish at its level (9, 10, 10, 11, 12) with no problems reported.
qa-act3:
	@$(FRESH)
	@for o in $(or $(ORDERS),r13,r14,r15,r16,r17); do GODOT=$(GODOT) python3 tools/qa/qa.py story --out $(QA_OUT) --dice $(or $(DICE),high) \
		--seeds $(or $(SEEDS),1) --steps $(or $(STEPS),30000) --order $$o --act3 || exit 1; done
qa-fights:
	@$(FRESH)
	GODOT=$(GODOT) python3 tools/qa/qa.py fights --out $(QA_OUT) --seeds $(or $(SEEDS),1-8) --jobs $(or $(JOBS),2) \
		$(if $(MODES),--modes $(MODES),) $(if $(ONLY),--only $(ONLY),) $(if $(REGIONS),--regions $(REGIONS),)
## qa-act1: Act 1 as a player plays it, from the title through the Ghostlight Express, Wickermoor and the Crooked House to
## Vessla dead at level 4 (SEEDS=1-4 MODE=balanced SHUFFLED=1 for the Switcheroo's own car order); every run's blockers are
## printed. CHECKPOINT=/abs/dir/slot saves the game where the Express ends; RESUME=/abs/dir/slot starts from such a save;
## REVIVE=1 brings fallen heroes back between steps (a stand-in, since nothing in Wickermoor raises the dead).
qa-act1:
	@$(FRESH)
	GODOT=$(GODOT) python3 tools/qa/qa.py act1 --out $(QA_OUT) --seeds $(or $(SEEDS),1) --mode $(or $(MODE),balanced) $(if $(SHUFFLED),--shuffled,) \
		$(if $(CHECKPOINT),--checkpoint $(CHECKPOINT),) $(if $(RESUME),--resume $(RESUME),) $(if $(REVIVE),--revive,)
## qa-perf: each place's build time and per-frame CPU cost, headless (REGIONS=a,b ONLY=loc,loc FRAMES=n); perf.md.
qa-perf:
	@$(FRESH)
	GODOT=$(GODOT) python3 tools/qa/qa.py perf --out $(QA_OUT) --frames $(or $(FRAMES),180) $(if $(REGIONS),--regions $(REGIONS),) $(if $(ONLY),--only $(ONLY),)
qa-report:
	python3 tools/qa/qa.py report --out $(QA_OUT)
qa: qa-story qa-fights qa-report

## Boots the game, or SCENE=res://..., headless for FRAMES frames (600); fails on errors. Agents check with this.
smoke:
	@$(FRESH)
	$(G) --headless --quit-after $(or $(FRAMES),600) $(SCENE) 2>&1 | $(LOGCHK)

import:
	$(IMPORT) | $(LOGCHK) > /dev/null
	@touch $(STAMP)

## The test files share several headless Godot processes (tools/run_tests.py); JOBS=n sets how many, JOBS=1 is one.
## FILES takes bare file names (a path runs the whole suite).
test: import
	python3 tools/run_tests.py --godot $(GODOT) $(if $(JOBS),--jobs $(JOBS),) $(if $(ONLY),--only=$(ONLY),) $(if $(FILES),--files=$(FILES),) 2>&1 | $(LOGCHK)

## Lane folders that cost almost no disk (tools/lane.sh): a worktree whose files and import cache are APFS clones of the
## main checkout's. make lane NAME=<name> BRANCH=<branch> [BASE=main] · make lane-reclone NAME=<name> (a running lane's
## unchanged files become clones again) · make lane-done NAME=<name> (once merged). SSD=1 on any of them: the lane is on
## the external SSD's disk image (/Volumes/CrookedMoonLanes), cloned from a seed there. The seed is refreshed only when it
## has drifted from the lane's base (LANE_SEED_DRIFT files, 1500; LANE_SEED_ART_DRIFT textures, 40); make lane-seed SSD=1
## refreshes it on its own, LANE_REFRESH_SEED=1 on make lane forces a refresh first, LANE_NO_IMPORT=1 skips the seed's import.
LANE = $(if $(SSD),LANE_ROOT=/Volumes/CrookedMoonLanes )tools/lane.sh
.PHONY: lane lane-reclone lane-done lane-seed setup asset-root
lane:
	$(LANE) new $(NAME) $(BRANCH) $(or $(BASE),main)
lane-reclone:
	$(LANE) reclone $(NAME)
lane-done:
	$(LANE) done $(NAME)
lane-seed:
	$(LANE) seed

## The repo's git hooks (tools/git/), into the hooks folder every worktree shares: pre-push refuses a push of main unless
## CM_PUSH_MAIN=1 (the build thread's), then runs Git LFS's own pre-push.
hooks:
	cp tools/git/pre-push "$$(git rev-parse --git-common-dir)/hooks/pre-push"

## Where generated and static source assets live on this computer (tools/asset_root.py): image and voice takes, portrait
## options, renders, captures worth keeping. It is outside git so it can sit on an external drive. make setup
## ASSET_ROOT=<folder> sets it for this clone and all its worktrees (git config cm.assetRoot); CM_ASSET_ROOT overrides it; with
## neither it is .assets/ in the checkout. make asset-root prints it. Final art the game loads still goes in art/ through Git LFS.
setup:
	@if [ -n "$(ASSET_ROOT)" ]; then python3 tools/asset_root.py --set "$(ASSET_ROOT)" > /dev/null; fi
	@echo "Asset root: $$(python3 tools/asset_root.py --ensure)"
	@$(MAKE) --no-print-directory hooks

asset-root:
	@python3 tools/asset_root.py

## Golden saves: the tests keep a save in tests/saves (v<save version>_<name>.json, tests/support/golden_saves.gd); one already
## there is never made again. Every test run loads all of them (tests/integration/test_golden_saves.gd).
golden-saves:
	GOLDEN_SAVES=$$(git rev-parse --short HEAD) $(MAKE) test FILES=test_golden_saves.gd

## Git LFS noise: old art and clips that only changed timestamp stop showing as modified (tools/lfs_quiet.sh).
lfs-quiet:
	@sh tools/lfs_quiet.sh

validate:
	python3 tools/data/validate_data.py
	python3 tools/data/check_implemented.py
	python3 tools/data/check_rules_docs.py
	python3 tools/art/rig_facing.py --check
	python3 tools/data/cheat_codes.py --check
	python3 tools/art/audit_icons.py

## Every playable item's cheat code (Curse of Strahd's list, ported): docs/cheat_codes.md and Cheat Codes.md in the vault,
## rebuilt from the item data (tools/data/cheat_codes.py). Run it after adding or renaming items.
cheat-codes:
	python3 tools/data/cheat_codes.py

## Compiles every engine script (addons/dnd_core/rules, combat, story) and the game's own story/ standalone (no autoloads allowed there).
lint: import
	tools/lint_gd.sh

## Local CI: everything main must pass before a merge.
ci: validate lint test

## The quick check while working (CLAUDE.md says when it is enough): only what covers the files changed since main, from
## validate to the tests that use them (tools/check.py). make check [BASE=<branch>] [DEPTH=n|all] [DRY=1]
check:
	@$(if $(DRY),,$(FRESH))
	python3 tools/check.py $(if $(BASE),--base $(BASE),) $(if $(DEPTH),--depth $(DEPTH),) $(if $(DRY),--dry-run,)

## The palette files from the list in tools/art/build_palette.py (art/palette/*.json, .gpl and the strip the screen pass reads).
palette:
	python3 tools/art/build_palette.py

## Our spell, item and ability tiles (art/icons/<kind>/<key>.png) from art/icons.json, a game-icons.net silhouette and a
## tint per key, framed in the menu palette by the core's tools/art/build_icons.gd; the core's own tiles are left alone.
## Then make import. tools/art/audit_icons.py (in make validate) lists any spell, item or ability of ours without a tile.
icons:
	$(G) --headless --script res://addons/dnd_core/tools/art/build_icons.gd -- --game 2>&1 | grep -E '^icons:'
	python3 tools/art/audit_icons.py

## Writes screenshots to captures/ from a window that never takes focus or shows: it opens 1 px wide in a corner, moves off
## screen and is drawn by tools/capture (silent, 60 fps). LOCATION=<id> starts the story game there. The default scene is the
## foundation's place; SCENE=res://tools/capture/<x>.tscn for the audits, SCENE=res://scenes/combat/arena.tscn for the arena.
capture:
	$(UNSEEN) res://tools/capture/capture.tscn -- --scene=$(or $(SCENE),res://tools/capture/hillside_capture.tscn) --out=$(CURDIR)/captures/$(or $(NAME),capture) --frames=$(or $(FRAMES),90) $(if $(FOCUS),--focus=$(FOCUS),) $(if $(LOCATION),--location=$(LOCATION),) $(if $(ENCOUNTER),--encounter=$(ENCOUNTER),) $(if $(LOAD),--load=$(LOAD),) $(if $(DIALOGUE),--dialogue=$(DIALOGUE),) $(if $(BEATS),--beats=$(BEATS),) $(if $(MAP),--map,) $(if $(SHOP),--shop=$(SHOP),) $(ARGS) < /dev/null

## Works the 3D overworld out once and saves it (world/overworld/overworld_bake.gd), so it opens at once: run it after
## changing art/overworld/overworld.json or the travel map (a stale bake is ignored and the land worked out afresh).
overworld-bake:
	$(G) --headless res://tools/overworld_bake.tscn 2>&1 | grep -v 'Writing region' | $(LOGCHK)

## Lays a place painted as land into a location's grid (the engine's world/authoring/sketch_tool.gd, plan E29): HEIGHT= a
## height picture (black low, white TOP= feet up, default 30), LAYOUT= the layout in the key's flat colours, SIZE=WxD squares,
## LOC=data/locations/<id>.json to write (refuses to close a walked square unless FORCE=1), PREVIEW=captures/<x>.png.
sketch:
	$(G) --headless --script res://addons/dnd_core/world/authoring/sketch_tool.gd -- $(if $(HEIGHT),--height=$(HEIGHT),) $(if $(LAYOUT),--layout=$(LAYOUT),) --size=$(SIZE) $(if $(TOP),--top=$(TOP),) $(if $(LOC),--loc=$(LOC),) $(if $(PREVIEW),--preview=$(PREVIEW),) $(if $(FORCE),--force,)

.PHONY: gpu-scheduler-install gpu-scheduler-restart gpu-scheduler-status blender-queue blender-run

## The GPU scheduler (tools/gpu): voice first, then images, then headless Blender batches (at most 20 minutes a turn) when both queues
## are empty or at a voice turn boundary. The daemon lives in ~/.crooked-moon (the art and voice thread's folder); these copy the
## tools there and manage it. Blender batches are scripts dropped in ~/.crooked-moon/blender_queue/ (NN_name.py, oldest first).
##   make gpu-scheduler-install      copies blender_batch.sh to ~/.crooked-moon and the new scheduler beside the running one as gpu_scheduler.sh.new
##                                   (the running script is never overwritten: zsh reads a script as it runs)
##   make gpu-scheduler-restart      installs, then stops the running scheduler (by its PID, not a pattern), moves gpu_scheduler.sh.new into place
##                                   (the old one is kept as gpu_scheduler.sh.before_blender) and starts it in the mode the GPU is in
##   make gpu-scheduler-status       the mode, the queues and the Blender queue
##   make blender-queue              lists the waiting batches    make blender-run   runs the next one now (takes the GPU lock; use only when the GPU is free)
gpu-scheduler-install:
	@mkdir -p $(HOME)/.crooked-moon/blender_queue/done $(HOME)/.crooked-moon/blender_queue/failed
	@cp tools/gpu/gpu_scheduler.sh $(HOME)/.crooked-moon/gpu_scheduler.sh.new
	@cp tools/gpu/blender_batch.sh $(HOME)/.crooked-moon/blender_batch.sh
	@chmod +x $(HOME)/.crooked-moon/gpu_scheduler.sh.new $(HOME)/.crooked-moon/blender_batch.sh
	@echo "installed to $(HOME)/.crooked-moon"

gpu-scheduler-restart: gpu-scheduler-install
	@sh tools/gpu/restart.sh

gpu-scheduler-status:
	@tools/gpu/gpu_scheduler.sh --status

blender-queue:
	@tools/gpu/blender_batch.sh --list
	@echo "$$(tools/gpu/blender_batch.sh --pending) waiting"

blender-run:
	@tools/gpu/blender_batch.sh

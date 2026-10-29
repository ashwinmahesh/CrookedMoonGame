# The Crooked Moon

A single-player, turn-based tactical party RPG of the whole *Crooked Moon* campaign, levels 1 to 13 (and an optional endgame
to 20), built on the Dungeons and Dragons game engine in `addons/dnd_core`: four heroes you control, real-time exploration on the
same 5 ft grid the fights use, the 2024 rules with every number explained, voiced branching dialogue, and a world stuck in
Halloween, drawn like an 80s cartoon. Private repository; personal use. The campaign book is paid content and is never in
this repo.

The plan lives in Ashwin's vault (`Crooked Moon/Crooked Moon Game Plan.md`); the agent rules are in `CLAUDE.md`; what is still a
placeholder is in `docs/PLACEHOLDERS.md`.

## Getting started

```sh
git clone --recurse-submodules https://github.com/ashwinmahesh/CrookedMoonGame.git
cd CrookedMoonGame
git lfs pull && git -C addons/dnd_core lfs pull   # the art and the engine's kit
make hooks                                        # the push guard: only the build thread pushes main
make import                                       # the first import takes a while (it waits for a Godot slot)
make smoke                                        # headless boot
make check                                        # the quick check
```

`make run` plays the edge build, `make capture` draws pictures off screen, `make lane NAME=... BRANCH=... SSD=1` makes a lane on
the external SSD's disk image. Godot 4.7.2 on macOS.

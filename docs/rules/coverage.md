# Rules coverage matrix (2024 PHB) for the Crooked Moon

The engine's matrix, `addons/dnd_core/docs/reference/rules/coverage.md`, decides whether a 2024 rule is done. This one lists the
rules and systems this game adds from its own book, and what is left to build; a row moves to **tested** when its test exists.
Statuses: **tested** · **implemented** · **data** · **partial** · **deviated** (see deviations.md) · **not started**. Brackets say where
the rest lands: a plan phase, or an item of the plan's Engine and Systems Work note (E1, G2 ...). `make validate` fails on a row
still waiting on a phase that's built, and on a "not started" or "data" row naming something the data marks `implemented: engine`
(tools/data/check_rules_docs.py).

Tests live in `tests/unit/` and `tests/integration/`; names below are files.

## The book's own rules and the campaign's systems

| Rule | Code | Status | Test |
|---|---|---|---|
| The campaign's level cap, 13 then 20 [E1] | story/story_state.gd (the engine's) | not started | — |
| Eternal night: six named hours, no sun, the moon as light [E2] | story/story_state.gd, world/look | not started | — |
| Readings: one card per hero from a deck of any size [E22] | ui/dialogue (the engine's) | not started | — |
| A game's own features module for the book's options [E26] | combat/game_features.gd (the engine's), combat/crooked_features.gd and its parts in combat/crooked/ | tested | test_game_features (the engine's), test_crooked_features |
| The camera's pitch from campaign data, 30 degrees [E28] | world/exploration/camera_rig.gd (the engine's) | not started | — |
| Fateweaving and the Threads of Fate [G2] | — | not started | — |
| Dark Bargains with their cost shown first [E14, G4] | — | not started | — |
| Boss phases and masterless round effects [E4, E5] | — | not started | — |

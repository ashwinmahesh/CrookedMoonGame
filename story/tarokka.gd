class_name Tarokka
extends RefCounted
## A stub of the reading (docs/PLACEHOLDERS.md). The engine's dialogue screen (addons/dnd_core/ui/dialogue/dialogue_ui.gd) draws a
## face-up reading card through a class of this name in the game, so a game must have one even before it has a reading. This
## game's is the Fated Tarot (plan G1, engine item E22: one card per hero, a deck of any size, card art per campaign), which
## replaces this file; the engine lane should then ask the campaign module for a card so no game carries Curse of Strahd's name.

## The names of a reading's slots, by slot id. None until the Fated Tarot is written.
const SLOT_NAMES := {}


## A card's data (name, deck, suit, value, art), or {} for a card this game doesn't have.
static func card(_card_id: String) -> Dictionary:
	return {}

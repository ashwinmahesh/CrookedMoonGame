class_name TutorialSession
extends Node
## A stub of the game's tutorial (docs/PLACEHOLDERS.md). The engine's touch controls (addons/dnd_core/ui/common/mobile_controls.gd)
## name this class by type, so a game must have one even before it has a tutorial; Curse of Strahd's is a practice scene in its
## own world. This game has none yet, so nothing ever makes one: the title offers no tutorial, and these members are only what
## the engine reads of it. When a tutorial for the Crooked Moon is written (a practice scene on the new look), it replaces this
## file; the engine lane (W1) should make the touch controls ask by duck typing so no game has to carry the name.

## The practice ended: true when the campaign should start next.
signal finished(start_campaign: bool)

## The tutorial was offered at the start of a new campaign, so finishing it begins that campaign.
var pending_campaign := false
## The practice place the party stands in, for the camera controls (the same view type exploring uses).
var location: LocationView = null


## Leaves the practice and frees what it made. Nothing to free in the stub.
func leave_tutorial() -> void:
	pass

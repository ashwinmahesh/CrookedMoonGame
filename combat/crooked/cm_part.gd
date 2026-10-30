class_name CmPart
extends GameFeatures
## What the Crooked Moon's parts (combat/crooked/cm_*.gd) share: the prefix that routes hotbar actions, queued Reactions
## ("gm_" + the prefix) and sustained modes to the part, and small helpers the book's options use again and again.


## The part's prefix: its actions are "feat:gm:<prefix><id>".
func prefix() -> String:
	return ""


func owns(id: String) -> bool:
	var pre := prefix()
	return pre != "" and (id.begins_with(pre) or id.begins_with("gm_" + pre))


## A hotbar entry of this part (its id gets the prefix).
func _act(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return _entry(prefix() + id, label, sub, cost, why, targeting, help, rng)


## The save DC of a feature that uses 8 + Proficiency Bonus + an ability modifier.
static func dc_of(c: Combatant, ability: StringName) -> int:
	return 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(ability)


## `ch.refresh()` in a fight without losing what the fight and the day have spent: a refresh drops every resource the data
## doesn't define (once-per-rest counters a feature made with ClassFeatures._uses) and refills none, so those are put back
## as they were (a build pick changed mid-fight: a Harvest aspect, an Occult Presence).
static func refresh_keeping(ch: Character) -> void:
	var kept := {}
	for id: String in ch.resources:
		kept[id] = (ch.resources[id] as Dictionary).duplicate()
	ch.refresh()
	for id: String in kept:
		if not ch.resources.has(id):
			ch.resources[id] = kept[id]

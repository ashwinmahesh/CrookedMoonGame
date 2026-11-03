extends TestCase
## A spell leaves the caster's hand soon after the cast begins (Ashwin, 2026-11-03: "there is a delay between the action and the
## effect, reduce that delay"): the gather, the hold and the throw up to the clip's hit frame add up to no more than WINDUP_MAX real
## seconds at the game's animation speed, for the default cast and the heroes' (the manifest's `cast`), and a weapon swing's hit
## frame comes as soon.

const WINDUP_MAX := 0.45
const PACK_ENTER := 0.533   ## Spell_Simple_Enter's length in the pack rig (seconds at normal speed)


func _casts() -> Array[Dictionary]:
	var m := ArtPaths.json("art/figures/manifest.json")
	var out: Array[Dictionary] = []
	var d := ((m.get("defaults", {}) as Dictionary).get("clips", {}) as Dictionary).get("cast", {}) as Dictionary
	if not d.is_empty():
		out.append(d)
	for rig: Variant in (m.get("rigs", {}) as Dictionary).values():
		var c := ((rig as Dictionary).get("clips", {}) as Dictionary).get("cast", {}) as Dictionary
		if not c.is_empty():
			out.append(c)
	return out


func test_every_cast_leaves_the_hand_within_the_windup() -> void:
	var anim := float(Campaign.config().get("anim_speed", 1.0))
	var casts := _casts()
	assert_true(casts.size() >= 1, "there is a cast to check")
	for c: Dictionary in casts:
		var lead := c.get("lead", {}) as Dictionary if c.get("lead") is Dictionary else {}
		var lead_len := minf(float(lead.get("to", PACK_ENTER)), PACK_ENTER) if c.has("lead") else 0.0
		var hold := float((c.get("hold", {}) as Dictionary).get("seconds", 0.0)) if c.get("hold") is Dictionary else 0.0
		var throw := float(c.get("hit", 0.13)) / float(c.get("speed", 1.0))
		var total := (lead_len + throw) / anim + hold
		assert_true(total <= WINDUP_MAX, "a cast takes %.2f s to leave the hand (at most %.2f): %s" % [total, WINDUP_MAX, str(c)])

class_name SacrificeRitual
extends RefCounted
## The sacrifice ritual at the Crooked Tree (plan 5.7 and 13.11, G5; data/ritual/sacrifice.json). After the Born King
## falls, each hero offers something of value at the goat skull (an heirloom, two points of an ability, a class feature,
## their Thread, or their life) and rolls a d20 in the open, adding the offering's bonus. Kehlenn spends Ritual Points
## against the roll to pull it under the DC: her points are the ritual's base plus what the party's Sin gives her
## (story/sin.gd), and what she may spend on one roll is capped by the difficulty (Story 3, Balanced 5, Tactician and
## Honour all). A refused offering stays with its hero, who offers again; six refusals and the ritual fails (ending
## all_will_be_crooked). Heroic Inspiration rerolls a refused d20 once. The Last Act, a hero's life, is accepted without a
## roll. A hero who fell in the fight still offers, as a lingering spirit, but has no life left to give. When every hero's
## offering is accepted, Kehlenn is bound in the moon.
##
## Pure logic over the story: the ritual's scene (its conversation or screen) asks offerings(), then offer() or reroll()
## for each hero, and finish() at the end. What it keeps is the flag `_sacrifice`; what it ends with are the flags the
## endings read, under the finale chapters' names (kehlenn_bound, crooked_cause, last_act_count, party_size, ritual_fails,
## ritual_points) and its own (ritual_done, ritual_all_gave).

const DATA := "res://data/ritual/sacrifice.json"
const MEMORY := "_sacrifice"
const LIFE := "life"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {}
	return _data


static func clear_cache() -> void:
	_data = {}


## The key a hero is kept under in the ritual's memory: their id, or their name for a hero without one.
static func key_of(ch: Character) -> String:
	return ch.id if ch.id != "" else ch.name


static func offering(id: String) -> Dictionary:
	for o: Variant in data().get("offerings", []):
		if str((o as Dictionary).get("id", "")) == id:
			return o as Dictionary
	return {}


## The most Kehlenn may spend on one roll in this playthrough's difficulty.
static func cap(st: StoryState) -> int:
	var caps := data().get("caps", {}) as Dictionary
	return int(caps.get(str(st.options.get("difficulty", Difficulty.DEFAULT)), caps.get(Difficulty.DEFAULT, 5)))


## Kehlenn's Ritual Points as the ritual begins: the base and the party's Sin.
static func starting_points(st: StoryState) -> int:
	return int(data().get("base_points", 0)) + Sin.ritual_points(st)


## The ritual's state, or {} before it begins: {points, cap, refusals, heroes: {key: {name, accepted, offered: [...],
## last: result, life}}, over, outcome}.
static func state(st: StoryState) -> Dictionary:
	var m: Variant = st.flags.get(MEMORY, {})
	return m as Dictionary if m is Dictionary else {}


## Begins the ritual for everyone in the party, the fallen in it too (they offer as lingering spirits). A ritual already
## under way is left as it is.
static func begin(st: StoryState) -> Dictionary:
	if not state(st).is_empty():
		return state(st)
	var heroes := {}
	for ch: Character in st.party:
		heroes[key_of(ch)] = {"name": ch.name, "accepted": "", "offered": [], "last": {}, "spirit": ch.dead}
	var s := {"points": starting_points(st), "cap": cap(st), "refusals": 0, "heroes": heroes, "over": false, "outcome": ""}
	st.flags[MEMORY] = s
	return s


static func _hero(st: StoryState, ch: Character) -> Dictionary:
	return (state(st).get("heroes", {}) as Dictionary).get(key_of(ch), {}) as Dictionary


## Whether `ch` still has to make an offering that is accepted.
static func waiting(st: StoryState, ch: Character) -> bool:
	var h := _hero(st, ch)
	return not h.is_empty() and str(h.get("accepted", "")) == "" and not bool(state(st).get("over", false))


## What `ch` can offer now, each {id, name, bonus, summary, choices: [{id, name}]}: an heirloom (a magic item they're
## attuned to; the choices are those items), two points of an ability (one that is 3 or more), a class feature (the
## features of their classes), their Thread (when they have one and haven't given it), and their life (unless they
## already fell). An offering already refused can be made again with another choice; one taken can't be made twice.
static func offerings(st: StoryState, ch: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Variant in data().get("offerings", []):
		var off := (o as Dictionary).duplicate(true)
		var choices := _choices(st, ch, str(off["id"]))
		if choices.is_empty():
			continue
		off["choices"] = choices
		out.append(off)
	return out


static func _choices(st: StoryState, ch: Character, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tried := {}
	for t: Variant in _hero(st, ch).get("offered", []):
		tried["%s:%s" % [(t as Dictionary).get("kind", ""), (t as Dictionary).get("choice", "")]] = true
	match id:
		"heirloom":
			for item_id: String in ch.attuned:
				if not tried.has("heirloom:" + item_id) and ch.carries(item_id):
					var d := Compendium.shared().item_data(item_id) if Compendium.shared() != null else {}
					out.append({"id": item_id, "name": str(d.get("name", item_id))})
		"ability":
			for ab: String in ["str", "dex", "con", "int", "wis", "cha"]:
				if not tried.has("ability:" + ab) and ch.ability_score(StringName(ab)) >= 3:
					out.append({"id": ab, "name": ab.to_upper()})
		"feature":
			for f: Dictionary in ch.features:
				var fid := str(f.get("id", ""))
				if str(f.get("class_id", "")) != "" and fid != "" and not tried.has("feature:" + fid):
					out.append({"id": fid, "name": str(f.get("name", fid))})
		"thread":
			var thread := str(ch.build.get("thread", ""))
			if thread != "" and not tried.has("thread:" + thread):
				out.append({"id": thread, "name": thread.replace("_", " ").capitalize()})
		LIFE:
			if not ch.dead:
				out.append({"id": LIFE, "name": "Their life"})
	return out


## `ch` offers `kind` (an offering's id) with `choice` (one of its choices' ids). Rolls the d20 in the open, adds the
## offering's bonus, and lets Kehlenn spend what it takes to pull the total under the DC, if she has it and her cap allows.
## Returns {kind, choice, roll, bonus, spent, total, dc, accepted, refusals, can_reroll} ({} when `ch` can't offer that).
## An accepted offering is taken at once (the item, the points, the feature, the Thread); a life is given at finish().
static func offer(st: StoryState, ch: Character, kind: String, choice: String, dice: DiceRoller) -> Dictionary:
	if not waiting(st, ch):
		return {}
	var ok := false
	for c: Dictionary in _choices(st, ch, kind):
		if str(c["id"]) == choice:
			ok = true
	if not ok:
		return {}
	var s := state(st)
	var h := _hero(st, ch)
	var res := {"kind": kind, "choice": choice, "roll": 0, "bonus": 0, "spent": 0, "total": 0,
		"dc": int(data().get("dc", 11)), "accepted": false, "rerolled": false}
	if kind == LIFE:
		res["accepted"] = true
	else:
		res["bonus"] = int(offering(kind).get("bonus", 0))
		_roll(s, res, dice, ch)
	(h["offered"] as Array).append({"kind": kind, "choice": choice})
	_settle(st, ch, s, h, res)
	return res


## Heroic Inspiration: `ch`'s last offering was refused on its roll, so they spend their inspiration and roll it again
## (Kehlenn may spend again). The refusal is taken back if the new roll stands. Returns the new result, or {}.
static func reroll(st: StoryState, ch: Character, dice: DiceRoller) -> Dictionary:
	var s := state(st)
	var h := _hero(st, ch)
	var last := h.get("last", {}) as Dictionary
	if h.is_empty() or bool(s.get("over", false)) or not can_reroll(st, ch):
		return {}
	ch.heroic_inspiration = false
	var res := last.duplicate(true)
	res["rerolled"] = true
	res["spent"] = 0
	_roll(s, res, dice, ch)
	s["refusals"] = int(s["refusals"]) - 1   # the refused roll is replaced, and this one is counted as it falls
	_settle(st, ch, s, h, res)
	return res


## Whether `ch` may reroll their last offering now: it was refused on a roll, they haven't rerolled it, and they have
## Heroic Inspiration.
static func can_reroll(st: StoryState, ch: Character) -> bool:
	var last := _hero(st, ch).get("last", {}) as Dictionary
	return not last.is_empty() and not bool(last.get("accepted", true)) and not bool(last.get("rerolled", false)) \
		and ch.heroic_inspiration and not bool(state(st).get("over", false))


static func _roll(s: Dictionary, res: Dictionary, dice: DiceRoller, ch: Character) -> void:
	var d20 := dice.roll_one(20, "%s's offering at the Crooked Tree" % ch.name)
	var total := d20 + int(res["bonus"])
	var dc := int(res["dc"])
	var spent := 0
	# Kehlenn's spending: just enough to pull the total under the DC, when her cap and her points allow; else nothing.
	if total >= dc:
		var need := total - dc + 1
		if need <= mini(int(s["cap"]), int(s["points"])):
			spent = need
			s["points"] = int(s["points"]) - need
	res["roll"] = d20
	res["spent"] = spent
	res["total"] = total - spent
	res["accepted"] = total - spent >= dc


static func _settle(st: StoryState, ch: Character, s: Dictionary, h: Dictionary, res: Dictionary) -> void:
	if bool(res["accepted"]):
		h["accepted"] = str(res["kind"])
		h["choice"] = str(res["choice"])
		_take(ch, str(res["kind"]), str(res["choice"]))
	else:
		s["refusals"] = int(s["refusals"]) + 1
	res["refusals"] = int(s["refusals"])
	h["last"] = res.duplicate(true)
	res["can_reroll"] = not bool(res["accepted"]) and not bool(res.get("rerolled", false)) and ch.heroic_inspiration
	if int(s["refusals"]) >= int(data().get("max_refusals", 6)):
		s["over"] = true
		s["outcome"] = "failed"
	elif _all_accepted(s):
		s["over"] = true
		s["outcome"] = "bound"
	st.flags[MEMORY] = s


static func _all_accepted(s: Dictionary) -> bool:
	for k: Variant in (s.get("heroes", {}) as Dictionary):
		if str(((s["heroes"] as Dictionary)[k] as Dictionary).get("accepted", "")) == "":
			return false
	return true


## Takes what an accepted offering gives up: the heirloom from the pack, two points off the ability (kept in the build
## like a manual's, so its breakdown names the ritual), the class feature and the Thread marked given up in the build.
static func _take(ch: Character, kind: String, choice: String) -> void:
	match kind:
		"heirloom":
			ch.remove_one(choice)
		"ability":
			if not ch.build.has("item_boons"):
				ch.build["item_boons"] = []
			(ch.build["item_boons"] as Array).append({"ability": choice, "value": -2, "max_raise": 0,
				"source": "Offered at the Crooked Tree"})
			ch.refresh()
		"feature", "thread":
			var given := ch.build.get("given_up", []) as Array
			given.append({"kind": kind, "id": choice, "source": "Offered at the Crooked Tree"})
			ch.build["given_up"] = given


## `ch` won't offer anything: the ritual fails at once (ending all_will_be_crooked).
static func refuse(st: StoryState, ch: Character) -> void:
	var s := state(st)
	if s.is_empty() or bool(s.get("over", false)) or _hero(st, ch).is_empty():
		return
	s["over"] = true
	s["outcome"] = "unwilling"
	st.flags[MEMORY] = s


static func over(st: StoryState) -> bool:
	return bool(state(st).get("over", false))


## "bound" (every offering accepted), "failed" (too many refused), "unwilling" (a hero wouldn't offer), or "" while it
## goes on.
static func outcome(st: StoryState) -> String:
	return str(state(st).get("outcome", ""))


## Ends the ritual: those who gave their lives are lost for good, and the flags the endings read are set. When Kehlenn is
## bound, every hero who lives may raise one ability by 2 (grant_boon). Returns the outcome.
static func finish(st: StoryState) -> String:
	var s := state(st)
	if s.is_empty() or not bool(s.get("over", false)) or bool(st.get_flag("ritual_done", false)):
		return outcome(st)
	var heroes := s["heroes"] as Dictionary
	var lives := 0
	for ch: Character in st.party.duplicate():
		var h := heroes.get(key_of(ch), {}) as Dictionary
		if str(h.get("accepted", "")) == LIFE:
			lives += 1
			st.lose_member(ch, "gave their life at the Crooked Tree")
	st.set_flag("ritual_done")
	st.set_flag("party_size", heroes.size())
	st.set_flag("last_act_count", lives)
	st.set_flag("ritual_all_gave", lives > 0 and lives >= heroes.size())
	st.set_flag("ritual_fails", int(s.get("refusals", 0)))
	st.set_flag("ritual_points", int(s.get("points", 0)))
	match outcome(st):
		"bound":
			st.set_flag("kehlenn_bound")
		"failed":
			st.set_flag("crooked_cause", "ritual_failed")
		"unwilling":
			st.set_flag("crooked_cause", "refused")
	return outcome(st)


## The ritual's gift once Kehlenn is bound: `ch` (who lives) raises `ability` by 2, past 20 up to the campaign's limit
## (StoryBoons). Once per hero. Returns how much it rose.
static func grant_boon(st: StoryState, ch: Character, ability: String) -> int:
	if not bool(st.get_flag("kehlenn_bound", false)) or ch.dead:
		return 0
	var s := state(st)
	var h := _hero(st, ch)
	if h.is_empty() or bool(h.get("boon", false)):
		return 0
	h["boon"] = true
	st.flags[MEMORY] = s
	var boon := data().get("boon", {}) as Dictionary
	return StoryBoons.raise_ability(ch, ability, int(boon.get("amount", 2)), str(boon.get("source", "The ritual")))

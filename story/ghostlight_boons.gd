class_name GhostlightBoons
extends RefCounted
## What the Ghostlight Express gives the heroes besides items (package R10, audit note section C): Bless for an hour from Adela's Fated
## Tarot, and a heal of 1d6 for every hero each time a haint is freed (overflow becomes Temporary Hit Points). Both use what the engine
## already has (an Effect on the hero that runs out with the clock; Character.heal and add_temp_hp); only the moments are ours.

## The haints, by the id of their quest. A haint is freed by a token or by being talked round ("helped"); a bottled or destroyed one
## heals no one.
const HAINTS: Array[String] = ["haint_sweetheart", "haint_songstress", "haint_daydreamer", "haint_mariner", "haint_jailbird", "haint_harlequin"]
const FREED_STAGES: Array[String] = ["token", "helped"]
const PAID := "_haint_heal/"


# --- Bless from the reading ---------------------------------------------------------------------------------------

## The Bless of the Fated Tarot: the spell's own modifiers (1d4 on attack rolls and saving throws) for one hour of exploring and
## fighting time, on `ch` and not kept up by Concentration (the cards hold it). A second one replaces the first.
static func bless(ch: Character) -> void:
	if ch.dead:
		return
	var fx := Effect.new("Bless", &"spell", "bless")
	for f: Variant in Compendium.shared().spell_data("bless").get("effects", []):
		if str((f as Dictionary).get("effect", "")) != "modifiers":
			continue
		for md: Variant in ((f as Dictionary).get("params", {}) as Dictionary).get("modifiers", []):
			fx.modifiers.append(Modifier.make((md as Dictionary).duplicate(true), "Bless", &"spell", "bless"))
	fx.caster_id = ch.id
	fx.lasting({"kind": "hours", "amount": 1})
	for old: Effect in ch.effects.duplicate():
		if old.key() == fx.key():
			ch.remove_effect(old)
	ch.add_effect(fx)


## The hero at reading slot `slot` ("hero_1" ...) takes part in the reading: Bless for an hour, once per playthrough (a reading that
## was already finished blesses no one again).
static func bless_slot(slot: String, st: StoryState) -> void:
	if bool(st.get_flag("tarot_full_reading", false)):
		return
	var n := int(slot.trim_prefix("hero_")) - 1
	if n >= 0 and n < st.party.size():
		bless(st.party[n])


# --- A haint freed -------------------------------------------------------------------------------------------------

## Connects `st` so that a haint's quest ending in a freeing stage heals the party. `dice` rolls the 1d6 (story code names no autoload: the world passes Dice.roller). `said` (a Callable taking the text) is told what
## happened, for a toast. The world calls this when a game opens, and the playthrough test does the same.
static func watch(st: StoryState, dice: DiceRoller, said: Callable = Callable()) -> void:
	# The handler holds the story only weakly: a connection that captured `st` would keep the story alive through its own signal.
	st.quest_finished.connect(Callable(GhostlightBoons, "_quest_finished").bind(weakref(st), dice, said))


static func _quest_finished(quest_id: String, _ending: String, story: WeakRef, dice: DiceRoller, said: Callable) -> void:
	var st := story.get_ref() as StoryState
	if st == null:
		return
	var text := haint_freed(st, quest_id, dice)
	if text != "" and said.is_valid():
		said.call(text)


## If `quest_id` is a haint whose quest stands at a freeing stage and it hasn't healed yet, heals every hero who isn't dead by one
## 1d6 (rolled once for the haint), the part past their Hit Point maximum going to Temporary Hit Points. Returns what to tell the
## player, or "".
static func haint_freed(st: StoryState, quest_id: String, dice: DiceRoller) -> String:
	if not quest_id in HAINTS or not st.quest_stage(quest_id) in FREED_STAGES or st.flags.has(PAID + quest_id):
		return ""
	st.flags[PAID + quest_id] = true
	var amount := int(dice.roll_expr("1d6", "A freed haint heals the party")["total"])
	var temp := 0
	for ch in st.party:
		if ch.dead:
			continue
		var healed := ch.heal(amount, "a freed haint")
		if healed < amount and ch.add_temp_hp(amount - healed, "a freed haint"):
			temp += 1
	return "The freed haint heals each hero %d%s" % [amount, " (Temporary Hit Points for the rest)" if temp > 0 else ""]

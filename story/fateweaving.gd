class_name Fateweaving
extends RefCounted
## Fateweaving (plan 5.4, gap G2): each companion carries one Thread of Fate (data/threads/<thread>.json), a personal story of six
## beats. Each beat is a scene that sets `<beat>_<thread>` and closes a one-stage quest of the same name (data/quests): the
## Incitement on the train or in the Crooked House, the Connection with a villager in Wickermoor, then the Discovery after one Act II
## chapter and the Confrontation after one Act III chapter (both camp talks in narrative/camp/<hero>_thread.dialogue, so a benched
## companion's beat waits for them and none can be missed), the Climax at the Crooked Tree and the Catharsis in the epilogue.
##
## The rewards follow the book's ladder, given when the beat's quest ends (CampaignModule.quest_finished, story/crooked_moon_campaign.gd):
## Incitement, Heroic Inspiration (the scene's own `inspire`); Connection, Bless for a day; Discovery, a Twist of Fate;
## Confrontation, +2 to the Thread's ability (to the campaign's limit, 24); Climax, the Thread's feat; Catharsis, the end of their story.
## A Twist of Fate and a granted feat wait on the engine (twist-of-fate and StoryBoons.grant_feat, asked of the hooks lane): until
## they land, the hero's due is kept in flags (TWISTS, FEATS) so a later build can pay it.

const DIR := "res://data/threads/"
const BEATS: Array[String] = ["incitement", "connection", "discovery", "confrontation", "climax", "catharsis"]
## A day of game time, for the Connection's Bless.
const DAY_MINUTES := 1440
## Flags: a beat's reward paid (one each a playthrough); the Twists of Fate and feats owed to a hero until the engine can give them.
const PAID := "_thread_paid/"
const TWISTS := "_thread_twists/"
const FEATS := "_thread_feats/"

static var _threads: Dictionary = {}


# --- Reading ---------------------------------------------------------------------------------------------------------

## Every Thread, by id.
static func threads() -> Dictionary:
	if _threads.is_empty():
		var dir := DirAccess.open(DIR)
		if dir != null:
			for f in dir.get_files():
				if not f.ends_with(".json"):
					continue
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
				if d is Dictionary:
					_threads[str((d as Dictionary).get("id", f.get_basename()))] = d
	return _threads


static func thread(id: String) -> Dictionary:
	return threads().get(id, {}) as Dictionary


## The Thread a companion carries ("" for none).
static func thread_of(hero_id: String) -> String:
	for id: String in threads():
		if str((threads()[id] as Dictionary).get("hero", "")) == hero_id:
			return id
	return ""


## {thread, beat} for a beat's quest id (`discovery_pilgrimage`), or {} for any other quest.
static func beat_of_quest(quest_id: String) -> Dictionary:
	for beat in BEATS:
		if quest_id.begins_with(beat + "_"):
			var id := quest_id.trim_prefix(beat + "_")
			if threads().has(id):
				return {"thread": id, "beat": beat}
	return {}


static func beat_done(st: StoryState, thread_id: String, beat: String) -> bool:
	return bool(st.get_flag("%s_%s" % [beat, thread_id], false))


## The beats of a Thread that have played, in order.
static func beats_done(st: StoryState, thread_id: String) -> Array[String]:
	var out: Array[String] = []
	for beat in BEATS:
		if beat_done(st, thread_id, beat):
			out.append(beat)
	return out


## The next beat of a Thread still to play, or "" once the Catharsis has.
static func next_beat(st: StoryState, thread_id: String) -> String:
	for beat in BEATS:
		if not beat_done(st, thread_id, beat):
			return beat
	return ""


## The Thread's hero wherever they are: in the party, at camp, or on the bench. Null when they aren't in the company (or are dead).
static func hero(st: StoryState, thread_id: String) -> Character:
	var id := str(thread(thread_id).get("hero", ""))
	if id == "":
		return null
	var everyone: Array[Character] = []
	everyone.append_array(st.party)
	everyone.append_array(st.camp_company)
	everyone.append_array(st.bench)
	for ch in everyone:
		if not ch.dead and StoryState.member_matches(ch, "name:" + id):
			return ch
	return null


## Twists of Fate a hero is owed until the engine can hold them.
static func twists_owed(st: StoryState, hero_id: String) -> int:
	return int(st.get_flag(TWISTS + hero_id, 0))


## Feats a hero is owed until the engine can grant them.
static func feats_owed(st: StoryState, hero_id: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in st.get_flag(FEATS + hero_id, []) as Array:
		out.append(str(f))
	return out


# --- Rewards ---------------------------------------------------------------------------------------------------------

## A quest ended (CampaignModule.quest_finished). If it is a beat's quest and ended well, pays the beat's reward to the Thread's hero,
## once a playthrough. Returns what to tell the player ("" for nothing).
static func quest_finished(st: StoryState, quest_id: String, ending: String) -> String:
	var b := beat_of_quest(quest_id)
	if b.is_empty() or ending != "success" or st.flags.has(PAID + quest_id):
		return ""
	var thread_id := str(b["thread"])
	var beat := str(b["beat"])
	st.flags["%s_%s" % [beat, thread_id]] = true
	var ch := hero(st, thread_id)
	if ch == null:
		return ""
	st.flags[PAID + quest_id] = true
	var data := thread(thread_id)
	var first := ch.name.get_slice(" ", 0)
	match beat:
		"incitement":
			if not ch.heroic_inspiration:
				ch.heroic_inspiration = true
				return "%s gains Heroic Inspiration." % first
		"connection":
			if StoryBoons.spell_boon(ch, "bless", DAY_MINUTES):
				return "%s carries a blessing from Wickermoor (Bless) for a day." % first
		"discovery":
			st.flags[TWISTS + ch.id] = twists_owed(st, ch.id) + 1
			return "%s gains a Twist of Fate." % first
		"confrontation":
			var ability := str(data.get("confrontation_ability", ""))
			if ability == "":
				return ""
			var rose := StoryBoons.raise_ability(ch, ability, 2, "Thread of Fate: %s" % str(data.get("name", thread_id)))
			if rose > 0:
				return "%s's %s rises by %d." % [first, str(Creature.ABILITY_NAMES.get(StringName(ability), ability.to_upper())), rose]
			return "%s's %s is already as high as it can go." % [first, str(Creature.ABILITY_NAMES.get(StringName(ability), ability.to_upper()))]
		"climax":
			var feat := str(data.get("climax_feat", ""))
			if feat != "":
				var owed := feats_owed(st, ch.id)
				owed.append(feat)
				st.flags[FEATS + ch.id] = owed
				return "%s gains the %s feat." % [first, Compendium.shared().display_name("feats", feat)]
		"catharsis":
			return "%s's Thread of Fate is complete." % first
	return ""

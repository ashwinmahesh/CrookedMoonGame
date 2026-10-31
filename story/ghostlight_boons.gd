class_name GhostlightBoons
extends RefCounted
## What the Ghostlight Express gives the heroes besides items (package R10, audit note section C): Bless for an hour from Adela's Fated
## Tarot, and a heal of 1d6 for every hero each time a haint is freed (overflow becomes Temporary Hit Points). The engine tells the
## campaign module when each moment comes (CampaignModule.reading_finished and quest_finished: story/crooked_moon_campaign.gd), and
## StoryBoons.spell_boon and Character.heal and add_temp_hp do the giving; only the moments and the amounts are ours.

## The haints, by the id of their quest. A haint is freed by a token or by being talked round ("helped"); a bottled or destroyed one
## heals no one.
const HAINTS: Array[String] = ["haint_sweetheart", "haint_songstress", "haint_daydreamer", "haint_mariner", "haint_jailbird", "haint_harlequin"]
const FREED_STAGES: Array[String] = ["token", "helped"]
const PAID := "_haint_heal/"


# --- Bless from the reading ---------------------------------------------------------------------------------------

## The reading is finished (CampaignModule.reading_finished, called once the last card is turned): every hero who isn't dead takes part
## and gains Bless for an hour, once per playthrough (a reading that was already finished blesses no one again). The bonus is the
## spell's own (1d4 on attack rolls and saving throws), given by the story (StoryBoons.spell_boon): no Concentration and no slot.
static func bless_party(st: StoryState) -> void:
	if bool(st.get_flag("tarot_full_reading", false)):
		return
	for ch in st.party:
		StoryBoons.spell_boon(ch, "bless", 60)


# --- A haint freed -------------------------------------------------------------------------------------------------

## A quest has ended (CampaignModule.quest_finished): if `quest_id` is a haint whose quest stands at a freeing stage and it hasn't
## healed yet, heals every hero who isn't dead by one 1d6 (rolled once for the haint, on `dice`, which the story seeds from the
## playthrough), the part past their Hit Point maximum going to Temporary Hit Points. Returns what to tell the player (the journal's
## notice carries it), or "".
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
	return ("The freed haint heals each hero %d%s" % [amount, " (Temporary Hit Points for the rest)" if temp > 0 else ""]) + "."

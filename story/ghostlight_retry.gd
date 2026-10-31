class_name GhostlightRetry
extends RefCounted
## A wipe at the Ghostlight Locomotive is a plain game over with an immediate retry from the clearing's edge (package R10 sections 3
## and 10, the Narrator's `defeat:ghostlight_locomotive`). The world asks `applies` when a fight is lost; if it does, the party is put
## back on its feet (`restore`) and the walk-away fight begins afresh, with the Vagrant's line over it.

## The fights it covers: the boss fight and the same fight begun from the clearing's rim.
const FIGHTS: Array[String] = ["gl_locomotive", "gl_locomotive_edge"]
## The fight the retry begins: the heroes at the rim of the clearing and the engine 30 ft off.
const RETRY_FIGHT := "gl_locomotive_edge"
const NARRATOR_KEY := "defeat:ghostlight_locomotive"
## How many times the party has been sent back, for the record.
const COUNT_FLAG := "gl_locomotive_retries"


## Whether a lost fight (the encounter's data) is one that retries.
static func applies(spec: Dictionary) -> bool:
	return str(spec.get("id", "")) in FIGHTS


## Puts the party back as they were for the boss fight: the fallen alive, everyone at full Hit Points with their powers back (as after
## a Long Rest), no hold or effect of the fight left on them. Bless from the reading and other lasting effects stay.
static func restore(st: StoryState) -> void:
	for ch in st.party:
		if ch.dead:
			Services.bring_back(st, ch, true, false, "the retry")
		ch.finish_long_rest()
		EncounterSetup.clear_fight_effects(ch)
	st.set_flag(COUNT_FLAG, int(st.get_flag(COUNT_FLAG, 0)) + 1)

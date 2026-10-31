class_name GhostlightRetry
extends RefCounted
## The Ghostlight Locomotive's entry in the retry table (data/fight_retries.json, story/fight_retry.gd): a wipe at the boss is a plain
## game over with an immediate retry from the clearing's edge (package R10 sections 3 and 10, the Narrator's
## `defeat:ghostlight_locomotive`). These are the names the Locomotive's tests and the table share.

## The fights it covers: the boss fight and the same fight begun from the clearing's rim.
const FIGHTS: Array[String] = ["gl_locomotive", "gl_locomotive_edge"]
## The fight the retry begins: the heroes at the rim of the clearing and the engine 30 ft off.
const RETRY_FIGHT := "gl_locomotive_edge"
const NARRATOR_KEY := "defeat:ghostlight_locomotive"
## How many times the party has been sent back, for the record.
const COUNT_FLAG := "gl_locomotive_retries"


## Whether a lost fight (the encounter's data) is one of the Locomotive's.
static func applies(spec: Dictionary) -> bool:
	return str(spec.get("id", "")) in FIGHTS

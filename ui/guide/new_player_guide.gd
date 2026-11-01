class_name NewPlayerGuide
extends RefCounted
## The new-player guide (vault Build/New Player Guide.md): coaching cards that ride along in the real game, never a
## practice world. They explain the hero creator's steps as the player reaches each one (CreatorGuide) and walk the
## first fight of a new game turn by turn (FightGuide), pointing at the real controls with the engine's TutorialCoach.
## Nothing is blocked: the cards sit beside the game while the player plays it. It's on for a player until they turn
## it off (the New game page's switch, or "Turn the guide off" on any card), and each part shows once.

## The player's switch (on until turned off), and what they've already been shown, kept in the game's settings.
const SETTING := "new_player_guide"
const SEEN_CREATOR := "new_player_guide_seen_creator"
## A new game's own copy of the switch (StoryState.options), and its flag once the first fight's guide has run.
const OPTION := "guide"
const FIGHT_DONE := "guide_first_fight_done"


## False: what the guide remembers lasts this run only (tests, captures), never the player's settings file.
static var keep := true


static func enabled() -> bool:
	return bool(GameSettings.value(SETTING, true))


static func set_enabled(on: bool) -> void:
	GameSettings.set_value(SETTING, on, keep)


static func creator_seen() -> bool:
	return bool(GameSettings.value(SEEN_CREATOR, false))


static func set_creator_seen() -> void:
	GameSettings.set_value(SEEN_CREATOR, true, keep)


## A coach for the guide: the engine's tutorial card, its menu worded for a guide in the real game.
static func coach() -> TutorialCoach:
	var c := TutorialCoach.new()
	c.ready.connect(func() -> void:
		c.menu_button.text = "Guide menu"
		c.retry_button.text = "Show this card again"
		c.skip_button.text = "Skip this card"
		c.exit_button.text = "Turn the guide off"
		(c.get("_return_button") as Button).text = "Back to the game"
		(c.get("_hint") as Label).text = "The guide menu can skip a card or turn the guide off.")
	return c


## A lesson card that never blocks the game: the player can use anything while it's up.
static func card(title: String, body: String, objective: String, details: String = "", read_only := false) -> Dictionary:
	var out := {"title": title, "body": body, "objective": objective, "details": details, "free_practice": true, "progress": "GUIDE"}
	if read_only:
		out["read_only"] = true
	return out

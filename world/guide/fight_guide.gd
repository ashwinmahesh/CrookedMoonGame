class_name FightGuide
extends Node
## The new-player guide in a new game's first fight (NewPlayerGuide): cards that walk the player's first turns in the
## real fight, each pointing at the control it's about (CombatHud.coach_anchor), each done by what the player actually
## does (the view's events_presented): who acts when, moving, attacking, the action shapes, ending the turn. The fight
## plays on as usual; nothing is blocked or changed. The game root adds it to a new game with the guide on; it waits
## for the first fight, runs once (the story's FIGHT_DONE flag) and goes.

## The cards, in order: what each is about, the HUD control it points at, and (for one the player acts on) what the card
## says once they have.
const CARDS: Array[Dictionary] = [
	{"id": "order", "anchor": "turn_order", "read_only": true, "title": "A fight, turn by turn",
		"body": "A fight goes in turns. The portraits along the top are the order everyone acts in, rolled when the fight began (Initiative). The lit one is acting now. When it's one of your heroes, you choose what they do.",
		"objective": "Find your hero in the order, then carry on.",
		"details": "You control every hero in your party. Foes take their turns on their own, and you watch them play out."},
	{"id": "move", "anchor": "movement", "title": "Move",
		"body": "On your turn a hero can move up to their speed (30 feet for most; one square is 5 feet). The bar shows how far they can still go. Moving doesn't use up their action.",
		"objective": "Click a square to move your hero there.",
		"details": "Moving away from a foe that's next to you can let it strike you as you go (an opportunity attack). The square you point at shows the path first.",
		"done": "Moved. Whatever movement is left stays for this turn."},
	{"id": "attack", "anchor": "action", "title": "Attack",
		"body": "Each turn a hero has one Action: attacking is the usual one. Pick an attack on the bar, then the foe. The game rolls a d20 and adds the hero's bonus; if that meets the foe's Armor Class, it hits and rolls damage.",
		"objective": "Pick an attack, then click a foe in reach.",
		"details": "A miss isn't a mistake: even good heroes miss often. Spells are on their own tab of the bar.",
		"done": "That was your Action. The log at the side shows the roll."},
	{"id": "shapes", "anchor": "economy", "read_only": true, "title": "Action, Bonus Action, Reaction",
		"body": "The shapes show what a hero has left this turn: an Action, a Bonus Action and a Reaction. They come back at the start of the hero's next turn.",
		"objective": "Look over the shapes, then carry on.",
		"details": "Only some powers use the Bonus Action, like a quick heal or an off-hand strike. A Reaction answers something on someone else's turn, like striking a foe that walks away from you. Rest the pointer on anything on the bar to read what it does and what it costs."},
	{"id": "end", "anchor": "end_turn", "title": "End the turn",
		"body": "When your hero is done, end the turn. The next in the order acts: another of your heroes, or a foe.",
		"objective": "Press End turn.",
		"details": "Any movement or Action left unused is lost when the turn ends, so use them first if you can.",
		"done": "That's a whole turn. Keep going the same way: move, act, end the turn."},
	{"id": "log", "anchor": "log", "read_only": true, "title": "If you're unsure",
		"body": "The log shows every roll and what it added up to. Resting the pointer on a number or a gold word explains it, and the hero's sheet (their portrait) has everything they can do. That's the basics: good luck!",
		"objective": "That's the basics. Win the fight!",
		"details": "The guide won't show again in this game. You can turn it off for new games on the New game page."},
]

var view: CombatView
var coach: TutorialCoach
var at := -1
var _found := 0.0
var _party_turns := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if view == null or not is_instance_valid(view):
		if view != null:
			_finish()   # the fight ended while a card was up
			return
		_found -= delta
		if _found <= 0.0:
			_found = 0.5
			_find_fight()
		return
	if coach == null or at < 0:
		return
	var anchor := str(CARDS[at]["anchor"])
	coach.set_highlight(view.hud.coach_anchor(anchor, _attack_id() if anchor == "action" else "") if view.hud != null and _party_turn() else Rect2())


## The first fight: the CombatView in the game, once it has begun.
func _find_fight() -> void:
	var found := get_tree().root.find_children("*", "CombatView", true, false)
	if found.is_empty():
		return
	view = found[0] as CombatView
	view.events_presented.connect(_presented)
	coach = NewPlayerGuide.coach()
	add_child(coach)
	coach.next_requested.connect(_next)
	coach.skip_requested.connect(_next)
	coach.retry_requested.connect(func() -> void: _present(at))
	coach.exit_requested.connect(_turn_off)


func _party_turn() -> bool:
	return view != null and view.e != null and view.e.current() != null and view.e.current().is_player_controlled()


## What the fight showed: the first party turn brings the first card; moves, attacks and turns end the others.
func _presented(events: Array[Dictionary]) -> void:
	for ev in events:
		var kind := str(ev.get("type", ""))
		if kind == "over":
			_finish()
			return
		if kind == "turn":
			if _ours(str(ev.get("id", ""))):
				_party_turns += 1
				if at < 0:
					_present(0)
				elif _id() == "end" and _party_turns > 1:
					_done()
		elif kind == "move" and _id() == "move" and _ours(str(ev.get("id", ""))) and not bool(ev.get("forced", false)) and not bool(ev.get("undo", false)):
			_done()
		elif kind in ["attack", "spell"] and _id() == "attack" and _ours(str(ev.get("attacker", ev.get("caster", "")))):
			_done()


## The acting hero's first attack on the bar (a weapon's "attack:<id>"), for the Attack card to point at; "" if none.
func _attack_id() -> String:
	for action: Dictionary in view.hud.get("_slot_actions") as Array[Dictionary]:
		for one: Variant in [action] + (action.get("items", []) as Array):
			var id := str((one as Dictionary).get("id", ""))
			if id.begins_with("attack:"):
				return id
	return ""


func _ours(id: String) -> bool:
	for c in view.e.combatants:
		if c.id == id:
			return c.is_player_controlled()
	return false


func _id() -> String:
	return str(CARDS[at]["id"]) if at >= 0 and at < CARDS.size() else ""


func _present(i: int) -> void:
	at = i
	var c := CARDS[i]
	coach.present(NewPlayerGuide.card(str(c["title"]), str(c["body"]), str(c["objective"]), str(c["details"]), bool(c.get("read_only", false))), i, CARDS.size())
	if bool(c.get("read_only", false)):
		_done()


func _done() -> void:
	if coach != null and not coach.complete:
		coach.set_complete("" if bool(CARDS[at].get("read_only", false)) else str(CARDS[at]["done"]))


## Continue: the next card; after the last, the guide is over for this game.
func _next() -> void:
	if at + 1 >= CARDS.size():
		_finish()
		return
	_present(at + 1)


## Turn the guide off: for new games too, and this game's fight is left to the player.
func _turn_off() -> void:
	NewPlayerGuide.set_enabled(false)
	_finish()


func _finish() -> void:
	GameState.story.set_flag(NewPlayerGuide.FIGHT_DONE)
	queue_free()

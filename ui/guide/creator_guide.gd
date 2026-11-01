class_name CreatorGuide
extends Node
## The new-player guide in the hero creator (NewPlayerGuide): a card for each step as the player reaches it, saying what
## the step decides in plain words, with the step's choices outlined. It never blocks the creator: its "Next step"
## moves on whenever the player likes, and once the step has nothing left to pick (CharacterBuilder.step_status) the
## card says so. Added to the CreationScreen by the title's "Create your own hero"; it shows once for a player.

## One card per step, in CharacterBuilder.Step order.
const CARDS: Array[Dictionary] = [
	{"title": "Your class", "body": "A class is what your hero does best: a Fighter takes the blows, a Wizard bends the world with spells, a Rogue strikes from the shadows. It sets your hit points, your weapons and your powers as you level up.",
		"objective": "Pick a class. Rest the pointer on one to read more.",
		"details": "Not sure? Fighter and Barbarian are the simplest to play; Cleric and Druid heal; Wizard, Sorcerer and Warlock are spellcasters. You can make a different hero later.",
		"done": "That's your hero's class."},
	{"title": "Where you come from", "body": "Your species is your people and your body: some are small, some see in the dark, some shrug off poison. Your background is the life you led before the adventure, and it gives you skills and a starting talent.",
		"objective": "Pick a species and a background, and any choices they ask for.",
		"details": "Gold names in the text can be rested on for the rule they stand for. A background also raises your ability scores a little: the Origin step says which.",
		"done": "Your hero's people and past are set."},
	{"title": "Ability scores", "body": "Six numbers say how strong, quick, hardy, clever, wise and charming your hero is. Most rolls in the game add one of them. The suggested spread already suits your class.",
		"objective": "Keep the suggested scores or arrange your own.",
		"details": "A score of 10 is ordinary; each 2 points above it adds +1 to rolls with that ability. Your class's main ability should be your highest.",
		"done": "Scores set."},
	{"title": "Class choices", "body": "Your class offers a few picks of its own: skills you're trained in, spells you know, a fighting style. Each choice says what it does.",
		"objective": "Make each pick the step asks for.",
		"details": "Skills you're trained in add your proficiency bonus to those checks. Spells can be changed later outside a fight.",
		"done": "Class choices made."},
	{"title": "Equipment", "body": "Pick the kit your hero starts with: a bundle of weapons and armour, or gold to buy your own. The list below shows how hard your attacks hit and how hard you are to hit (Armor Class).",
		"objective": "Choose an option for your class and for your background.",
		"details": "Armor Class (AC) is the number an enemy's attack roll must reach to hit you. Higher is safer.",
		"done": "Kit packed."},
	{"title": "How you look", "body": "Choose your hero's body, build and height. The figure turns so you can see it from every side; the buttons under it show it walking, running and swinging.",
		"objective": "Make your hero look the way you like.",
		"details": "Drag the figure to turn it yourself. Portrait and voice are on their own tab.",
		"done": "Looking the part."},
	{"title": "Who you are", "body": "Give your hero a name, and if you like, a few words on who they are. The story calls you by this name.",
		"objective": "Type a name.",
		"details": "",
		"done": "Named."},
	{"title": "Review", "body": "Here is your hero, all together. Anything that still needs a pick is listed in red; warnings in gold never stop you.",
		"objective": "Check your hero, then confirm.",
		"details": "You can step back to any earlier step from the list on the left without losing the rest.",
		"done": "Your hero is ready."},
]

var screen: CreationScreen
var coach: TutorialCoach
var _shown := -1


static func attach(to: CreationScreen) -> CreatorGuide:
	var g := CreatorGuide.new()
	g.screen = to
	to.add_child(g)
	return g


func _ready() -> void:
	coach = NewPlayerGuide.coach()
	add_child(coach)
	coach.skip_requested.connect(_next)
	coach.retry_requested.connect(func() -> void: _present(_shown))
	coach.exit_requested.connect(func() -> void:
		NewPlayerGuide.set_enabled(false)
		queue_free())
	NewPlayerGuide.set_creator_seen()


func _process(_delta: float) -> void:
	if screen == null or screen.builders.is_empty():
		return
	var at := clampi(screen.step, 0, CARDS.size() - 1)
	if at != _shown:
		_present(at)
	var done := bool(screen.b().step_status(at as CharacterBuilder.Step).get("complete", false))
	coach.set_step_hint("done" if done else "open", "%s %s" % [str(CARDS[at]["done"]), "Confirm when you're ready." if at == CARDS.size() - 1
		else "On to the next step when you're ready."] if done else str(CARDS[at]["objective"]))
	var body := screen.get("_body") as Control
	coach.set_highlight(body.get_global_rect() if body != null and body.is_visible_in_tree() else Rect2())


func _present(at: int) -> void:
	_shown = at
	var c := CARDS[at]
	var card := NewPlayerGuide.card(str(c["title"]), str(c["body"]), str(c["objective"]), str(c["details"]))
	card["corner"] = "bottom_right"   # clear of the steps, the choices and the creator's own Next
	coach.present(card, at, CARDS.size())
	coach.set_action("Close the guide" if at == CARDS.size() - 1 else "Next step", _next)


## Next step: the creator moves on as its own Next does; the last card closes the guide.
func _next() -> void:
	if _shown >= CARDS.size() - 1:
		queue_free()
		return
	screen.step = _shown + 1
	screen._draw()

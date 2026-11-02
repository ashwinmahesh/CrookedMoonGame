extends TestCase
## Mori Shade brings back a hero who has truly died (Ashwin, 2026-11-02): the engine's raise_dead service on her NPC data
## (data/npcs/mori_shade.json), priced exactly 1000 gp for each hero brought back (`fixed_price`: the seller's goodwill does not move it), with no
## diamond, from 07:00 to 23:00. Played here: the price is the same at every level, a hero who died is paid for and comes back with the engine's
## aftereffects, a purse that falls short is refused and the offer stays, the hours, the ten-day limit, and each of her conversations that
## reaches the service (her usual one, the first with the brass plates, Act III's hub). Nothing here fights.

const MORI := "mori_shade"


class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState


func before_each() -> void:
	GameState.reset()
	st = GameState.story


func after_each() -> void:
	GameState.reset()


## A party of four at `level`, the clock at `hour`, a purse of `gold`.
func _party(level: int, hour: int = 12, gold: float = 1000.0) -> void:
	GameState.reset()
	st = GameState.story
	for id: String in ["rook_coldwake", "tobin_hayward", "lucan_houndstooth", "silas_vane"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = hour * 60
	st.gold = gold


## The raise line Mori offers now, or {}.
func _line() -> Dictionary:
	for l: Dictionary in Services.offered(st, MORI):
		if str(l["id"]) == "raise_dead":
			return l
	return {}


func _fall(ch: Character) -> void:
	ch.dead = true
	ch.hp = 0


## Plays `ref` and returns the blocks it comes to, taking at each menu the first option holding the next of `picks`, until it ends or comes to
## the services screen (the block {kind: "services"}).
func _run(ref: String, picks: Array[String] = []) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, HighDice.new())
	r.npc_id = MORI
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var seen: Array[Dictionary] = []
	var b := r.next()
	for i in 200:
		seen.append(b)
		match str(b["kind"]):
			"end", "services":
				return seen
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					if pick < 0:
						fail("%s: no option '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
						return seen
				b = r.choose(pick)
			_:
				b = r.next()
	fail("%s never ended" % ref)
	return seen


func _kinds(blocks: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in blocks:
		out.append(str(b["kind"]))
	return out


func _spoken(blocks: Array[Dictionary]) -> String:
	var out := ""
	for b: Dictionary in blocks:
		out += " " + str(b.get("text", ""))
	return out


func test_the_toll_is_exactly_a_thousand_gold_whatever_her_goodwill_and_no_diamond() -> void:
	# The campaign stops a hero at level 13 until Moonfall begins (the cap is a campaign setting), so the party is built up to there.
	for level in range(1, 14):
		_party(level)
		var line := _line()
		assert_true(not line.is_empty(), "level %d: Mori offers it" % level)
		assert_eq(Services.offered(st, MORI).filter(func(l: Dictionary) -> bool: return str(l["id"]) == "raise_dead").size(), 1, "level %d: one line, not several" % level)
		assert_eq(float(line["price"]), 1000.0, "level %d: 1000 gp, whatever the level" % level)
		assert_eq(float(line["material"]), 0.0, "level %d: no diamond" % level)
		assert_eq(Services.cost(line), float(line["price"]), "level %d: the price is the whole cost" % level)
	var lines := Compendium.shared().get_entry("npcs", MORI)["services"] as Array
	assert_eq(lines.size(), 1, "one entry, the same for every level")
	assert_eq(float((lines[0] as Dictionary)["price"]), 1000.0, "1000 gp")
	assert_false(str((lines[0] as Dictionary)["if"]).contains("level"), "and no level in its condition")
	_party(3)
	assert_eq(float(_line()["price"]), 1000.0, "1000 gp, with no tenth off from her goodwill")
	assert_true(bool((lines[0] as Dictionary).get("fixed_price", false)), "her entry fixes the price")
	assert_true(str(_line()["text"]).contains("Ferryman") and not str(_line()["text"]).contains("diamond"), "the screen's words are hers")


func test_a_hero_who_died_is_paid_for_and_comes_back_with_the_ordeal() -> void:
	_party(3, 12, 2000.0)
	var tobin := st.party[1]
	_fall(tobin)
	var line := _line()
	var price := float(line["price"])
	assert_eq(Services.why_not(st, line, tobin), "", "the screen lets it be bought for the fallen")
	assert_eq(Services.why_not(st, line, st.party[0]), "Rook is alive", "and not for the living")
	var said := Services.buy(st, MORI, line, tobin, HighDice.new())
	assert_true(said != "", "it is done")
	assert_false(tobin.dead, "back among the living")
	assert_eq(tobin.hp, 1, "with 1 Hit Point")
	assert_eq(st.gold, 2000.0 - price, "the toll was taken and nothing else")
	var ordeal := tobin.effects.filter(func(fx: Effect) -> bool: return fx.source_id == "raise_dead")
	assert_eq(ordeal.size(), 1, "the ordeal is on them")
	assert_eq(int((ordeal[0] as Effect).minutes_left), Services.ORDEAL - 60, "for ten days, from the start of the hour the rite takes")


func test_a_purse_that_falls_short_is_refused_and_the_offer_stands() -> void:
	_party(3, 12, 100.0)
	var lucan := st.party[2]
	_fall(lucan)
	var line := _line()
	assert_eq(Services.why_not(st, line, lucan), "Not enough gold", "refused plainly")
	assert_eq(Services.buy(st, MORI, line, lucan, HighDice.new()), "", "nothing is done")
	assert_true(lucan.dead and st.gold == 100.0, "still dead, nothing taken")
	assert_false(_line().is_empty(), "and the offer is still there")
	st.gold = float(line["price"])
	assert_eq(Services.why_not(st, _line(), lucan), "", "it can be bought the moment the purse is enough")
	assert_true(Services.buy(st, MORI, _line(), lucan, HighDice.new()) != "")
	assert_false(lucan.dead)
	assert_eq(st.gold, 0.0)


func test_the_price_does_not_follow_the_level_the_party_reaches() -> void:
	_party(3)
	var three := float(_line()["price"])
	_party(4)
	assert_eq(float(_line()["price"]), three, "a level more costs the same")
	# The lowest hero no longer sets anything: a level 4 party with one level 3 hero pays the same toll.
	_party(4)
	st.party[3] = Pregens.build("silas_vane", 3)
	assert_eq(float(_line()["price"]), three, "the same for every party")


func test_the_door_is_shut_from_the_midnight_hour_to_the_twilight_hour() -> void:
	for hour: int in [23, 0, 3, 6]:
		_party(3, hour)
		assert_true(_line().is_empty(), "%02d:00: nothing is offered" % hour)
		assert_eq(Services.closed_text(MORI), "Mori gives the Midnight and Witching hours to the graves. Come back from the Twilight Hour until the Evening Hour is spent.")
	for hour: int in [7, 12, 19, 22]:
		_party(3, hour)
		assert_false(_line().is_empty(), "%02d:00: the door is open" % hour)
	_party(3, 22)
	st.minute_of_day = 22 * 60 + 59
	assert_false(_line().is_empty(), "open until 23:00")
	st.minute_of_day = 23 * 60
	assert_true(_line().is_empty(), "and shut at 23:00")


func test_a_hero_dead_more_than_ten_days_is_beyond_her() -> void:
	_party(3)
	var silas := st.party[3]
	_fall(silas)
	st.flags["_died/" + silas.id] = st.total_minutes() - Services.RAISE_LIMIT - 1
	assert_eq(Services.why_not(st, _line(), silas), "Silas has been dead more than 10 days")
	st.flags["_died/" + silas.id] = st.total_minutes() - Services.RAISE_LIMIT + 60
	assert_eq(Services.why_not(st, _line(), silas), "", "inside the ten days it can be done")


func test_her_usual_conversation_asks_the_ferryman_and_opens_the_services() -> void:
	_party(3, 12)
	var blocks := _run("wickermoor/mori_shade:start", ["called back"])
	assert_eq(_kinds(blocks).back(), "services", "the services screen is opened")
	var talk := _spoken(blocks)
	assert_true(talk.contains("turn his oar") and talk.contains("a thousand gold pieces") and talk.contains("ten days"), "she states the terms first")


func test_asked_outside_her_hours_she_says_when_to_come_back_and_the_menu_stays() -> void:
	_party(3, 2)
	var blocks := _run("wickermoor/mori_shade:start", ["called back", "Take our leave"])
	assert_eq(_kinds(blocks).back(), "end", "no services screen at the Witching Hour")
	assert_true(_spoken(blocks).contains("Midnight and Witching hours I give to the graves"), "she gives the hours")
	assert_true(_spoken(blocks).contains("The ten days will keep"))


func test_each_way_into_her_company_offers_it() -> void:
	_party(3, 12)
	st.set_flag("wm_welcomed")
	for ref: String in ["wickermoor/mori:start", "maidenmist/mori:hub"]:
		var blocks := _run(ref, ["called back"])
		assert_eq(_kinds(blocks).back(), "services", "%s reaches the services screen" % ref)


func test_after_the_screen_she_leaves_the_offer_standing() -> void:
	_party(3, 12)
	var blocks := _run("wickermoor/mori_shade:raising_after", ["Take our leave"])
	assert_eq(_kinds(blocks).back(), "end")
	assert_true(_spoken(blocks).contains("the offer stands for the full ten days"))

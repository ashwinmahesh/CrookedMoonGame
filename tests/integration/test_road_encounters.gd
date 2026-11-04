extends TestCase
## The roads push back (fun pass, lane D): every road on the Wickermoor Hollow map that leads somewhere a chapter is played
## has its random encounter table (data/random_encounters/), every fight in them can be set up on each of its table's battle
## grounds (the foes on open ground, clear of the party), and the Crooked Man's road table and fireside visits are where
## Travel.roll and NightEvents find them. A fight's working is checked by starting it; how a party fares is never measured.

const NO_TABLE := ["wickermoor_to_nm_estate", "wickermoor_to_nm_estate_ruins"]   ## an hour up the hill, into the chapter itself


func _tables() -> Dictionary:
	return Compendium.shared().table("random_encounters")


func test_every_road_has_a_table() -> void:
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	for r: Variant in t["roads"]:
		var road := r as Dictionary
		if str(road["id"]) in NO_TABLE:
			continue
		var tid := str(road.get("table", ""))
		assert_ne(tid, "", "the road %s has a table" % road["id"])
		assert_false(Compendium.shared().get_entry("random_encounters", tid).is_empty(), "%s's table %s exists" % [road["id"], tid])


func test_every_fight_sets_up_on_every_ground() -> void:
	var c := Compendium.shared()
	for tid: Variant in _tables():
		var table := _tables()[tid] as Dictionary
		var grounds := table.get("grounds", [table["map"]]) as Array
		for e: Variant in table["entries"]:
			var entry := e as Dictionary
			if not entry.has("monsters"):
				continue
			for m: Variant in entry["monsters"]:
				assert_false(c.monster_data(str((m as Dictionary)["monster"])).is_empty(), "%s:%s's %s exists" % [tid, entry["id"], (m as Dictionary)["monster"]])
			for g: Variant in grounds:
				var loc := c.get_entry("locations", str(g))
				var rows := (loc["map"] as Dictionary)["rows"] as Array
				var spawn := loc["spawns"]["default"] as Array
				var foes := RoadGrounds.placed(entry["monsters"] as Array, str(table["map"]), str(g))
				assert_eq(foes.size(), (entry["monsters"] as Array).size(), "%s:%s keeps every foe on %s" % [tid, entry["id"], g])
				for f: Variant in foes:
					var cell := (f as Dictionary).get("cell", []) as Array
					assert_eq(cell.size(), 2, "%s:%s's %s has a square on %s" % [tid, entry["id"], (f as Dictionary)["monster"], g])
					if cell.size() == 2:
						assert_true(str(rows[int(cell[1])])[int(cell[0])] in ".~", "%s:%s's %s stands on open ground on %s %s" % [tid, entry["id"], (f as Dictionary)["monster"], g, cell])
						assert_true(maxi(absi(int(cell[0]) - int(spawn[0])), absi(int(cell[1]) - int(spawn[1]))) >= 3, "%s:%s's foes start clear of the party on %s" % [tid, entry["id"], g])


## One fight from each table, set up on its own map with the party at the arrival square and played for two rounds: the
## monsters take their turns on these grounds without an error.
func test_one_fight_from_each_table_runs() -> void:
	var c := Compendium.shared()
	for tid: Variant in _tables():
		var table := _tables()[tid] as Dictionary
		var fights := (table["entries"] as Array).filter(func(e: Variant) -> bool: return (e as Dictionary).has("monsters"))
		if fights.is_empty():
			continue
		var entry := fights[0] as Dictionary
		var loc := c.get_entry("locations", str(table["map"]))
		var spawn := loc["spawns"]["default"] as Array
		var party: Array = []
		var i := 0
		for pid: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
			party.append({"pregen": pid, "cell": [int(spawn[0]) + i % 2, int(spawn[1]) + i / 2]})
			i += 1
		var errors: Array[String] = []
		var e := EncounterSetup.from_data({"map": loc["map"], "party_level": 4, "party": party, "enemies": entry["monsters"]}, DiceRoller.new(7), errors)
		assert_true(errors.is_empty(), "%s:%s %s" % [tid, entry["id"], errors])
		var res := PartyAutopilot.new(e).run(2)
		assert_true(str(res["outcome"]) in ["victory", "defeat", "timeout"], "%s:%s played" % [tid, entry["id"]])


func test_the_crooked_man_waits_on_the_story() -> void:
	var st := StoryState.new()
	st.minute_of_day = 22 * 60
	var cm := Compendium.shared().get_entry("random_encounters", "crooked_man_road")
	assert_true(bool(cm.get("every_road", false)), "he can be at the edge of any road")
	assert_false(StoryConditions.check(str(cm["when"]), st), "not before the Crooked House is done")
	st.flags["vessla_slain"] = true
	assert_true(StoryConditions.check(str(cm["when"]), st))
	var due := (cm["entries"] as Array).filter(func(e: Variant) -> bool: return StoryConditions.check(str((e as Dictionary)["when"]), st))
	assert_eq(due.map(func(e: Variant) -> String: return str((e as Dictionary)["id"])), ["after_house"])
	st.flags["cm_road_house"] = true
	st.flags["renathyr_slain"] = true
	due = (cm["entries"] as Array).filter(func(e: Variant) -> bool: return StoryConditions.check(str((e as Dictionary)["when"]), st))
	assert_eq(due.map(func(e: Variant) -> String: return str((e as Dictionary)["id"])), ["first_fallen"])


func test_his_fireside_visits_come_at_the_interval_and_before_fools_day() -> void:
	NightEvents.use({})
	var st := StoryState.new()
	st.location = "road_moor_bonfire"
	var ids := func() -> Array:
		return NightEvents.events().filter(func(e: Variant) -> bool: return NightEvents.applies(e as Dictionary, st)).map(
			func(e: Variant) -> String: return str((e as Dictionary)["id"]))
	assert_eq(ids.call(), [])
	for f: String in ["raum_slain", "renathyr_slain", "grinning_sinner_slain", "lethica_slain"]:
		st.flags[f] = true
	assert_eq(ids.call(), ["crooked_man_fire"])
	st.flags["fallen_farryn_dead"] = true
	st.flags["fallen_yorgrim_dead"] = true
	assert_eq(ids.call(), ["crooked_man_last_fire"])
	st.flags["chuckles_dead"] = true
	assert_eq(ids.call(), [])

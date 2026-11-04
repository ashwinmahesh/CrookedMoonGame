extends TestCase
## The companions react in Acts II and III's conversations (tools/content/companion_reactions.py, fun pass lane A): every
## chapter file still reads clean, every chapter moves approval on its choices and has asides from all six, and an aside
## plays only with its companion in the party.

const CHAPTERS: Array[String] = ["foxwillow", "monastery", "drowned_crossroads", "skitterdeep", "memorys_rest", "hartsblight",
	"maidenmist", "rookery", "fools_day", "nightmare"]
const IDS: Array[String] = ["rook_coldwake", "tobin_hayward", "silas_vane", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"]


func _files(chapter: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://narrative/" + chapter):
		if f.ends_with(".dialogue"):
			out.append("%s/%s" % [chapter, f.get_basename()])
	return out


func test_every_chapter_file_reads_with_no_errors() -> void:
	for chapter in CHAPTERS:
		for key in _files(chapter):
			var df := DialogueFile.load_key(key)
			assert_true(df != null, key)
			assert_true(df.errors.is_empty(), "%s: %s" % [key, str(df.errors)])


func test_each_chapter_moves_approval_and_hears_from_all_six() -> void:
	for chapter in CHAPTERS:
		var approves := 0
		var heard := {}
		for key in _files(chapter):
			for line in FileAccess.get_file_as_string("res://narrative/%s.dialogue" % key).split("\n"):
				if line.begins_with("approve "):
					approves += 1
					for m in RegEx.create_from_string("([a-z_]+) [+-]\\d+").search_all(line.get_slice(":", 0)):
						assert_true(m.get_string(1) in IDS, "%s: %s" % [key, line])
				var m := RegEx.create_from_string("^interject name:([a-z_]+): ").search(line)
				if m != null:
					heard[m.get_string(1)] = true
		assert_true(approves >= 5, "%s moves approval on its choices (%d)" % [chapter, approves])
		if chapter != "nightmare":   # the Nightmare's first half waits for its drafts
			for id in IDS:
				assert_true(heard.has(id), "%s: %s speaks up somewhere" % [chapter, id])


func test_an_aside_plays_only_with_its_companion_along() -> void:
	# The Fool's Day church: Rook's aside on the rest, with him and without him.
	var with_rook := StoryState.new()
	with_rook.party.append(TestChars.pregen("rook_coldwake", 9))
	var without := StoryState.new()
	without.party.append(TestChars.pregen("silas_vane", 9))
	assert_true(_hears(with_rook, "rook_coldwake"), "Rook's asides play with him along")
	assert_false(_hears(without, "rook_coldwake"), "and never without him")


## Whether a node with one of `who`'s asides says it, run to its end in `st`.
func _hears(st: StoryState, who: String) -> bool:
	for key in _files("fools_day"):
		var df := DialogueFile.load_key(key)
		for node: String in df.order:
			var text := FileAccess.get_file_as_string("res://narrative/%s.dialogue" % key)
			var start := text.find("~ %s\n" % node)
			var end := text.find("\n~ ", start + 1)
			var body := text.substr(start, (end - start) if end > 0 else -1)
			if not body.contains("interject name:%s:" % who) or body.contains("\n* ") or body.contains("\nif "):
				continue
			var r := DialogueRunner.new(st, DiceRoller.new(1))
			if not r.start("%s:%s" % [key, node]):
				continue
			for i in 60:
				var b := r.next()
				if str(b["kind"]) == "line" and str(b["speaker_id"]) == who:
					return true
				if str(b["kind"]) in ["end", "options", "check"]:
					break
			return false
	return false

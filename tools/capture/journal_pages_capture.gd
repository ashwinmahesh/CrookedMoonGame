extends Node
## The campaign's own journal pages (engine journal-pages: data/journal/): Secrets, Townsfolk and Plague with every entry
## known, then Secrets with nothing learned yet.
##   make capture SCENE=res://tools/capture/journal_pages_capture.tscn NAME=journal-pages/x FRAMES=30
## Shots: <out>_secrets.png, <out>_townsfolk.png, <out>_plague.png, <out>_secrets_empty.png.

const GAME := preload("res://world/game_root.gd")
const KNOWN: Array[String] = ["fw_arrived", "secret_william", "secret_martha", "secret_jonah", "secret_isaac",
	"secret_adelaide", "tender_banjo", "tender_song", "tender_certificate", "paid_own_secret", "isaac_found"]


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = GAME.FIRST_LOCATION
	for f in KNOWN:
		st.flags[f] = true
	st.flags["secrets_paid"] = 3
	st.flags["plague_started"] = 1
	st.flags["plague_day"] = 4
	st.flags["plague_toll"] = 16
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 40)
	for page: String in ["Secrets", "Townsfolk", "Plague"]:
		game.call("open_screen", "journal", 0)
		await tool.call("wait_frames", 5)
		(game.get("screen") as Node).call("_turn_to", page)
		await tool.call("wait_frames", 10)
		tool.call("_shot", "%s_%s.png" % [out, page.to_lower()])
		game.call("close_screen")
		await tool.call("wait_frames", 3)
	for f in KNOWN:
		if f != "fw_arrived":
			st.flags.erase(f)
	st.flags.erase("secrets_paid")
	game.call("open_screen", "journal", 0)
	await tool.call("wait_frames", 5)
	(game.get("screen") as Node).call("_turn_to", "Secrets")
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_secrets_empty.png")

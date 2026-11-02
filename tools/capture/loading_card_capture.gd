extends Node
## Shoots the loading card for each region in turn (data/loading/cards.json): the picture, the place's name and a tip.
##   make capture SCENE=res://tools/capture/loading_card_capture.tscn NAME=look/loading ARGS='--places=wickermoor_village,foxwillow'
## Shots: <out>_<place>.png


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			places = a.get_slice("=", 1).split(",")
	for place in places:
		var loc := Compendium.shared().get_entry("locations", place)
		var card := LoadingCard.new()
		card.location = loc
		card.tip = str(LoadingCard.tips()[0])
		add_child(card)
		await tool.call("wait_frames", 40)
		tool.call("_shot", "%s_%s.png" % [out, place])
		card.queue_free()
		await tool.call("wait_frames", 5)

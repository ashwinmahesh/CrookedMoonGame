extends TestCase
## The host contract (the engine handbook, new_game.md section 3): every file the engine reads from the game exists and is
## whole. Most are placeholders today (docs/PLACEHOLDERS.md lists each one to replace); this test keeps the contract met while
## they are replaced, so the game never stops booting for a missing file.

## Files the engine needs, as `res://` paths.
const FILES: Array[String] = [
	"res://art/palette/palette.png", "res://art/palette/palette.json", "res://art/palette/ui_palette.json",
	"res://art/plants/cards.png", "res://art/plants/cards.json", "res://art/plants/flora.json", "res://art/plants/manifest.json",
	"res://art/ui/map/barovia.png", "res://data/campaign.json", "res://art/atmosphere/moods.json", "res://art/vistas/vistas.json",
	"res://art/sprites/props/catalog.json", "res://art/ui/title_backdrop.png", "res://art/sprites/villager/walk.tres",
	"res://data/weather/barovia.json", "res://data/progression/xp.json", "res://data/progression/chapters.json",
	"res://data/treasure/levels.json", "res://data/ai/profiles.json", "res://data/camp/night_visitors.json",
	"res://data/loading/cards.json", "res://data/glossary/terms.json", "res://data/busts/facing.json",
	"res://narrative/combat/barks.json", "res://narrative/combat/bosses.json", "res://art/credits.json",
	"res://scenes/main_menu.tscn", "res://scenes/game.tscn", "res://scenes/combat/arena.tscn", "res://scenes/skirmish.tscn",
	"res://tests/saves/README.md",
]


func test_every_file_the_engine_reads_exists() -> void:
	for f in FILES:
		assert_true(FileAccess.file_exists(f) or ResourceLoader.exists(f), "%s is part of the host contract" % f)


func test_every_json_file_of_the_contract_parses() -> void:
	for f in FILES:
		if f.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
			assert_true(parsed is Dictionary, "%s is a JSON object" % f)


func test_the_palette_strip_has_a_colour_for_every_name() -> void:
	var names := JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary
	var strip := load("res://art/palette/palette.png") as Texture2D
	assert_eq(strip.get_width(), names.size(), "palette.png is one pixel per colour (make palette)")
	for n: String in ["void", "ink", "moonlight", "flame", "parchment"]:
		assert_true(names.has(n), "the engine's own screens ask for %s" % n)


func test_the_placeholders_are_written_down() -> void:
	var text := FileAccess.get_file_as_string("res://docs/PLACEHOLDERS.md")
	assert_false(text.is_empty(), "docs/PLACEHOLDERS.md lists what to replace")
	for key: String in ["palette", "moods", "vistas", "catalog", "weather", "pregens", "travel map", "game_root", "barks"]:
		assert_true(text.to_lower().contains(key), "PLACEHOLDERS.md says something about %s" % key)

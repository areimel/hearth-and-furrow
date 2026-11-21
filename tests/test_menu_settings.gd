extends TestCase
## Settings persistence round trip and the Large text mode.

const TEMP_PATH := "user://test_settings_tmp.cfg"


func _fresh() -> GameSettings:
	var settings := GameSettings.new()
	settings.path = TEMP_PATH
	return settings


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func test_defaults_when_no_file_exists() -> void:
	_cleanup()
	var settings := _fresh()
	eq(settings.get_value(&"text_size"), "normal", "text size")
	eq(settings.get_value(&"pause_in_menus"), true, "pause default on")
	eq(settings.get_value(&"relaxed_time"), false, "relaxed default off")
	settings.free()


func test_values_survive_a_round_trip() -> void:
	_cleanup()
	var first := _fresh()
	first.set_value(&"pause_in_menus", false)
	first.set_value(&"music_volume", 0.4)
	first.set_value(&"master_volume", 0.5)
	var second := _fresh()
	second.load_file()
	eq(second.get_value(&"pause_in_menus"), false, "bool persisted")
	near(float(second.get_value(&"music_volume")), 0.4, 0.001, "float persisted")
	eq(second.get_value(&"text_size"), "normal", "untouched default")
	first.set_value(&"master_volume", 1.0)  # restore the real bus
	first.free()
	second.free()
	_cleanup()


func test_large_text_swaps_the_theme_font_size() -> void:
	_cleanup()
	var settings := _fresh()
	settings.autosave = false
	var label := Label.new()
	tree.root.add_child(label)
	var normal := label.get_theme_font_size(&"font_size")
	settings.set_value(&"text_size", "large")
	eq(label.get_theme_font_size(&"font_size"), GameSettings.FONT_SIZES["large"], "large size")
	check(label.get_theme_font_size(&"font_size") > normal, "bigger than normal")
	settings.set_value(&"text_size", "normal")
	eq(label.get_theme_font_size(&"font_size"), normal, "back to normal")
	label.free()
	settings.free()


func test_relaxed_time_slows_the_clock() -> void:
	var settings := _fresh()
	settings.autosave = false
	settings.set_value(&"relaxed_time", true)
	near(GameClock.time_scale, GameSettings.RELAXED_SCALE, 0.0001, "slower")
	settings.set_value(&"relaxed_time", false)
	near(GameClock.time_scale, 1.0, 0.0001, "normal speed")
	settings.free()

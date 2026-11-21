class_name GameSettings extends Node
## Player settings, persisted to user://settings.cfg and applied immediately.
## Register as autoload "Settings" (scripts/autoload/settings.gd). Code that must also
## work without the autoload (menu, tests) uses GameSettings.instance(tree), which finds
## /root/Settings or creates one.
##
## Keys: text_size ("normal" | "large"), pause_in_menus (bool), relaxed_time (bool),
## master_volume / music_volume / sfx_volume (0..1), fullscreen (bool).

## A setting changed (after it was applied and saved).
signal changed(key: StringName)

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
## Default theme font size per text_size value.
const FONT_SIZES: Dictionary = {"normal": 9, "large": 12}
const SMALL_FONT_SIZES: Dictionary = {"normal": 8, "large": 10}
## Clock speed multiplier when relaxed_time is on.
const RELAXED_SCALE := 0.6
const DEFAULTS: Dictionary = {
	"text_size": "normal", "pause_in_menus": true, "relaxed_time": false,
	"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0, "fullscreen": false,
}
## Volume key -> candidate audio bus names (first that exists wins; master is always there).
const BUSES: Dictionary = {
	"master_volume": ["Master"],
	"music_volume": ["Background Music", "Music"],
	"sfx_volume": ["SFX", "Sound Effects"],
}

## Where settings are stored; tests point this at a temp file.
var path: String = DEFAULT_PATH
## Write the file after every set_value(). Disable for demos and tests.
var autosave: bool = true

var _values: Dictionary = {}
var _base_db: Dictionary = {}
var _loaded: bool = false


## The Settings node of `tree`, created under the root when the autoload is absent.
static func instance(tree: SceneTree) -> GameSettings:
	var node := tree.root.get_node_or_null("Settings") as GameSettings
	if node == null:
		node = GameSettings.new()
		node.name = "Settings"
		tree.root.add_child.call_deferred(node)
	return node


func _ready() -> void:
	_ensure_loaded()
	apply_all()


## Value of `key`, or its default (or `fallback` for unknown keys).
func get_value(key: StringName, fallback: Variant = null) -> Variant:
	_ensure_loaded()
	return _values.get(String(key), DEFAULTS.get(String(key), fallback))


## Store, apply and (with autosave) persist one setting.
func set_value(key: StringName, value: Variant) -> void:
	_ensure_loaded()
	_values[String(key)] = value
	_apply(key)
	if autosave:
		save()
	changed.emit(key)


## Read the settings file (missing or damaged file leaves the defaults).
func load_file() -> void:
	_values.clear()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for key: String in DEFAULTS:
			if config.has_section_key(SECTION, key):
				_values[key] = config.get_value(SECTION, key)
	_loaded = true


## Write the settings file. Returns the ConfigFile error code.
func save() -> Error:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, get_value(StringName(key)))
	return config.save(path)


## Apply every setting (done at boot).
func apply_all() -> void:
	for key: String in DEFAULTS:
		_apply(StringName(key))


## True when an audio bus exists for the volume key (e.g. &"sfx_volume").
func has_bus(key: StringName) -> bool:
	return _bus_index(key) >= 0


func _ensure_loaded() -> void:
	if not _loaded:
		load_file()


func _apply(key: StringName) -> void:
	match key:
		&"text_size":
			_apply_text_size(String(get_value(key)))
		&"relaxed_time":
			GameClock.time_scale = RELAXED_SCALE if get_value(key) else 1.0
		&"fullscreen":
			_apply_fullscreen(bool(get_value(key)))
		&"master_volume", &"music_volume", &"sfx_volume":
			_apply_volume(key, float(get_value(key)))


func _apply_text_size(size_name: String) -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null or not FONT_SIZES.has(size_name):
		return
	theme.default_font_size = FONT_SIZES[size_name]
	theme.set_font_size("font_size", "SmallLabel", SMALL_FONT_SIZES[size_name])


func _apply_fullscreen(on: bool) -> void:
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if on and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not on and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_volume(key: StringName, value: float) -> void:
	var bus := _bus_index(key)
	if bus < 0:
		return
	if not _base_db.has(bus):
		_base_db[bus] = AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, _base_db[bus] + linear_to_db(maxf(value, 0.001)))


func _bus_index(key: StringName) -> int:
	for bus_name: String in BUSES.get(String(key), []):
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			return index
	return -1

extends Node
## Autoload `SaveManager`: single-slot, versioned JSON save.
## Providers are objects with to_dict() -> Dictionary, from_dict(Dictionary) and reset();
## each registers itself under a unique key in its _ready(). Values are encoded with
## JSON.from_native, so ints, StringNames, Vector2i and typed arrays round-trip exactly.
## File shape: {"save_version": int, "saved_at": unix seconds, "sections": {key: dict}}.

signal saved(path: String)
signal loaded(path: String)
## Emitted after new_game() has reset every provider.
signal new_game_started

## Bump when the save shape changes, and add a case to _migrate().
const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://save_1.json"

## Where save_game()/load_game() read and write. Tests point this at a temp file.
var save_path: String = DEFAULT_PATH
## autosave() is a no-op until the title menu / day-end flow enables it.
var autosave_enabled: bool = false
var _providers: Dictionary[StringName, Object] = {}


## Adds a save section. Load and reset happen in registration order (= autoload order).
func register(key: StringName, provider: Object) -> void:
	assert(provider.has_method("to_dict") and provider.has_method("from_dict"))
	_providers[key] = provider


func unregister(key: StringName) -> void:
	_providers.erase(key)


func is_registered(key: StringName) -> bool:
	return _providers.has(key)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> Error:
	if not has_save():
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Writes every provider's to_dict() to save_path.
func save_game() -> Error:
	var sections: Dictionary = {}
	for key: StringName in _providers:
		sections[key] = _providers[key].to_dict()
	var data := {"save_version": SAVE_VERSION, "saved_at": int(Time.get_unix_time_from_system()),
		"sections": sections}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(JSON.from_native(data), "\t"))
	file.close()
	saved.emit(save_path)
	return OK


## Saves only when autosave_enabled. Called at the end of GameClock.advance_day().
func autosave() -> Error:
	return save_game() if autosave_enabled else OK


## Reads save_path, migrates it, then calls from_dict() on every registered provider.
## A provider whose section is missing is reset() instead.
func load_game() -> Error:
	if not has_save():
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	var data: Variant = JSON.to_native(parsed)
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	if int(data.get("save_version", 0)) > SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	data = _migrate(data)
	var sections: Dictionary = data.get("sections", {})
	for key: StringName in _providers:
		var section: Variant = sections.get(key, sections.get(String(key)))
		if section is Dictionary:
			_providers[key].from_dict(section)
		elif _providers[key].has_method("reset"):
			_providers[key].reset()
	loaded.emit(save_path)
	return OK


## Resets every provider to new-game state (does not touch the file).
func new_game() -> void:
	for key: StringName in _providers:
		if _providers[key].has_method("reset"):
			_providers[key].reset()
	new_game_started.emit()


## Upgrades older save data one version at a time to SAVE_VERSION.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	while version < SAVE_VERSION:
		match version:
			0:
				# v0 (unversioned dev saves): sections were stored at the top level.
				var sections: Dictionary = {}
				for key: Variant in data.keys():
					if key != "saved_at" and key != "save_version":
						sections[key] = data[key]
				data = {"sections": sections, "saved_at": data.get("saved_at", 0)}
		version += 1
		data["save_version"] = version
	return data

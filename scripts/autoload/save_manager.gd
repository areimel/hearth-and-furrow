extends Node
## Autoload `SaveManager`: single-slot, versioned JSON save.
## Providers are objects with to_dict() -> Dictionary, from_dict(Dictionary) and reset();
## each registers itself under a unique key in its _ready(). Values are encoded with
## JSON.from_native, so ints, StringNames, Vector2i and typed arrays round-trip exactly.
## File shape: {"save_version": int, "saved_at": unix seconds, "sections": {key: dict}}.
## Writes are atomic (temp file then rename) and the previous save is kept as `.bak`;
## a damaged main file falls back to it. Sections whose provider is not registered yet
## (scene-owned state of a level that is still loading) are kept and delivered the moment
## that provider calls register().

signal saved(path: String)
signal loaded(path: String)
## Emitted after new_game() has reset every provider.
signal new_game_started
## load_game() found the main file damaged and loaded the backup instead.
signal backup_restored

## Bump when the save shape changes, and add a migration step for the old version.
const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://save_1.json"
const BACKUP_SUFFIX: String = ".bak"
const TEMP_SUFFIX: String = ".tmp"

## Where save_game()/load_game() read and write. Tests point this at a temp file.
var save_path: String = DEFAULT_PATH
## autosave() is a no-op until a real session enables it (GameSession does).
var autosave_enabled: bool = false
## Player-facing explanation of the last failed or degraded load ("" when it went fine).
var last_message: String = ""
## True when the last load_game() used the backup because the main file was damaged.
var restored_from_backup: bool = false
## Migration steps: version -> Callable(data: Dictionary) -> Dictionary that upgrades
## data from that version to the next. Tests may add synthetic steps.
var migrations: Dictionary[int, Callable] = {0: _migrate_v0}
var _providers: Dictionary[StringName, Object] = {}
var _pending: Dictionary = {}


## Adds a save section. Load and reset happen in registration order (= autoload order).
## If a load already delivered a section for `key` before it existed, it is applied now.
func register(key: StringName, provider: Object) -> void:
	assert(provider.has_method("to_dict") and provider.has_method("from_dict"))
	_providers[key] = provider
	if _pending.has(key):
		var section: Dictionary = _pending[key]
		_pending.erase(key)
		provider.from_dict(section)


func unregister(key: StringName) -> void:
	_providers.erase(key)


func is_registered(key: StringName) -> bool:
	return _providers.has(key)


## Section keys loaded from a save that no provider has claimed yet.
func pending_keys() -> Array:
	return _pending.keys()


## Forgets sections still waiting for a provider (leaving the game for the title).
func discard_pending() -> void:
	_pending.clear()


## Path of the one-deep backup of the previous save.
func backup_path() -> String:
	return save_path + BACKUP_SUFFIX


## True when a save (or its backup) exists to continue from.
func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path())


## Removes the save, its backup and any leftover temp file.
func delete_save() -> Error:
	var result: Error = OK
	for path: String in [save_path, backup_path(), save_path + TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if err != OK:
				result = err
	return result


## Writes every provider's to_dict() to save_path atomically, keeping the previous
## valid save as the backup.
func save_game() -> Error:
	var data := {"save_version": SAVE_VERSION, "saved_at": int(Time.get_unix_time_from_system()),
		"sections": snapshot()}
	var temp_path := save_path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(JSON.from_native(data), "\t"))
	file.close()
	if FileAccess.file_exists(save_path) and _read(save_path).error == OK:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),
				ProjectSettings.globalize_path(backup_path()))
	var err := _replace(temp_path, save_path)
	if err != OK:
		return err
	saved.emit(save_path)
	return OK


## Every registered provider's to_dict(), keyed by section (what save_game() writes).
func snapshot() -> Dictionary:
	var sections: Dictionary = {}
	for key: StringName in _providers:
		sections[key] = _providers[key].to_dict()
	return sections


## Saves only when autosave_enabled. Called at the end of GameClock.advance_day().
func autosave() -> Error:
	return save_game() if autosave_enabled else OK


## Reads save_path (or the backup when it is damaged), migrates it, then calls
## from_dict() on every registered provider. A provider whose section is missing is
## reset() instead; sections nobody has registered yet wait for register(). A save from
## a newer game version is refused (ERR_FILE_UNRECOGNIZED, see last_message).
func load_game() -> Error:
	restored_from_backup = false
	last_message = ""
	var result := _read(save_path)
	if result.error == ERR_FILE_UNRECOGNIZED:
		last_message = "This save was made by a newer version of the game and cannot be loaded."
		return ERR_FILE_UNRECOGNIZED
	if result.error != OK:
		var backup := _read(backup_path())
		if backup.error != OK:
			last_message = "No readable save was found." if result.error == ERR_FILE_NOT_FOUND \
					else "The save file is damaged and there is no backup."
			return result.error
		result = backup
		restored_from_backup = true
		last_message = "Save was damaged; restored the previous one."
		push_warning("SaveManager: %s damaged, restored backup" % save_path)
	_apply(result.data["sections"])
	if restored_from_backup:
		backup_restored.emit()
	loaded.emit(save_path)
	return OK


## Resets every provider to new-game state (does not touch the file).
func new_game() -> void:
	_pending.clear()
	last_message = ""
	for key: StringName in _providers:
		if _providers[key].has_method("reset"):
			_providers[key].reset()
	new_game_started.emit()


## Cheap look at the save for the title menu: {day_index, date, saved_at}, or {} when
## nothing readable exists. Nothing is applied to any provider.
func peek_summary() -> Dictionary:
	for path: String in [save_path, backup_path()]:
		var result := _read(path)
		if result.error == OK:
			var clock: Dictionary = result.data["sections"].get("clock", {})
			var day := int(clock.get("day_index", 0))
			return {"day_index": day, "date": Calendar.date_string(day),
				"saved_at": int(result.data.get("saved_at", 0))}
	return {}


## Upgrades older save data one version at a time to `target` using `migrations`.
func migrate(data: Dictionary, target: int = SAVE_VERSION) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	while version < target:
		if migrations.has(version):
			data = migrations[version].call(data)
		version += 1
		data["save_version"] = version
	return data


func _migrate_v0(data: Dictionary) -> Dictionary:
	# v0 (unversioned dev saves): sections were stored at the top level.
	var sections: Dictionary = {}
	for key: Variant in data.keys():
		if data[key] is Dictionary:
			sections[key] = data[key]
	return {"sections": sections, "saved_at": data.get("saved_at", 0)}


func _apply(sections: Dictionary) -> void:
	_pending.clear()
	for key: StringName in _providers:
		var section: Variant = sections.get(key, sections.get(String(key)))
		if section is Dictionary:
			_providers[key].from_dict(section)
		elif _providers[key].has_method("reset"):
			_providers[key].reset()
	for key: Variant in sections:
		if not _providers.has(StringName(key)) and sections[key] is Dictionary:
			_pending[StringName(key)] = sections[key]


## Parses and migrates one file: {error: Error, data: Dictionary}. data["sections"] is
## guaranteed to be a Dictionary when error is OK.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "data": {}}
	var json := JSON.new()  # instance parse: bad input returns an Error instead of logging one
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.has("type"):  # from_native envelope
		return {"error": ERR_PARSE_ERROR, "data": {}}
	var data: Variant = JSON.to_native(parsed)
	if not data is Dictionary:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	if int(data.get("save_version", 0)) > SAVE_VERSION:
		return {"error": ERR_FILE_UNRECOGNIZED, "data": {}}
	var unversioned: bool = not data.has("save_version")
	data = migrate(data)
	var sections: Variant = data.get("sections")
	if not sections is Dictionary or (unversioned and sections.is_empty()):
		return {"error": ERR_INVALID_DATA, "data": {}}
	return {"error": OK, "data": data}


func _replace(from_path: String, to_path: String) -> Error:
	var from_abs := ProjectSettings.globalize_path(from_path)
	var to_abs := ProjectSettings.globalize_path(to_path)
	var err := DirAccess.rename_absolute(from_abs, to_abs)
	if err != OK and FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_abs)
		err = DirAccess.rename_absolute(from_abs, to_abs)
	return err

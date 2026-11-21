extends TestCase
## SaveManager: full round-trip through a temp file, migration, version guard.

const TEMP_PATH := "user://test_save_tmp.json"


func before_each() -> void:
	SaveManager.save_path = TEMP_PATH
	SaveManager.delete_save()
	SaveManager.new_game()


func _cleanup() -> void:
	SaveManager.migrations.erase(1)
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.DEFAULT_PATH
	SaveManager.new_game()


func test_round_trip_all_services() -> void:
	Economy.add_coins(123)
	Inventory.add(&"cheese", 3)
	Progress.set_flag(&"test_flag")
	Progress.record(&"crafted", &"bread", 4)
	GameClock.day_index = 30
	GameClock.hour = 14
	Relationships.add_points(&"miller", 250)
	QuestManager.start(&"prologue")
	Weather.set_forecast(G.WeatherKind.STORM)
	eq(SaveManager.save_game(), OK, "save ok")
	check(SaveManager.has_save(), "file exists")
	SaveManager.new_game()
	eq(Economy.coins, 100, "reset before load")
	eq(SaveManager.load_game(), OK, "load ok")
	eq(Economy.coins, 223, "coins")
	eq(Inventory.count(&"cheese"), 3, "inventory")
	check(Progress.has_flag(&"test_flag"), "flag")
	eq(Progress.count(&"crafted.bread"), 4, "counter")
	eq(GameClock.day_index, 30, "day")
	eq(GameClock.hour, 14, "hour")
	eq(typeof(GameClock.hour), TYPE_INT, "ints stay ints")
	eq(Relationships.hearts(&"miller"), 2, "hearts")
	check(QuestManager.is_active(&"prologue"), "quest state")
	eq(Weather.forecast, G.WeatherKind.STORM, "forecast")
	check(not GameClock.running, "clock stays stopped after load")
	_cleanup()


func test_migrates_unversioned_save() -> void:
	var v0 := {&"economy": {"coins": 777}}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native(v0)))
	file.close()
	eq(SaveManager.load_game(), OK, "v0 loads")
	eq(Economy.coins, 777, "v0 section migrated")
	eq(Inventory.count(&"hoe_wooden"), 1, "missing section was reset to new game")
	_cleanup()


func test_rejects_newer_version_and_missing_file() -> void:
	eq(SaveManager.load_game(), ERR_FILE_NOT_FOUND, "no file")
	var future := {"save_version": SaveManager.SAVE_VERSION + 1, "sections": {}}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native(future)))
	file.close()
	eq(SaveManager.load_game(), ERR_FILE_UNRECOGNIZED, "future version refused")
	eq(SaveManager.delete_save(), OK, "delete")
	check(not SaveManager.has_save(), "deleted")
	_cleanup()


func test_autosave_is_off_by_default() -> void:
	check(not SaveManager.autosave_enabled, "disabled")
	eq(SaveManager.autosave(), OK, "no-op")
	check(not SaveManager.has_save(), "nothing written")
	_cleanup()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_save_is_atomic_and_keeps_one_backup() -> void:
	Economy.add_coins(1)
	eq(SaveManager.save_game(), OK, "first save")
	check(not FileAccess.file_exists(TEMP_PATH + SaveManager.TEMP_SUFFIX), "no temp file left")
	check(not FileAccess.file_exists(SaveManager.backup_path()), "no backup after the first save")
	Economy.add_coins(10)
	eq(SaveManager.save_game(), OK, "second save")
	check(not FileAccess.file_exists(TEMP_PATH + SaveManager.TEMP_SUFFIX), "no temp file left again")
	check(FileAccess.file_exists(SaveManager.backup_path()), "previous save kept as backup")
	var backup: Dictionary = JSON.to_native(JSON.parse_string(
			FileAccess.get_file_as_string(SaveManager.backup_path())))
	eq(int(backup["sections"]["economy"]["coins"]), 101, "backup holds the earlier coins")
	eq(SaveManager.delete_save(), OK, "delete")
	check(not SaveManager.has_save(), "delete removes the backup too")
	_cleanup()


func test_corrupt_main_file_falls_back_to_backup() -> void:
	Economy.add_coins(50)
	SaveManager.save_game()
	Economy.add_coins(50)
	SaveManager.save_game()
	_write(TEMP_PATH, "{ this is not json")
	SaveManager.new_game()
	eq(SaveManager.load_game(), OK, "load from backup")
	check(SaveManager.restored_from_backup, "flagged as restored")
	eq(Economy.coins, 150, "backup state (the first save)")
	check(SaveManager.last_message != "", "player-facing message set")
	_write(TEMP_PATH, JSON.stringify(JSON.from_native({"save_version": 1, "saved_at": 0})))
	eq(SaveManager.load_game(), OK, "missing sections also fall back")
	check(SaveManager.restored_from_backup, "restored again")
	_cleanup()


func test_corrupt_file_without_backup_is_an_error() -> void:
	_write(TEMP_PATH, "garbage")
	eq(SaveManager.load_game(), ERR_PARSE_ERROR, "no backup, no load")
	check(not SaveManager.restored_from_backup, "nothing restored")
	check(SaveManager.last_message != "", "message set")
	check(SaveManager.peek_summary().is_empty(), "nothing to preview")
	_cleanup()


func test_newer_version_is_refused_with_a_message() -> void:
	SaveManager.save_game()
	_write(TEMP_PATH, JSON.stringify(JSON.from_native(
			{"save_version": SaveManager.SAVE_VERSION + 1, "sections": {}})))
	Economy.add_coins(5)
	eq(SaveManager.load_game(), ERR_FILE_UNRECOGNIZED, "refused, not rescued by an older backup")
	check(SaveManager.last_message.contains("newer"), "message explains why")
	eq(Economy.coins, 105, "state untouched")
	_cleanup()


func test_peek_summary_reads_the_date_without_loading() -> void:
	GameClock.day_index = 11
	SaveManager.save_game()
	GameClock.day_index = 0
	var summary := SaveManager.peek_summary()
	eq(summary["day_index"], 11, "day from the clock section")
	eq(summary["date"], Calendar.date_string(11), "formatted date")
	eq(GameClock.day_index, 0, "nothing applied")
	_cleanup()


func test_synthetic_migration_step_upgrades_old_data() -> void:
	# A pretend v1 -> v2 change: the coins field was renamed. The real version is untouched.
	SaveManager.migrations[1] = func(data: Dictionary) -> Dictionary:
		var economy: Dictionary = data["sections"]["economy"]
		economy["coins"] = economy["gold"]
		economy.erase("gold")
		return data
	var old := {"save_version": 1, "sections": {"economy": {"gold": 9}}}
	var upgraded := SaveManager.migrate(old, 2)
	eq(upgraded["save_version"], 2, "version stamped")
	eq(upgraded["sections"]["economy"], {"coins": 9}, "shape migrated")
	var chained := SaveManager.migrate({"economy": {"gold": 4}}, 2)
	eq(chained["sections"]["economy"], {"coins": 4}, "v0 -> v1 -> v2 chain")
	_cleanup()

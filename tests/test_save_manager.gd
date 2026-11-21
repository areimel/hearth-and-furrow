extends TestCase
## SaveManager: full round-trip through a temp file, migration, version guard.

const TEMP_PATH := "user://test_save_tmp.json"


func before_each() -> void:
	SaveManager.save_path = TEMP_PATH
	SaveManager.delete_save()
	SaveManager.new_game()


func _cleanup() -> void:
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

extends Node
## Soak test: a scripted farmer (tools/sim_farmer.gd) plays 112 days (four seasons) in the
## real level through the public APIs only, saving and reloading at the end of every season
## and checking that the state survived. It is also the economy yardstick: the purse at the
## end of spring and of the year must land in the bands below (targets: data/balance.gd).
## Run: godot --path . --headless res://tools/year_sim.tscn
## Prints SIM/SEASON/YEAR lines and exits non-zero on any failed check or engine ERROR.

const DAYS := 112
const SEASON_DAYS := 28
const TEMP_PATH := "user://year_sim.json"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const OPTIONAL_NODES: Array[String] = ["Shops", "Gathering", "Foraging", "Risks", "Festivals", "BuildMode"]
## Generous bands: the sim is random (weather, forage), the economy must stay inside them.
const SPRING_PURSE_MIN := 100
const SPRING_PURSE_MAX := 1000
const YEAR_PURSE_MIN := 700
const YEAR_PURSE_MAX := 5000

var _level: Level
var _farmer := SimFarmer.new()
var _failures: Array[String] = []
var _errors := ErrorCounter.new()
var _season_start := {"crafted": 0, "reaped": 0, "products": 0, "sold": 0}


## Counts engine ERROR lines (OS.add_logger) so the sim can assert there are none.
class ErrorCounter extends Logger:
	var count := 0
	var first: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		count += 1
		if first.size() < 5:
			first.append("%s:%d %s %s" % [file, line, code, rationale])


func _ready() -> void:
	OS.add_logger(_errors)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = TEMP_PATH
	SaveManager.delete_save()
	SaveManager.autosave_enabled = true  # exercises the real autosave at every day end
	SaveManager.new_game()
	await _spawn()
	var found: Array[String] = []
	for node_name in OPTIONAL_NODES:
		if _level.find_child(node_name, true, false):
			found.append(node_name)
	print("SIM start coins=%d optional_features=%s" % [Economy.coins, found if not found.is_empty() else "none"])
	for day in DAYS:
		_farmer.play_day()
		GameClock.advance_day()
		await get_tree().process_frame
		if (day + 1) % SEASON_DAYS == 0:
			await _season_end(day + 1)
	_finish(saved_path)


func _finish(saved_path: String) -> void:
	print("YEAR days=%d coins=%d goods_made=%d crops_reaped=%d products=%d quests=%d errors=%d" % [
			GameClock.day_index, Economy.coins, _crafted_total(), _farmer.reaped, _farmer.products,
			_farmer.quests, _errors.count])
	print("YEAR first_upgrade_day=%d first_animal_day=%d upgrades=%d animals_bought=%d" % [
			_farmer.first_upgrade_day, _farmer.first_animal_day, _farmer.upgrades, _farmer.animals_bought])
	print("YEAR sold_for_by_item=%s" % [_farmer.sold_by_item])
	_check(Economy.coins >= YEAR_PURSE_MIN and Economy.coins <= YEAR_PURSE_MAX,
			"year-end purse %d outside %d..%d" % [Economy.coins, YEAR_PURSE_MIN, YEAR_PURSE_MAX])
	_check(_farmer.upgrades == Content.tool_kinds().size(), "only %d tool upgrades in a year" % _farmer.upgrades)
	_check(GameClock.day_index == DAYS, "ran %d days, clock says %d" % [DAYS, GameClock.day_index])
	_check(_errors.count == 0, "engine errors: %s" % [_errors.first])
	SaveManager.delete_save()
	SaveManager.save_path = saved_path
	SaveManager.autosave_enabled = false
	for failure in _failures:
		print("SIM FAIL %s" % failure)
	print("SIM %s" % ("FAILED" if not _failures.is_empty() else "OK"))
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _spawn() -> void:
	_level = load(LEVEL_SCENE).instantiate()
	add_child(_level)
	for i in 3:
		await get_tree().process_frame
	GameClock.stop()
	_farmer.level = _level
	_farmer.find_plots()
	_check(_farmer.plots.size() >= 8, "found only %d farmable plots" % _farmer.plots.size())


# ---------------------------------------------------------------- season boundary

func _season_end(day: int) -> void:
	var name_of := Calendar.season_name(Calendar.season(day - 1))
	print("SEASON %s day=%d coins=%d goods_made=%d crops_reaped=%d products=%d sold_for=%d upgrades=%d animals_bought=%d" % [
			name_of, day, Economy.coins, _crafted_total() - _season_start["crafted"],
			_farmer.reaped - _season_start["reaped"], _farmer.products - _season_start["products"],
			_farmer.sold_coins - _season_start["sold"], _farmer.upgrades, _farmer.animals_bought])
	print("SEASON   sold: %s" % [_farmer.season_sales])
	_farmer.season_sales.clear()
	if day == SEASON_DAYS:
		_check(Economy.coins >= SPRING_PURSE_MIN and Economy.coins <= SPRING_PURSE_MAX,
				"spring-end purse %d outside %d..%d" % [Economy.coins, SPRING_PURSE_MIN, SPRING_PURSE_MAX])
	_season_start = {"crafted": _crafted_total(), "reaped": _farmer.reaped,
		"products": _farmer.products, "sold": _farmer.sold_coins}
	_farmer.run_stations()  # leave jobs in flight so the reload has station state to preserve
	await _save_and_reload(name_of)


## Save, tear the level down, load into a fresh level (the continue order) and compare.
func _save_and_reload(label: String) -> void:
	var before := SaveSnapshot.capture()
	var summary := SaveSnapshot.summary(_level)
	_check(SaveManager.save_game() == OK, "%s: save failed" % label)
	_level.free()
	await get_tree().process_frame
	SaveManager.new_game()
	_check(SaveManager.load_game() == OK, "%s: load failed" % label)
	await _spawn()
	var after := SaveSnapshot.summary(_level)
	for key: String in summary:
		_check(summary[key] == after[key], "%s: %s was %s, now %s" % [label, key, summary[key], after[key]])
	var drift := SaveSnapshot.diff(before, SaveSnapshot.capture())
	_check(drift == "", "%s: sections changed across reload: %s" % [label, drift])
	print("SIM reload after %s ok: %s" % [label, after])


func _crafted_total() -> int:
	var total := 0
	for item in Content.items():
		total += Progress.count(Progress.counter_key(&"crafted", item.id))
	return total

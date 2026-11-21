extends Node
## Soak test: a scripted farmer plays 112 days (four seasons) in the real level through
## the public APIs only, saving and reloading at the end of every season and checking that
## the state survived. Run: godot --path . --headless res://tools/year_sim.tscn
## Prints SIM/SEASON/YEAR lines and exits non-zero on any failed check or engine ERROR.
## Features that other branches add (shops, gathering, risks, festivals, build mode) are
## detected by node name and reported; they are only used through public methods.

const DAYS := 112
const SEASON_DAYS := 28
const TEMP_PATH := "user://year_sim.json"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const OPTIONAL_NODES: Array[String] = ["Shops", "Gathering", "Foraging", "Risks", "Festivals", "BuildMode"]
const SEED_RESERVE := 30  ## Coins kept back when buying seed.
const PLOT_COUNT := 18

var _level: Level
var _failures: Array[String] = []
var _errors := ErrorCounter.new()
var _plots: Array[Vector2i] = []
var _reaped := 0
var _products := 0
var _sold_coins := 0
var _quests := 0
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
		_play_day()
		GameClock.advance_day()
		await get_tree().process_frame
		if (day + 1) % SEASON_DAYS == 0:
			await _season_end(day + 1)
	var crafted := _crafted_total()
	print("YEAR days=%d coins=%d goods_made=%d crops_reaped=%d products=%d quests=%d errors=%d" % [
			GameClock.day_index, Economy.coins, crafted, _reaped, _products, _quests, _errors.count])
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
	_find_plots()


func _find_plots() -> void:
	if not _plots.is_empty():
		return  # keep the same plots after a reload (they are occupied by then)
	var farm := _level.farm_grid
	for y in range(-12, -3):
		for x in range(5, 22):
			var cell := Vector2i(x, y)
			if _plots.size() < PLOT_COUNT and farm.is_tool_valid(G.ToolKind.HOE, cell) \
					and not farm.is_occupied(cell):
				_plots.append(cell)
	_check(_plots.size() >= 8, "found only %d farmable plots" % _plots.size())


# ---------------------------------------------------------------- a day's chores

func _play_day() -> void:
	_reap_and_sow()
	_run_stations()
	_tend_animals()
	_social_and_quests()
	_sell_surplus()
	for crop in _level.farm_grid.crop_field.crops():
		_level.farm_grid.water(crop.cell)


func _reap_and_sow() -> void:
	var field := _level.farm_grid.crop_field
	for crop in field.ripe_crops():
		_reaped += field.reap(crop.cell)
	var season := Calendar.season()
	var options: Array[CropData] = []
	for crop_row in Content.crops():
		if crop_row.grows_in(season):
			options.append(crop_row)
	if options.is_empty():
		return
	var pick := 0
	for cell in _plots:
		if field.crop_at(cell) != null:
			continue
		for attempt in options.size():
			var row := options[(pick + attempt) % options.size()]
			if not Inventory.has(row.seed_item, 1) and Economy.coins > SEED_RESERVE:
				Economy.buy(row.seed_item, 1)
			if Inventory.has(row.seed_item, 1):
				if not _level.farm_grid.is_tilled(cell):
					_level.farm_grid.till(cell)
				if field.sow(cell, row.id) != null:
					Inventory.remove(row.seed_item, 1)
					pick += 1
				break


func _run_stations() -> void:
	var works := _level.get_node_or_null("Workstations") as Workstations
	if works == null:
		return
	for station in works.stations():
		station.collect()
		for recipe in Content.recipes_for_station(station.station_id):
			while station.can_start(recipe.id):
				station.start_job(recipe.id)


func _tend_animals() -> void:
	var herd := _level.get_node_or_null("Livestock") as Livestock
	if herd == null:
		return
	for animal in herd.animals():
		if animal.product_ready and animal.collect():
			_products += 1
		if not Inventory.has(animal.data.feed_item, 1):
			Economy.buy(animal.data.feed_item, 1)
		animal.feed()
		animal.pet()


func _social_and_quests() -> void:
	for npc in Content.npcs():
		Relationships.talk(npc.id)
	for quest in Content.quests():
		if QuestManager.can_start(quest.id):
			QuestManager.start(quest.id)
		if QuestManager.is_active(quest.id) and QuestManager.is_ready(quest.id) \
				and QuestManager.complete(quest.id):
			_quests += 1


## Sell everything that is neither seed, tool, animal feed nor a stockpile of recipe input.
func _sell_surplus() -> void:
	var feed: Array[StringName] = []
	for animal_row in Content.animals():
		feed.append(animal_row.feed_item)
	for i in Inventory.size():
		var id := Inventory.slot_id(i)
		if id == &"" or id in feed:
			continue
		var item := Content.item(id)
		if item == null or item.is_tool() or item.is_seed() or not item.is_sellable():
			continue
		var keep := 8 if not Content.recipes_using(id).is_empty() else 0
		var surplus := Inventory.count(id) - keep
		if surplus > 0:
			_sold_coins += Economy.sell(id, surplus)


# ---------------------------------------------------------------- season boundary

func _season_end(day: int) -> void:
	var name_of := Calendar.season_name(Calendar.season(day - 1))
	print("SEASON %s day=%d coins=%d goods_made=%d crops_reaped=%d products=%d sold_for=%d" % [
			name_of, day, Economy.coins, _crafted_total() - _season_start["crafted"],
			_reaped - _season_start["reaped"], _products - _season_start["products"],
			_sold_coins - _season_start["sold"]])
	_season_start = {"crafted": _crafted_total(), "reaped": _reaped, "products": _products,
		"sold": _sold_coins}
	_run_stations()  # leave jobs in flight so the reload has station state to preserve
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

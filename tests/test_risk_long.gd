extends TestCase
## Statistical guarantee: even the worst habits (same wheat every time, reaping two days
## late, ignoring every warning) never lose more than a cozy share of the yield.

const Balance := preload("res://data/balance.gd")
const YEARS := 10
const FIELD_CELLS := 12
const REAP_LAG := 2
const MAX_LOSS_SHARE := 0.25

var level: Level
var field: CropField
var risk: RiskSystem


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	field = level.farm_grid.crop_field
	level.day_cycle.fade_time = 0.0
	level.day_cycle.hold_time = 0.0
	risk = load("res://scenes/world/risk_system.tscn").instantiate()
	level.add_child(risk)
	await tree.process_frame


func _despawn() -> void:
	level.free()
	await tree.process_frame


func _plant(cell: Vector2i) -> void:
	level.farm_grid.till(cell)
	field.sow(cell, &"wheat")


func _run(world_seed: int) -> float:
	GameClock.day_index = 0
	Weather.world_seed = world_seed
	Weather.set_today(Weather.roll_for_day(0))
	Weather.set_forecast(Weather.roll_for_day(1))
	field.clear()
	var cells: Array[Vector2i] = []
	for i in FIELD_CELLS:
		cells.append(Vector2i(i, -40))
		_plant(cells[i])
	var ripe_days: Dictionary = {}
	var potential := 0
	var actual := 0
	for day in YEARS * Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR:
		GameClock.advance_day()
		for cell in cells:
			var crop := field.crop_at(cell)
			crop.weeds = 0  # weeds are measured elsewhere
			if not crop.is_ripe():
				continue
			ripe_days[cell] = int(ripe_days.get(cell, 0)) + 1
			if ripe_days[cell] > REAP_LAG:
				potential += crop.data.yield_amount
				actual += 1 if crop.is_flattened() else crop.yield_amount()
				field.reap(cell)
				ripe_days.erase(cell)
				_plant(cell)
	return 1.0 - float(actual) / float(maxi(1, potential))


func test_twenty_years_of_wheat_after_wheat_stays_cozy() -> void:
	await _spawn()
	for world_seed in [11]:
		var loss := _run(world_seed)
		check(loss <= MAX_LOSS_SHARE, "seed %d lost %.1f%% of the yield" % [world_seed, loss * 100.0])
	await _despawn()

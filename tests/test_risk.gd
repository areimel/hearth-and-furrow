extends TestCase
## Storm and blight rules on a real level with a RiskSystem attached.

const WET := [G.WeatherKind.RAIN, G.WeatherKind.RAIN, G.WeatherKind.RAIN]

var level: Level
var grid: FarmGrid
var field: CropField
var risk: RiskSystem


func before_each() -> void:
	SaveManager.new_game()


func _spawn(day: int = 20) -> void:
	level = await spawn_level()
	grid = level.farm_grid
	field = grid.crop_field
	risk = level.get_node("RiskSystem")
	GameClock.day_index = day
	Weather.from_dict({"today": G.WeatherKind.CLEAR, "forecast": G.WeatherKind.CLEAR, "world_seed": 5})


func _sow(crop_id: StringName, cell: Vector2i, ripe: bool = false) -> Crop:
	grid.till(cell)
	var crop := field.sow(cell, crop_id)
	if ripe:
		crop.age = crop.data.days_to_mature
	return crop


func _next_day(kind: int) -> void:
	Weather.set_forecast(kind)
	GameClock.advance_day()


## Sow, reap and resow `crop_id` on `cell` so it counts as grown there before.
func _repeat_crop(crop_id: StringName, cell: Vector2i) -> Crop:
	_sow(crop_id, cell, true)
	field.reap(cell)
	return _sow(crop_id, cell)


func _afflicted() -> int:
	var count := 0
	for crop in field.crops():
		if crop.blighted or crop.blight_warning:
			count += 1
	return count


func test_storm_flattens_at_most_forty_percent_of_ripe_grain_only() -> void:
	await _spawn()
	var ripe: Array[Crop] = []
	for i in 10:
		ripe.append(_sow(&"wheat", Vector2i(i, -20), true))
	var young := _sow(&"wheat", Vector2i(0, -21))
	var peas := _sow(&"peas", Vector2i(1, -21), true)
	Weather.set_today(G.WeatherKind.STORM)
	_next_day(G.WeatherKind.CLEAR)
	var flat := ripe.filter(func(c: Crop) -> bool: return c.is_flattened()).size()
	check(flat >= 1 and flat <= floori(10 * Balance.STORM_MAX_LOSS), "flattened %d of 10" % flat)
	check(not young.is_flattened(), "unripe grain untouched")
	check(not peas.is_flattened(), "non-grain untouched")
	check(risk.recent_losses() == flat, "bad week counter")
	await despawn_level()


func test_storm_never_takes_everything_and_flattened_crop_still_yields() -> void:
	await _spawn()
	for count in [1, 2, 3]:
		field.clear()
		var crops: Array[Crop] = []
		for i in count:
			crops.append(_sow(&"wheat", Vector2i(i, -22), true))
		Weather.set_today(G.WeatherKind.STORM)
		_next_day(G.WeatherKind.CLEAR)
		var standing := crops.filter(func(c: Crop) -> bool: return not c.is_flattened()).size()
		check(standing >= 1, "with %d ripe, some stand" % count)
	var victim := _sow(&"wheat", Vector2i(5, -23), true)
	victim.flatten()
	var before := Inventory.count(Balance.FLATTENED_SALVAGE_ITEM)
	check(field.reap(Vector2i(5, -23)) >= 1, "salvage reaped")
	eq(Inventory.count(Balance.FLATTENED_SALVAGE_ITEM), before + 1, "straw")
	await despawn_level()


func test_reaping_before_the_storm_removes_the_risk() -> void:
	await _spawn()
	var cells: Array[Vector2i] = []
	for i in 6:
		cells.append(Vector2i(i, -24))
		_sow(&"wheat", cells[i], true)
	Weather.set_today(G.WeatherKind.STORM)
	for cell in cells:
		field.reap(cell)
	_next_day(G.WeatherKind.CLEAR)
	eq(risk.recent_losses(), 0, "nothing left to flatten")
	await despawn_level()


func test_storm_result_does_not_depend_on_growth_order() -> void:
	await _spawn()
	var tonight := _sow(&"wheat", Vector2i(2, -25))
	tonight.age = tonight.data.days_to_mature - 1  # ripens tonight
	for i in 5:
		_sow(&"wheat", Vector2i(i, -26), true)
	Weather.set_today(G.WeatherKind.STORM)
	_next_day(G.WeatherKind.CLEAR)
	check(not tonight.is_flattened(), "a crop that ripened tonight was not in the storm")
	await despawn_level()


func test_week_one_is_risk_free() -> void:
	await _spawn(0)
	for i in 8:
		_repeat_crop(&"wheat", Vector2i(i, -27))
	for i in 5:
		_sow(&"wheat", Vector2i(i, -28), true)
	Weather.from_dict({"today": G.WeatherKind.STORM, "forecast": G.WeatherKind.RAIN, "world_seed": 5, "past": WET})
	for day in 5:
		_next_day(G.WeatherKind.RAIN)
		eq(_afflicted(), 0, "no blight on day %d" % GameClock.day_index)
	check(field.crops().all(func(c: Crop) -> bool: return not c.is_flattened()), "no flattening")
	await despawn_level()


func test_blight_needs_wet_spell_and_same_crop_before() -> void:
	await _spawn()
	var same := _repeat_crop(&"wheat", Vector2i(0, -29))
	_sow(&"barley", Vector2i(1, -29), true)
	field.reap(Vector2i(1, -29))
	var swapped := _sow(&"wheat", Vector2i(1, -29))
	for i in 8:  # filler so the blight cap leaves room for a few
		_sow(&"wheat", Vector2i(2 + i, -29))
	for day in 60:  # dry weather: nothing
		same.age = 0
		_next_day(G.WeatherKind.CLEAR)
	eq(_afflicted(), 0, "dry weeks never bring blight")
	var seen := false
	for day in 60:
		same.age = 0
		swapped.age = 0
		_next_day(G.WeatherKind.RAIN)
		check(not swapped.blight_warning and not swapped.blighted, "rotated cell stays healthy")
		seen = seen or same.blight_warning or same.blighted
	check(seen, "wet spell spots the crop prev=%s wet=%s day=%d season=%d age=%d" % [risk.previous_crop(same.cell), Weather.is_wet_spell(), GameClock.day_index, Calendar.season(), same.age])
	await despawn_level()


func test_blight_cap_and_warning_day_cure() -> void:
	await _spawn()
	var crops: Array[Crop] = []
	for i in 10:
		crops.append(_repeat_crop(&"wheat", Vector2i(i, -30)))
	var worst := 0
	for day in 80:
		for crop in crops:
			crop.age = 0
		_next_day(G.WeatherKind.RAIN)
		worst = maxi(worst, _afflicted())
		check(_afflicted() <= floori(10 * Balance.BLIGHT_MAX_SHARE), "cap respected on day %d" % day)
	check(worst > 0, "blight did occur")
	for crop in crops:
		crop.blight_warning = false
		crop.blighted = false
	var spotted := crops[0]
	spotted.blight_warning = true
	spotted.weeds = 1
	check(grid.is_tool_valid(G.ToolKind.HOE, spotted.cell), "hoe works on a spotted crop")
	level._hoe(spotted.cell)
	check(not spotted.blight_warning, "hoeing cures the warning")
	_next_day(G.WeatherKind.CLEAR)
	check(not spotted.blighted, "cured crop does not turn")
	await despawn_level()


func test_uncured_warning_turns_and_blighted_still_yields() -> void:
	await _spawn()
	var crop := _repeat_crop(&"wheat", Vector2i(0, -31))
	crop.blight_warning = true
	Weather.from_dict({"today": G.WeatherKind.RAIN, "forecast": G.WeatherKind.RAIN, "world_seed": 5, "past": WET})
	crop.age = 0
	_next_day(G.WeatherKind.RAIN)
	check(crop.blighted and not crop.blight_warning, "turned next morning")
	crop.age = crop.data.days_to_mature
	crop.weeds = Balance.MAX_WEEDS
	check(crop.yield_amount() >= 1, "yield at least 1")
	check(Inventory.count(&"wheat_sheaf") + field.reap(Vector2i(0, -31)) > 0, "reaps")
	await despawn_level()


func test_save_round_trip_and_advice() -> void:
	await _spawn()
	_repeat_crop(&"wheat", Vector2i(3, -32))
	_next_day(G.WeatherKind.CLEAR)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(risk.to_dict()))
	risk.reset()
	eq(risk.previous_crop(Vector2i(3, -32)), &"", "reset forgets")
	risk.from_dict(saved)
	eq(risk.previous_crop(Vector2i(3, -32)), &"wheat", "history restored")
	risk.from_dict({})
	eq(risk.recent_losses(), 0, "empty save")
	check(risk.advice() != "", "advice text")
	check(SaveManager.is_registered(&"risks"), "registered")
	await despawn_level()
	check(not SaveManager.is_registered(&"risks"), "unregistered on exit")

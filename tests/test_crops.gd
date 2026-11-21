extends TestCase
## Crop rules on a real level: field vs garden growth, seasons, weeds, reaping,
## blight/storm salvage and the `farm` save section.

var level: Level
var grid: FarmGrid
var field: CropField


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	grid = level.farm_grid
	field = grid.crop_field
	level.day_cycle.fade_time = 0.0
	level.day_cycle.hold_time = 0.0
	Weather.set_today(G.WeatherKind.CLEAR)


func _despawn() -> void:
	level.free()
	await tree.process_frame


## Roll `count` dry days (never rain), optionally watering `cell` each evening.
func _days(count: int, water_cell: Variant = null) -> void:
	for i in count:
		Weather.set_forecast(G.WeatherKind.CLEAR)
		if water_cell != null:
			grid.water(water_cell)
		GameClock.advance_day()


func _planted(crop_id: StringName, cell: Vector2i) -> Crop:
	grid.till(cell)
	return field.sow(cell, crop_id)


func test_field_crop_ripens_in_days_without_water() -> void:
	await _spawn()
	var crop := _planted(&"wheat", Vector2i(10, -7))
	var days := crop.data.days_to_mature
	_days(days - 1)
	check(not crop.is_ripe(), "not ripe a day early")
	_days(1)
	check(crop.is_ripe(), "ripe after %d dry days" % days)
	await _despawn()


func test_garden_crop_needs_water() -> void:
	await _spawn()
	var cell := Vector2i(11, -7)
	var crop := _planted(&"cabbage", cell)
	_days(3)
	eq(crop.age, 0, "dry garden crop does not grow")
	_days(2, cell)
	eq(crop.age, 2, "watered garden crop grows")
	await _despawn()


func test_out_of_season_pauses_and_never_dies() -> void:
	await _spawn()
	var cell := Vector2i(12, -7)
	var crop := _planted(&"flax", cell)  # spring and summer only
	GameClock.day_index = Calendar.day_index_for(1, G.Season.AUTUMN, 1)
	_days(5, cell)
	eq(crop.age, 0, "paused out of season")
	check(is_instance_valid(crop) and field.crop_at(cell) == crop, "still planted")
	await _despawn()


func test_weeds_reduce_yield_but_not_below_one() -> void:
	await _spawn()
	var crop := _planted(&"wheat", Vector2i(13, -7))
	eq(crop.yield_amount(), crop.data.yield_amount, "clean yield")
	crop.weeds = 1
	check(crop.yield_amount() < crop.data.yield_amount, "one weed costs yield")
	crop.weeds = Balance.MAX_WEEDS
	eq(crop.yield_amount(), 1, "never below 1")
	await _despawn()


func test_hoe_clears_weeds_and_is_valid_only_on_weedy_crop() -> void:
	await _spawn()
	var cell := Vector2i(14, -7)
	var crop := _planted(&"wheat", cell)
	check(not grid.is_tool_valid(G.ToolKind.HOE, cell), "hoe invalid on clean crop")
	crop.weeds = 2
	check(grid.is_tool_valid(G.ToolKind.HOE, cell), "hoe valid on weedy crop")
	level._hoe(cell)
	eq(crop.weeds, 0, "weeds pulled")
	await _despawn()


func test_sickle_reaps_only_ripe_crops_into_inventory() -> void:
	await _spawn()
	var cell := Vector2i(15, -7)
	var crop := _planted(&"wheat", cell)
	check(not grid.is_tool_valid(G.ToolKind.SICKLE, cell), "sickle invalid on young crop")
	eq(field.reap(cell), 0, "nothing to reap yet")
	crop.age = crop.data.days_to_mature
	check(grid.is_tool_valid(G.ToolKind.SICKLE, cell), "sickle valid on ripe crop")
	var before := Inventory.count(&"wheat_sheaf")
	eq(field.reap(cell), crop.data.yield_amount, "reaped amount")
	eq(Inventory.count(&"wheat_sheaf"), before + crop.data.yield_amount, "added to inventory")
	eq(Progress.count("harvested.wheat_sheaf"), crop.data.yield_amount, "progress recorded")
	await tree.process_frame
	check(field.crop_at(cell) == null and not grid.is_occupied(cell), "cell freed")
	await _despawn()


func test_regrowing_crop_stays_and_ripens_again() -> void:
	await _spawn()
	var cell := Vector2i(16, -7)
	var crop := _planted(&"peas", cell)
	crop.age = crop.data.days_to_mature
	field.reap(cell)
	check(field.crop_at(cell) == crop, "peas remain planted")
	check(not crop.is_ripe(), "regrowing")
	_days(crop.data.regrow_days)
	check(crop.is_ripe(), "ripe again after regrow_days")
	await _despawn()


func test_blighted_and_flattened_crops_still_yield() -> void:
	await _spawn()
	var blighted := _planted(&"peas", Vector2i(17, -7))
	blighted.blighted = true
	blighted.weeds = Balance.MAX_WEEDS
	check(blighted.yield_amount() >= 1, "blighted and weedy yields at least 1")
	var flat := _planted(&"wheat", Vector2i(18, -7))
	flat.flatten()
	check(flat.is_ripe(), "flattened crop can be salvaged")
	var before := Inventory.count(Balance.FLATTENED_SALVAGE_ITEM)
	check(field.reap(Vector2i(18, -7)) >= 1, "salvage gives something")
	eq(Inventory.count(Balance.FLATTENED_SALVAGE_ITEM), before + 1, "one straw")
	await _despawn()


func test_farm_section_round_trip() -> void:
	await _spawn()
	var cell := Vector2i(19, -7)
	var crop := _planted(&"barley", cell)
	crop.age = 3
	crop.weeds = 2
	crop.blighted = true
	grid.water(cell)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(grid.to_dict()))
	SaveManager.new_game()  # the level's farm provider resets
	await tree.process_frame
	check(field.crop_at(cell) == null and not grid.is_tilled(cell), "reset clears the farm")
	grid.from_dict(saved)
	var back := field.crop_at(cell)
	check(back != null, "crop restored")
	eq(back.crop_id, &"barley", "id")
	eq(back.age, 3, "age")
	eq(back.weeds, 2, "weeds")
	check(back.blighted, "blight")
	check(grid.is_wet(cell) and grid.is_tilled(cell), "soil restored")
	check(grid.is_occupied(cell), "cell claimed again")
	grid.from_dict({})
	eq(field.crops().size(), 0, "from_dict({}) empties the farm")
	await _despawn()

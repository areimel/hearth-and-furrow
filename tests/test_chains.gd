extends TestCase
## Each production chain driven end to end through real Station nodes, from raw items.

var _stations: Dictionary = {}


func before_each() -> void:
	SaveManager.new_game()
	_stations.clear()


func _run(station_id: StringName, recipe_id: StringName) -> void:
	if not _stations.has(station_id):
		var made := Station.create(station_id)
		tree.root.add_child.call_deferred(made)
		await tree.process_frame
		_stations[station_id] = made
	var station: Station = _stations[station_id]
	var recipe := Content.recipe(recipe_id)
	check(station.start_job(recipe_id), "start %s" % recipe_id)
	if recipe.overnight:
		GameClock.advance_day()
	else:
		GameClock.advance_minutes(recipe.minutes)
	check(station.has_output(), "%s ready" % recipe_id)
	check(station.collect(), "%s collected" % recipe_id)


func _finish() -> void:
	for station: Station in _stations.values():
		station.free()


func test_bread_chain() -> void:
	Inventory.add(&"wheat_sheaf", 1)
	Inventory.add(&"barm", 1)
	await _run(&"threshing_floor", &"thresh_wheat")
	await _run(&"quern", &"grind_flour")
	await _run(&"bread_oven", &"bake_bread")
	check(Inventory.count(&"bread") >= 2, "bread baked")
	_finish()


func test_dairy_chain() -> void:
	Inventory.add(&"milk", 5)
	await _run(&"churn", &"churn_butter")
	await _run(&"cheese_press", &"press_cheese")
	check(Inventory.count(&"butter") >= 1 and Inventory.count(&"cheese") >= 1, "butter and cheese")
	_finish()


func test_ale_chain() -> void:
	Inventory.add(&"barley", 2)
	await _run(&"malting_floor", &"malt_barley")
	await _run(&"brewing_vat", &"brew_ale")
	check(Inventory.count(&"ale") >= 2 and Inventory.count(&"barm") >= 1, "ale and barm")
	_finish()


func test_linen_chain() -> void:
	Inventory.add(&"flax", 16)
	for i in 4:
		await _run(&"retting_tub", &"ret_flax")
	for i in 4:
		await _run(&"distaff", &"spin_thread")
	for i in 2:
		await _run(&"loom", &"weave_linen")
	await _run(&"workbench", &"sew_linen_sack")
	check(Inventory.count(&"linen_sack") >= 1, "linen sack sewn")
	_finish()

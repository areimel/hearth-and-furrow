extends TestCase
## Build mode: validity rules, building pays and occupies, removal refunds and refuses
## busy stations, and the build menu's list and greying.

var level: Level
var works: Workstations
var mode: BuildMode
var menu: BuildMenu


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	works = level.get_node("Workstations")
	mode = level.build_mode
	await tree.process_frame
	await tree.process_frame
	menu = tree.get_first_node_in_group(BuildMenu.BUILD_GROUP)


func _despawn() -> void:
	level.free()
	await tree.process_frame


## A buildable cell; the player is moved beside it so it is the target cell.
func _target_free_cell() -> Vector2i:
	for cell in level.farm_grid.ground_layer.get_used_cells():
		if level.farm_grid.is_buildable(cell) and level.farm_grid.is_buildable(cell + Vector2i(1, 0)):
			level.player.position = Vector2((cell - Vector2i(1, 0)) * 16) + Vector2(8, 8)
			level.player.animation_direction = Vector2.RIGHT
			return cell
	return Vector2i.ZERO


func test_starter_yard_is_only_the_starter_set() -> void:
	await _spawn()
	var ids: Array[StringName] = []
	for station in works.stations():
		ids.append(station.station_id)
	eq(ids.size(), 4, "four starter stations")
	for id: StringName in [&"churn", &"quern", &"threshing_floor", &"workbench"]:
		check(id in ids, "%s in the starter yard" % id)
	await _despawn()


func test_validity_rules() -> void:
	await _spawn()
	var grid := level.farm_grid
	var cell := _target_free_cell()
	check(grid.is_buildable(cell), "free dry cell")
	grid.till(cell)
	check(not grid.is_buildable(cell), "tilled soil refused")
	grid.soil_layer.erase_cell(cell)
	grid.occupy(cell, level)
	check(not grid.is_buildable(cell), "occupied (planted) refused")
	grid.release(cell)
	for water_cell in grid.ground_layer.get_used_cells():
		if grid.is_water(water_cell):
			check(not grid.is_buildable(water_cell), "water refused")
			break
	check(works.build(&"churn", works.stations()[0].coord) == null, "cannot build over a station")
	await _despawn()


func test_build_pays_cost_and_occupies_the_cell() -> void:
	await _spawn()
	var cell := _target_free_cell()
	check(works.build(&"loom", cell) == null, "unaffordable build refused")
	Inventory.add(&"log", 8)
	Inventory.add(&"hazel_rod", 6)
	mode.start_placing(&"loom")
	check(mode.active() and mode.mode == BuildMode.Mode.PLACE, "placing")
	check(mode.target_valid(), "target is valid")
	mode.perform()
	check(works.station_at(cell) != null, "station placed on the target cell")
	check(level.farm_grid.occupant(cell) == works.station_at(cell), "cell occupied")
	eq(Inventory.count(&"log"), 0, "logs paid")
	eq(Inventory.count(&"hazel_rod"), 0, "rods paid")
	check(not mode.active(), "leaves placement once it cannot afford another")
	await _despawn()


func test_placement_stays_while_affordable() -> void:
	await _spawn()
	var cell := _target_free_cell()
	Inventory.add(&"log", 8)
	mode.start_placing(&"churn")
	mode.perform()
	check(mode.active(), "still affordable, still placing")
	check(not mode.target_valid(), "the cell is now taken")
	mode.exit()
	check(not mode.active() and not level.player.action_override.is_valid(), "exit clears the override")
	check(works.station_at(cell) != null, "built")
	await _despawn()


func test_remove_refunds_half_rounded_down() -> void:
	await _spawn()
	var cell := _target_free_cell()
	Inventory.add(&"stone", 10)
	Inventory.add(&"clay", 6)
	works.build(&"bread_oven", cell)  # costs stone 10, clay 6
	eq(works.refund_of(&"bread_oven"), {&"stone": 5, &"clay": 3}, "refund table")
	eq(works.refund_of(&"workbench"), {&"log": 2}, "5 logs refund 2")
	mode.start_removing()
	mode.perform()
	await tree.process_frame
	check(works.station_at(cell) == null, "removed")
	eq(Inventory.count(&"stone"), 5, "stone refunded")
	eq(Inventory.count(&"clay"), 3, "clay refunded")
	await _despawn()


func test_remove_refused_while_busy_or_holding_output() -> void:
	await _spawn()
	var cell := _target_free_cell()
	Inventory.add(&"log", 4)
	var churn := works.build(&"churn", cell)
	Inventory.add(&"milk", 5)
	churn.start_job(&"churn_butter")
	check(not works.can_remove(cell), "busy station refused")
	mode.start_removing()
	mode.perform()
	check(works.station_at(cell) != null, "still standing")
	GameClock.advance_minutes(600)
	check(churn.has_output(), "output waiting")
	check(not works.can_remove(cell), "output waiting refused")
	churn.collect()
	check(works.can_remove(cell), "idle and empty can go")
	await _despawn()


func test_menu_lists_every_station_greys_and_removes() -> void:
	await _spawn()
	menu.open_menu()
	var ids := menu.entry_ids()
	eq(ids.size(), Content.stations().size() + 1, "stations plus remove entry")
	eq(ids[ids.size() - 1], BuildMenu.REMOVE_ENTRY, "remove entry last")
	for i in ids.size() - 1:
		check(menu.is_entry_greyed(i) == not works.can_afford_build(ids[i]), "grey matches affordability for %s" % ids[i])
	var churn_index := ids.find(&"churn")
	check(menu.is_entry_greyed(churn_index), "churn greyed without logs")
	Inventory.add(&"log", 4)
	check(not menu.is_entry_greyed(churn_index), "churn available with logs")
	menu.close()
	await _despawn()


func test_build_action_opens_menu_and_choosing_enters_placement() -> void:
	await _spawn()
	var press := InputEventAction.new()
	press.action = &"build"
	press.pressed = true
	mode._unhandled_input(press)
	check(menu.is_open, "build opens the menu")
	mode._unhandled_input(press)
	check(not menu.is_open, "build closes it again")
	Inventory.add(&"log", 4)
	menu.open_menu()
	menu._on_entry_selected(&"churn")
	check(mode.active() and mode.station_id == &"churn" and not menu.is_open, "choice enters placement")
	mode._unhandled_input(press)
	check(not mode.active(), "build exits")
	await _despawn()

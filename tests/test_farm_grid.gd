extends TestCase
## FarmGrid cell maths, soil state, occupancy and the save round trip,
## exercised on a real instance of the level scene.

var level: Level
var grid: FarmGrid


func _spawn() -> void:
	level = await spawn_level()
	grid = level.farm_grid


func test_level_exposes_grid_and_containers() -> void:
	await _spawn()
	check(grid != null, "farm_grid missing")
	check(level.is_in_group("Level"), "level not in group")
	for container: Node2D in [level.crops(), level.animals(), level.stations(), level.npcs(), level.gatherables()]:
		check(container != null, "container missing")
	await despawn_level()


func test_cell_of_floors_negative_coordinates() -> void:
	await _spawn()
	eq(grid.cell_of(Vector2(0, 0)), Vector2i(0, 0), "origin")
	eq(grid.cell_of(Vector2(15.9, 16.0)), Vector2i(0, 1), "positive")
	eq(grid.cell_of(Vector2(-0.1, -16.1)), Vector2i(-1, -2), "negative")
	eq(grid.get_target_grid(Vector2(8, 8), Vector2(1, 0)), Vector2i(1, 0), "target in front")
	await despawn_level()


func test_till_water_and_dry() -> void:
	await _spawn()
	var cell := Vector2i(40, 40)
	check(not grid.is_tilled(cell), "starts untilled")
	grid.till(cell)
	check(grid.is_tilled(cell), "tilled")
	check(cell in grid.tilled_cells(), "listed as tilled")
	grid.water(cell)
	check(grid.is_wet(cell), "wet")
	grid.dry_all()
	check(not grid.is_wet(cell), "dry again")
	grid.water_all()
	check(grid.is_wet(cell), "rain wets tilled cells")
	await despawn_level()


func test_occupancy() -> void:
	await _spawn()
	var cell := Vector2i(41, 41)
	var node := Node2D.new()
	grid.occupy(cell, node)
	check(grid.occupant(cell) == node, "occupant stored")
	check(not grid.is_free_for_placement(cell), "occupied cell not free")
	grid.release(cell)
	check(grid.occupant(cell) == null, "released")
	grid.occupy(cell, node)
	node.free()
	check(not grid.is_occupied(cell), "freed occupant ignored")
	await despawn_level()


func test_dict_round_trip() -> void:
	await _spawn()
	var a := Vector2i(42, 42)
	var b := Vector2i(43, 42)
	grid.till(a)
	grid.till(b)
	grid.water(b)
	var saved := grid.to_dict()
	grid.soil_layer.clear()
	grid.dry_all()
	grid.from_dict(saved)
	check(grid.is_tilled(a) and grid.is_tilled(b), "tilled restored")
	check(grid.is_wet(b) and not grid.is_wet(a), "wet restored")
	eq(grid.to_dict()["tilled"].size(), saved["tilled"].size(), "same tilled count")
	await despawn_level()


func test_placeable_registers_and_releases_cell() -> void:
	await _spawn()
	var cell := Vector2i(44, 44)
	var placeable: Placeable = load("res://scenes/objects/placeable.tscn").instantiate()
	placeable.setup(cell, level, level.stations())
	check(grid.occupant(cell) == placeable, "setup occupies cell")
	eq(placeable.get_parent(), level.stations(), "added under stations")
	placeable.remove()
	await tree.process_frame
	check(not grid.is_occupied(cell), "remove releases cell")
	await despawn_level()


func test_village_ground_is_land_not_water() -> void:
	await _spawn()
	var village := level.get_node("Objects/Village") as Village
	var street := Vector2i(30, -11)  # a walkable village cell over the farm's sea tiles
	check(village.is_cell_walkable(street), "fixture: the street is walkable village ground")
	check(not grid.is_water(street), "street is not water")
	check(not grid.is_tool_valid(G.ToolKind.FISHING_ROD, street), "no fishing on the street")
	check(not grid.is_tool_valid(G.ToolKind.HOE, street), "no hoeing the street")
	check(not grid.is_buildable(street), "no building on the street")
	var wet := 0
	for cell in grid.ground_layer.get_used_cells():
		if village.is_cell_walkable(cell) and (grid.is_water(cell) or grid.is_farmable(cell)):
			wet += 1
	eq(wet, 0, "no walkable village cell is water or farmable")
	await despawn_level()


func test_starter_layout_keeps_the_way_to_the_village_gate_open() -> void:
	await _spawn()
	var open := func(cell: Vector2i) -> bool:
		return grid.is_walkable_land(cell) and not grid.is_occupied(cell) and not grid.is_object_near_cell(cell) \
				and not grid._in_house(cell)
	var reach := GridSearch.flood(grid.cell_of(level.player.position), open)
	check(reach.has(Vector2i(28, -1)) or reach.has(Vector2i(28, 0)), "the gate approach is reachable from the house")
	await despawn_level()

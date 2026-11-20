extends TestCase
## FarmGrid cell maths, soil state, occupancy and the save round trip,
## exercised on a real instance of the level scene.

var level: Level
var grid: FarmGrid


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)  # the root is busy while the runner starts
	await tree.process_frame
	grid = level.farm_grid


func _despawn() -> void:
	level.free()
	await tree.process_frame


func test_level_exposes_grid_and_containers() -> void:
	await _spawn()
	check(grid != null, "farm_grid missing")
	check(level.is_in_group("Level"), "level not in group")
	for container: Node2D in [level.crops(), level.animals(), level.stations(), level.npcs(), level.gatherables()]:
		check(container != null, "container missing")
	await _despawn()


func test_cell_of_floors_negative_coordinates() -> void:
	await _spawn()
	eq(grid.cell_of(Vector2(0, 0)), Vector2i(0, 0), "origin")
	eq(grid.cell_of(Vector2(15.9, 16.0)), Vector2i(0, 1), "positive")
	eq(grid.cell_of(Vector2(-0.1, -16.1)), Vector2i(-1, -2), "negative")
	eq(grid.get_target_grid(Vector2(8, 8), Vector2(1, 0)), Vector2i(1, 0), "target in front")
	await _despawn()


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
	await _despawn()


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
	await _despawn()


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
	await _despawn()


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
	await _despawn()

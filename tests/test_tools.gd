extends TestCase
## Tool tiers: area effects (hoe, can, sickle), the area highlight and the rod's ease.

var level: Level
var grid: FarmGrid
var _start: Vector2i  ## Player cell; the swing targets _start + (1, 0) and _start + (2, 0).


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	grid = level.farm_grid
	Weather.set_today(G.WeatherKind.CLEAR)
	_start = _find_run()


func _despawn() -> void:
	level.free()
	await tree.process_frame


## A cell whose two eastern neighbours are farmable, dry, free and untilled.
func _find_run() -> Vector2i:
	for cell in grid.ground_layer.get_used_cells():
		if _hoeable(cell + Vector2i(1, 0)) and _hoeable(cell + Vector2i(2, 0)):
			return cell
	return Vector2i.ZERO


func _hoeable(cell: Vector2i) -> bool:
	return grid.is_tool_valid(G.ToolKind.HOE, cell) and not grid.is_tilled(cell)


func _swing(action: int, item_id: StringName) -> void:
	level.player.action_item = Content.item(item_id)
	var pos := Vector2(_start * 16) + Vector2(8, 8)
	level._on_player_tool_use(action, pos, Vector2.RIGHT)


func _first() -> Vector2i:
	return _start + Vector2i(1, 0)


func _second() -> Vector2i:
	return _start + Vector2i(2, 0)


func test_tier_rows_carry_the_effects() -> void:
	var wooden := Content.tool_tier(&"wooden")
	var iron := Content.tool_tier(&"iron_shod")
	eq(wooden.area, 1, "wooden area")
	eq(iron.area, 2, "iron area")
	check(iron.bonus_logs > wooden.bonus_logs, "iron gives more logs")
	check(iron.fishing_ease > wooden.fishing_ease, "iron rod is more forgiving")
	eq(ToolArea.cells(G.ToolKind.HOE, iron, Vector2i(3, 3), Vector2i(1, 0)).size(), 2, "hoe covers two")
	eq(ToolArea.cells(G.ToolKind.AXE, iron, Vector2i(3, 3), Vector2i(1, 0)).size(), 1, "axe is single cell")
	eq(ToolArea.cells(G.ToolKind.HOE, null, Vector2i(3, 3), Vector2i(1, 0)).size(), 1, "no tier, one cell")


func test_iron_hoe_tills_two_cells_wooden_one() -> void:
	await _spawn()
	_swing(G.ToolKind.HOE, &"hoe_wooden")
	check(grid.is_tilled(_first()), "wooden tills target")
	check(not grid.is_tilled(_second()), "wooden leaves the next cell")
	_swing(G.ToolKind.HOE, &"hoe_iron_shod")
	check(grid.is_tilled(_second()), "iron tills the next cell")
	await _despawn()


func test_invalid_second_cell_is_skipped() -> void:
	await _spawn()
	grid.crop_field.sow(_second(), &"wheat")  # a crop without weeds: the hoe is invalid there
	_swing(G.ToolKind.HOE, &"hoe_iron_shod")
	check(grid.is_tilled(_first()), "valid first cell tilled")
	check(not grid.is_tilled(_second()), "occupied second cell skipped")
	await _despawn()


func test_iron_can_waters_two_cells() -> void:
	await _spawn()
	grid.till(_first())
	grid.till(_second())
	_swing(G.ToolKind.WATERING_CAN, &"watering_can_wooden")
	check(grid.is_wet(_first()) and not grid.is_wet(_second()), "wooden waters one")
	grid.dry_all()
	_swing(G.ToolKind.WATERING_CAN, &"watering_can_iron_shod")
	check(grid.is_wet(_first()) and grid.is_wet(_second()), "iron waters two")
	grid.dry_all()
	grid.soil_layer.erase_cell(_second())
	_swing(G.ToolKind.WATERING_CAN, &"watering_can_iron_shod")
	check(grid.is_wet(_first()) and not grid.is_wet(_second()), "untilled cell skipped")
	await _despawn()


func test_iron_sickle_reaps_each_ripe_cell() -> void:
	await _spawn()
	for cell in [_first(), _second()]:
		grid.till(cell)
		var crop := grid.crop_field.sow(cell, &"wheat")
		crop.age = crop.data.days_to_mature
	_swing(G.ToolKind.SICKLE, &"sickle_wooden")
	check(grid.crop_field.crop_at(_first()) == null, "wooden reaps the first")
	check(grid.crop_field.crop_at(_second()) != null, "wooden leaves the second")
	grid.crop_field.sow(_first(), &"wheat")  # young: not ripe, must be skipped
	_swing(G.ToolKind.SICKLE, &"sickle_iron_shod")
	check(grid.crop_field.crop_at(_second()) == null, "iron reaps the ripe second cell")
	check(grid.crop_field.crop_at(_first()) != null, "unripe first cell skipped")
	await _despawn()


func test_highlight_covers_every_affected_cell() -> void:
	await _spawn()
	var pos := Vector2(_start * 16) + Vector2(8, 8)
	var iron := Content.tool_tier(&"iron_shod")
	grid.update_highlight(pos, Vector2.RIGHT, G.ToolKind.HOE, iron)
	check(grid.target_layer.get_cell_source_id(_first()) != -1, "first cell lit")
	check(grid.target_layer.get_cell_source_id(_second()) != -1, "second cell lit")
	grid.update_highlight(pos, Vector2.RIGHT, G.ToolKind.HOE, Content.tool_tier(&"wooden"))
	check(grid.target_layer.get_cell_source_id(_second()) == -1, "wooden lights one cell")
	await _despawn()


func test_iron_rod_makes_the_minigame_more_forgiving() -> void:
	await _spawn()
	var game: Node = level.player.get_node("FishingGame")
	level.player.start_fishing(1.0)
	var base: float = game.catch_speed / game.FISH_KINDS[game.fish_kind]["catch_speed"]
	level.player.start_fishing(Content.tool_tier(&"iron_shod").fishing_ease)
	var eased: float = game.catch_speed / game.FISH_KINDS[game.fish_kind]["catch_speed"]
	near(base, 1.0, 0.001, "wooden factor")
	check(eased > base, "iron catches faster")
	check(game.lose_speed < game.FISH_KINDS[game.fish_kind]["lose_speed"], "iron loses slower")
	await _despawn()

class_name FarmGrid extends Node
## Owns everything about the tile grid: terrain queries, tilled/wet soil,
## cell occupancy (crops and placeables) and the target highlight.
## Cells are Vector2i grid coordinates, cell = floor(world_pos / Data.TILE_SIZE).
## `is_tool_valid` is the single authority on whether a tool works on a cell.

const HIGHLIGHT_GREEN := Vector2i(12, 1)
const HIGHLIGHT_RED := Vector2i(1, 1)
const SOIL_TERRAIN_SET := 0
const SOIL_TERRAIN := 1
const WET_VARIANTS := 3

@export var ground_layer: TileMapLayer  ## Terrain with custom data `water` / `farmable`.
@export var soil_layer: TileMapLayer  ## Tilled cells.
@export var wet_layer: TileMapLayer  ## Watered cells, cleared by dry_all().
@export var target_layer: TileMapLayer  ## Green/red highlight.
@export var house: Node2D  ## Needs is_point_inside_house(cell: Vector2).

var _occupants: Dictionary = {}  # Vector2i -> Node (untyped: entries may be freed)
var _last_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	GameClock.day_ending.connect(_on_day_ending)
	GameClock.day_passed.connect(_on_day_passed)


# ---------------------------------------------------------------- cells

## Grid cell containing a world position.
func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / Data.TILE_SIZE), floori(world_pos.y / Data.TILE_SIZE))


## Cell in front of `pos` in direction `dir`. A zero `dir` reuses the last non-zero one.
func get_target_grid(pos: Vector2, dir: Vector2) -> Vector2i:
	if dir != Vector2.ZERO:
		_last_dir = dir
	else:
		dir = _last_dir
	return cell_of(pos) + Vector2i(dir)


## True if the ground tile is water.
func is_water(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("water")


func is_farmable(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("farmable")


# ---------------------------------------------------------------- soil

func is_tilled(cell: Vector2i) -> bool:
	return soil_layer.get_cell_source_id(cell) != -1


func is_wet(cell: Vector2i) -> bool:
	return wet_layer.get_cell_source_id(cell) != -1


## Hoe the cell (connects to neighbouring tilled cells).
func till(cell: Vector2i) -> void:
	soil_layer.set_cells_terrain_connect([cell], SOIL_TERRAIN_SET, SOIL_TERRAIN)


## Water one cell.
func water(cell: Vector2i) -> void:
	wet_layer.set_cell(cell, 0, Vector2i(randi_range(0, WET_VARIANTS - 1), 0))


## Water every tilled cell (rain).
func water_all() -> void:
	for cell in soil_layer.get_used_cells():
		water(cell)


## Clear all wet soil (done every evening after crops resolve).
func dry_all() -> void:
	wet_layer.clear()


func tilled_cells() -> Array[Vector2i]:
	return soil_layer.get_used_cells()


func wet_cells() -> Array[Vector2i]:
	return wet_layer.get_used_cells()


# ---------------------------------------------------------------- occupancy

## Mark a cell as occupied by `node` (a crop, placeable, ...).
func occupy(cell: Vector2i, node: Node) -> void:
	_occupants[cell] = node


## Free a cell.
func release(cell: Vector2i) -> void:
	_occupants.erase(cell)


## The node occupying a cell, or null. Freed nodes count as absent.
func occupant(cell: Vector2i) -> Node:
	var node: Variant = _occupants.get(cell)
	if not is_instance_valid(node):  # also true for null and freed nodes
		_occupants.erase(cell)
		return null
	return node as Node


func is_occupied(cell: Vector2i) -> bool:
	return occupant(cell) != null


## Whether a placeable may be built on `cell`: dry land, outside the house,
## not under a tree/object footprint and not occupied.
func is_free_for_placement(cell: Vector2i) -> bool:
	if _in_house(cell) or is_occupied(cell) or is_object_near_cell(cell):
		return false
	return ground_layer.get_cell_tile_data(cell) != null and not is_water(cell)


## True if the cell falls inside the footprint of any node in group "Objects"
## (trees: 3x3 bottom-centre, others: 2x2 top-left).
func is_object_near_cell(cell: Vector2i) -> bool:
	for object: Node2D in get_tree().get_nodes_in_group("Objects"):
		var origin := cell_of(object.position)
		if object.is_in_group("Tree"):
			if absi(cell.x - origin.x) <= 1 and cell.y >= origin.y - 2 and cell.y <= origin.y:
				return true
		elif cell.x >= origin.x and cell.x <= origin.x + 1 and cell.y >= origin.y and cell.y <= origin.y + 1:
			return true
	return false


# ---------------------------------------------------------------- day end

## Evening: crops resolve against today's wet state, THEN the watering clears.
func _on_day_ending(_day: int) -> void:
	for plant: StaticBody2D in get_tree().get_nodes_in_group("Plants"):
		plant.grow(is_wet(plant.coord))
	dry_all()


## Morning: rain waters every tilled cell.
func _on_day_passed(_day: int) -> void:
	if Weather.is_raining():
		water_all()


# ---------------------------------------------------------------- tools

## Single authority on whether `tool` can be used on `cell`.
func is_tool_valid(tool: Enum.Tool, cell: Vector2i) -> bool:
	if _in_house(cell) or ground_layer.get_cell_tile_data(cell) == null:
		return false
	match tool:
		Enum.Tool.HOE:
			return is_farmable(cell) and not is_water(cell) and not is_object_near_cell(cell)
		Enum.Tool.WATER:
			return is_tilled(cell)
		Enum.Tool.FISH:
			return is_water(cell)
		Enum.Tool.SEED:
			return is_tilled(cell) and not is_occupied(cell)
		Enum.Tool.AXE, Enum.Tool.SWORD:
			return true
	return false


## Draw the green/red highlight for the cell targeted by a player at `pos` facing `dir`.
func update_highlight(pos: Vector2, dir: Vector2, tool: Enum.Tool) -> void:
	if dir == Vector2.ZERO and _last_dir == Vector2.ZERO:
		target_layer.clear()
		return
	var cell := get_target_grid(pos, dir)
	target_layer.clear()
	target_layer.set_cell(cell, 0, HIGHLIGHT_GREEN if is_tool_valid(tool, cell) else HIGHLIGHT_RED)


func clear_highlight() -> void:
	target_layer.clear()


# ---------------------------------------------------------------- save data

## Serialise tilled and wet cells as arrays of [x, y].
func to_dict() -> Dictionary:
	return {"tilled": _cells_to_pairs(tilled_cells()), "wet": _cells_to_pairs(wet_cells())}


## Restore tilled and wet cells from to_dict() output (replaces current soil).
func from_dict(data: Dictionary) -> void:
	soil_layer.clear()
	wet_layer.clear()
	var tilled := _pairs_to_cells(data.get("tilled", []))
	if not tilled.is_empty():
		soil_layer.set_cells_terrain_connect(tilled, SOIL_TERRAIN_SET, SOIL_TERRAIN)
	for cell in _pairs_to_cells(data.get("wet", [])):
		water(cell)


func _in_house(cell: Vector2i) -> bool:
	return house != null and house.is_point_inside_house(Vector2(cell))


static func _cells_to_pairs(cells: Array[Vector2i]) -> Array:
	var pairs: Array = []
	for cell in cells:
		pairs.append([cell.x, cell.y])
	return pairs


static func _pairs_to_cells(pairs: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair: Array in pairs:
		cells.append(Vector2i(int(pair[0]), int(pair[1])))
	return cells

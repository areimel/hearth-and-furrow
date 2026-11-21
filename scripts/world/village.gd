class_name Village
extends Node2D
## Village district root (baked by tools/bake_village.gd). Holds the baked walkability grid,
## opens the gate in the farm's east shore on load and answers path queries between places.

const TILE := 16
const GRASS_COST := 4.0  ## Route weight of grass relative to dirt path, so NPCs prefer the paths.

@export var origin_cell: Vector2i  ## World cell of walk grid cell (0, 0).
@export var grid_size: Vector2i
@export var walkable: PackedByteArray  ## Row-major, grid_size.x per row: 0 blocked, 1 grass, 2 dirt path.
@export var farm_gap_cells: Array[Vector2i] = []  ## Farm ground cells erased so the gate is open.
@export var bounds: Rect2  ## Village land in world pixels.

var _astar := AStarGrid2D.new()


func _ready() -> void:
	add_to_group(&"Village")
	_build_astar()
	_open_farm_gap()


## True when the world cell is inside the village grid and walkable.
func is_cell_walkable(world_cell: Vector2i) -> bool:
	var c := world_cell - origin_cell
	if c.x < 0 or c.y < 0 or c.x >= grid_size.x or c.y >= grid_size.y:
		return false
	return walkable[c.y * grid_size.x + c.x] > 0


func is_point_walkable(global_pos: Vector2) -> bool:
	return is_cell_walkable(Vector2i((to_local(global_pos) / TILE).floor()))


## Walkable polyline (global pixels) between two global points, following the baked grid.
## Returns an empty array when either end cannot be snapped to the grid or no route exists.
func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _snap(Vector2i((to_local(from) / TILE).floor()))
	var b := _snap(Vector2i((to_local(to) / TILE).floor()))
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var ids := _astar.get_id_path(a - origin_cell, b - origin_cell)
	var out := PackedVector2Array()
	for i in ids.size():
		var pt := Vector2(ids[i] + origin_cell) * TILE + Vector2(TILE, TILE) / 2.0
		if out.size() >= 2 and i < ids.size() - 1:
			var d1 := (out[out.size() - 1] - out[out.size() - 2]).normalized()
			if d1.is_equal_approx((pt - out[out.size() - 1]).normalized()):
				out[out.size() - 1] = pt
				continue
		out.append(pt)
	for i in out.size():
		out[i] = to_global(out[i])
	return out


func _build_astar() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in grid_size.y:
		for x in grid_size.x:
			var kind := walkable[y * grid_size.x + x]
			_astar.set_point_solid(Vector2i(x, y), kind == 0)
			_astar.set_point_weight_scale(Vector2i(x, y), 1.0 if kind == 2 else GRASS_COST)


## Nearest walkable world cell within 3 cells, or (-1, -1) when none.
func _snap(cell: Vector2i) -> Vector2i:
	return GridSearch.nearest(cell, 3, is_cell_walkable, Vector2i(-1, -1))


## The farm's shore tiles collide; erase the gate cells so the player can walk through.
func _open_farm_gap() -> void:
	var node: Node = self
	while node != null:
		var layer := node.get_node_or_null("Layers/WaterGrassLayer") as TileMapLayer
		if layer != null:
			for cell in farm_gap_cells:
				layer.erase_cell(cell)
			return
		node = node.get_parent()

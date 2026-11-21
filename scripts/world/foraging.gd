class_name Foraging extends Node2D
## Feature root for gathering nodes. Add scenes/world/foraging.tscn as a child of Level:
## it spawns Gatherables into `level.gatherables()`, scatters them on a new game
## (seeded, so a world looks the same on every machine) and registers with SaveManager
## under `foraging`. Extra spawn areas: any Marker2D in group `ForageArea` with metadata
## `gatherable_id` and `count` (and optional `radius` in pixels, default 48) gets that many
## nodes scattered around it on a new game.

const Balance := preload("res://data/balance.gd")
const SAVE_KEY := &"foraging"
const AREA_GROUP := &"ForageArea"
## Used when Weather.world_seed is still 0.
const FALLBACK_SEED := 1530

var _wait_frames: int = 0
## Closest two nodes may sit (cells, Chebyshev).
const MIN_SPACING := 3
## Cells kept clear around the house and around the animal pen centre.
const HOUSE_CLEARANCE := 2
const PEN_CLEARANCE := 5
const DEFAULT_AREA_RADIUS := 48.0

var _level: Level
var _grid: FarmGrid
var _nodes: Array[Gatherable] = []
var _started: bool = false
var _pending: Dictionary = {}
var _has_pending: bool = false


func _ready() -> void:
	_level = get_parent() as Level
	SaveManager.register(SAVE_KEY, self)
	_start.call_deferred()


func _exit_tree() -> void:
	if SaveManager.is_registered(SAVE_KEY):
		SaveManager.unregister(SAVE_KEY)


# ---------------------------------------------------------------- API

## Every live gathering node.
func nodes() -> Array[Gatherable]:
	return _nodes.filter(is_instance_valid)


## How many nodes of kind `id` are ready to gather right now.
func count_ready(id: StringName) -> int:
	return nodes().filter(func(n: Gatherable) -> bool:
		return n.gatherable_id == id and n.is_ripe()).size()


## The node standing on `cell`, or null.
func node_at(cell: Vector2i) -> Gatherable:
	for node in nodes():
		if node.coord == cell:
			return node
	return null


## Place one node of kind `id` on `cell` (no validity check). Null before the level exists.
func place(id: StringName, cell: Vector2i) -> Gatherable:
	if _level == null or not _known(id):
		return null
	var node := Gatherable.create(id)
	node.setup(cell, _level, _level.gatherables())
	_nodes.append(node)
	return node


## Scatter `count` nodes of kind `id` over the whole map using `rng`. Returns how many fit.
func scatter(id: StringName, count: int, rng: RandomNumberGenerator) -> int:
	return _scatter(id, count, rng, _all_cells(), false)


## Scatter around a ForageArea marker (metadata `gatherable_id`, `count`, `radius`).
func scatter_area(marker: Node2D, rng: RandomNumberGenerator) -> int:
	var id := StringName(marker.get_meta(&"gatherable_id", &""))
	if not _known(id):
		return 0
	var radius := float(marker.get_meta(&"radius", DEFAULT_AREA_RADIUS))
	var cells: Array[Vector2i] = []
	for cell in _all_cells():
		if (Vector2(cell * Balance.TILE_SIZE) + Vector2.ONE * 8.0).distance_to(marker.global_position) <= radius:
			cells.append(cell)
	return _scatter(id, int(marker.get_meta(&"count", 1)), rng, cells, true)


# ---------------------------------------------------------------- save

## Snapshot of every node.
func to_dict() -> Dictionary:
	var list: Array = []
	for node in nodes():
		list.append(node.to_dict())
	return {"nodes": list}


## Replace the nodes with the saved ones; an empty dict scatters a fresh world.
func from_dict(data: Dictionary) -> void:
	if not _started:
		_pending = data
		_has_pending = true
		return
	_clear()
	if data.is_empty():
		_scatter_world()
		return
	for entry: Dictionary in data.get("nodes", []):
		var id := StringName(entry.get("id", &""))
		var node := place(id, entry.get("cell", Vector2i.ZERO))
		if node != null:
			node.from_dict(entry)


## New game: remove everything and scatter a fresh world.
func reset() -> void:
	_clear()
	_scatter_world()


# ---------------------------------------------------------------- scattering

func _start() -> void:
	if _level == null:
		return
	# Livestock and Workstations claim their ground one frame after the Level is ready,
	# so wait two frames. Counted in _process: an `await` would resume on a freed node.
	_wait_frames = 2
	set_process(true)


func _process(_delta: float) -> void:
	if _started or _level == null:
		set_process(false)
		return
	_wait_frames -= 1
	if _wait_frames > 0:
		return
	set_process(false)
	_grid = _level.farm_grid
	_started = true
	if _has_pending:
		from_dict(_pending)
	elif _nodes.is_empty():
		_scatter_world()


func _scatter_world() -> void:
	if not _started:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Weather.world_seed if Weather.world_seed != 0 else FALLBACK_SEED, SAVE_KEY])
	for row in Content.gatherables():
		_scatter(row.id, row.scatter_count, rng, _all_cells(), false)
	for marker: Node2D in get_tree().get_nodes_in_group(AREA_GROUP):
		scatter_area(marker, rng)


func _all_cells() -> Array[Vector2i]:
	var cells := _grid.ground_layer.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func _scatter(id: StringName, count: int, rng: RandomNumberGenerator, cells: Array[Vector2i],
		relaxed: bool) -> int:
	if _grid == null or not _known(id):
		return 0
	var row := Content.gatherable(id)
	var order := cells.duplicate()
	for i in range(order.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var swap: Vector2i = order[i]
		order[i] = order[j]
		order[j] = swap
	var placed := 0
	# First pass keeps to non-farmable ground; the second accepts farmable cells too.
	for strict in ([false] if relaxed else [true, false]):
		for cell: Vector2i in order:
			if placed >= count:
				return placed
			if _valid(cell, row, strict) and place(id, cell) != null:
				placed += 1
	return placed


func _valid(cell: Vector2i, row: GatherableData, strict: bool) -> bool:
	if strict and _grid.is_farmable(cell):
		return false
	if not _grid.is_free_for_placement(cell) or _grid.is_tilled(cell):
		return false
	if row.placement == GatherableData.PLACE_NEAR_WATER and not _beside_water(cell):
		return false
	return _clear_above(cell, row) and _clear_of_neighbours(cell) and not _near_house(cell) \
			and not _near_pen(cell)


## Tall sprites (taller than one cell) need dry ground under their upper part too.
func _clear_above(cell: Vector2i, row: GatherableData) -> bool:
	var extra := ceili(row.full_texture.get_height() / float(Balance.TILE_SIZE)) - 1
	for i in range(1, extra + 1):
		var above := cell + Vector2i(0, -i)
		if _grid.ground_layer.get_cell_tile_data(above) == null or _grid.is_water(above) \
				or _grid.is_occupied(above):
			return false
	return true


func _beside_water(cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _grid.is_water(cell + step):
			return true
	return false


## No other node within MIN_SPACING and nothing (station, crop) on the eight neighbours.
func _clear_of_neighbours(cell: Vector2i) -> bool:
	for node in _nodes:
		if is_instance_valid(node) and maxi(absi(node.coord.x - cell.x), absi(node.coord.y - cell.y)) < MIN_SPACING:
			return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _grid.is_occupied(cell + Vector2i(dx, dy)):
				return false
	return true


func _near_house(cell: Vector2i) -> bool:
	if _grid.house == null:
		return false
	for dx in range(-HOUSE_CLEARANCE, HOUSE_CLEARANCE + 1):
		for dy in range(-HOUSE_CLEARANCE, HOUSE_CLEARANCE + 1):
			if _grid.house.is_point_inside_house(Vector2(cell + Vector2i(dx, dy))):
				return true
	return false


## True within PEN_CLEARANCE cells of a sibling feature's `pen_center()` (the animal pen).
func _near_pen(cell: Vector2i) -> bool:
	for sibling in _level.get_children():
		if sibling.has_method(&"pen_center"):
			var pen := _grid.cell_of(sibling.pen_center())
			if maxi(absi(pen.x - cell.x), absi(pen.y - cell.y)) <= PEN_CLEARANCE:
				return true
	return false


func _known(id: StringName) -> bool:
	return Content.Gatherables.ROWS.has(id)


func _clear() -> void:
	for node in nodes():
		node.free()  # immediate, so the cells are released before a re-scatter
	_nodes.clear()

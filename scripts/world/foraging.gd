class_name Foraging extends LevelFeature
## Feature root for gathering nodes. Add scenes/world/foraging.tscn as a child of Level:
## it spawns Gatherables into `level.gatherables()`, scatters them on a new game
## (seeded, so a world looks the same on every machine, and only onto ground the player can
## walk to) and saves under `foraging`. Extra spawn areas: any Marker2D in group
## `ForageArea` with metadata `gatherable_id` and `count` (and optional `radius` in pixels,
## default 48) gets that many nodes scattered around it on a new game.

const AREA_GROUP := &"ForageArea"
## Used when Weather.world_seed is still 0.
const FALLBACK_SEED := 1530

## Closest two nodes may sit (cells, Chebyshev).
const MIN_SPACING := 3
## Cells kept clear around the house and around the animal pen centre.
const HOUSE_CLEARANCE := 2
const PEN_CLEARANCE := 5
const DEFAULT_AREA_RADIUS := 48.0
## How far (cells) from open water a PLACE_NEAR_WATER node may sit.
const WATER_REACH := 2

var _grid: FarmGrid
var _nodes: Array[Gatherable] = []
var _known_ids: Dictionary = {}  # gatherable id -> true, built on first use
var _reachable: Dictionary = {}  # Vector2i -> true: land cells connected to the player's spawn


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
	if level == null or not _known(id):
		return null
	var node := Gatherable.create(id)
	node.setup(cell, level, level.gatherables())
	_nodes.append(node)
	return node


## Scatter `count` nodes of kind `id` over the reachable ground using `rng`. Returns how many fit.
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


## Place the saved nodes; an empty dict scatters a fresh world.
func _restore(data: Dictionary) -> void:
	if data.is_empty():
		_new_game_setup()
		return
	for entry: Dictionary in data.get("nodes", []):
		var node := place(StringName(entry.get("id", &"")), entry.get("cell", Vector2i.ZERO))
		if node != null:
			node.from_dict(entry)


# ---------------------------------------------------------------- scattering

func _on_level_ready() -> void:
	_grid = level.farm_grid
	_reachable = GridSearch.flood(_grid.cell_of(level.player.position), _grid.is_walkable_land)


## New game: scatter every gatherable row, then the ForageArea markers.
func _new_game_setup() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Weather.world_seed if Weather.world_seed != 0 else FALLBACK_SEED, save_key])
	for row in Content.gatherables():
		_scatter(row.id, row.scatter_count, rng, _all_cells(), false)
	for marker: Node2D in get_tree().get_nodes_in_group(AREA_GROUP):
		scatter_area(marker, rng)


## Reachable ground cells in a fixed (row-major) order so a seed gives the same world.
func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_reachable.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func _scatter(id: StringName, count: int, rng: RandomNumberGenerator, cells: Array[Vector2i],
		relaxed: bool) -> int:
	if _grid == null or not _known(id):
		return 0
	var row := Content.gatherable(id)
	var order := cells.duplicate()
	GridSearch.shuffle(order, rng)
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


## Open water within WATER_REACH cells. Shore tiles (which block walking) ring the water,
## so the nearest reachable land is usually two cells from it.
func _beside_water(cell: Vector2i) -> bool:
	for r in range(1, WATER_REACH + 1):
		for c in GridSearch.ring(cell, r):
			if _grid.is_water(c):
				return true
	return false


## No other node within MIN_SPACING and nothing (station, crop) on the eight neighbours.
func _clear_of_neighbours(cell: Vector2i) -> bool:
	for node in _nodes:
		if is_instance_valid(node) and GridSearch.chebyshev(node.coord, cell) < MIN_SPACING:
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
	for sibling in level.get_children():
		if sibling.has_method(&"pen_center"):
			var pen := _grid.cell_of(sibling.pen_center())
			if GridSearch.chebyshev(pen, cell) <= PEN_CLEARANCE:
				return true
	return false


func _known(id: StringName) -> bool:
	if _known_ids.is_empty():
		for row in Content.gatherables():
			_known_ids[row.id] = true
	return _known_ids.has(id)


func _clear() -> void:
	for node in nodes():
		node.free()  # immediate, so the cells are released before a re-scatter
	_nodes.clear()

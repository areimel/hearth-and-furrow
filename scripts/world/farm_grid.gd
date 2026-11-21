class_name FarmGrid extends LevelFeature
## Owns everything about the tile grid: terrain queries, tilled/wet soil,
## cell occupancy (crops and placeables), the crop field and the target highlight.
## Cells are Vector2i grid coordinates, cell = floor(world_pos / Balance.TILE_SIZE).
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
@export var crop_field: CropField  ## Owns the planted crops; resolved each evening.

var _village: Village  ## Found by group on first use; its walkable cells are land, not terrain.
var _occupants: Dictionary = {}  # Vector2i -> Node (untyped: entries may be freed)
var _last_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	GameClock.day_ending.connect(_on_day_ending)
	GameClock.day_passed.connect(_on_day_passed)


# ---------------------------------------------------------------- cells

## Grid cell containing a world position.
func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / Balance.TILE_SIZE), floori(world_pos.y / Balance.TILE_SIZE))


## Cell in front of `pos` in direction `dir`. A zero `dir` reuses the last non-zero one.
func get_target_grid(pos: Vector2, dir: Vector2) -> Vector2i:
	if dir != Vector2.ZERO:
		_last_dir = dir
	else:
		dir = _last_dir
	return cell_of(pos) + Vector2i(dir)


## True if the cell is open water. The farm's sea tiles run under the village, so cells in
## the village's walkable area are land (never water, farmable, buildable or fishable).
func is_water(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("water") and not in_village(cell)


func is_farmable(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("farmable") and not in_village(cell)


## True if `cell` lies on the village's walkable ground (the street, the green, the gate).
func in_village(cell: Vector2i) -> bool:
	if _village == null or not is_instance_valid(_village):
		_village = get_tree().get_first_node_in_group(&"Village") as Village
	return _village != null and _village.is_cell_walkable(cell)


## True if the player could stand on the farm cell: ground without water or a collision shape.
func is_walkable_land(cell: Vector2i) -> bool:
	var data := ground_layer.get_cell_tile_data(cell)
	return data != null and not is_water(cell) and not in_village(cell) \
			and data.get_collision_polygons_count(0) == 0


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
	return ground_layer.get_cell_tile_data(cell) != null and not is_water(cell) and not in_village(cell)


## Whether a station or other structure may be built on `cell`: free for placement and
## not tilled (crops and other occupants already block through occupancy).
func is_buildable(cell: Vector2i) -> bool:
	return is_free_for_placement(cell) and not is_tilled(cell)


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
	crop_field.resolve_day()
	dry_all()


## Morning: rain waters every tilled cell.
func _on_day_passed(_day: int) -> void:
	if Weather.is_raining():
		water_all()


# ---------------------------------------------------------------- tools

## Single authority on whether `action` (a G.ToolKind, or PlayerActions.SOW) can be used
## on `cell`. Sowing only checks the soil; Level checks the seed.
func is_tool_valid(action: int, cell: Vector2i) -> bool:
	if _in_house(cell) or ground_layer.get_cell_tile_data(cell) == null:
		return false
	if occupant(cell) is Placeable:
		return false
	var crop := crop_field.crop_at(cell)
	match action:
		G.ToolKind.HOE:
			if crop != null:
				return crop.weeds > 0
			return is_farmable(cell) and not is_water(cell) and not is_object_near_cell(cell)
		G.ToolKind.WATERING_CAN:
			return is_tilled(cell)
		G.ToolKind.FISHING_ROD:
			return is_water(cell)
		PlayerActions.SOW:
			return is_tilled(cell) and not is_occupied(cell)
		G.ToolKind.SICKLE:
			return crop != null and crop.is_ripe()
		G.ToolKind.AXE:
			return true
	return false


## Draw the highlight for every cell a swing of `action` by a player at `pos` facing `dir`
## will affect: the target cell is green or red, further cells of an area tool are shown
## only where valid. `tier` is the swung tool's tier (null = single cell).
func update_highlight(pos: Vector2, dir: Vector2, action: int, tier: ToolTierData = null) -> void:
	if dir == Vector2.ZERO and _last_dir == Vector2.ZERO:
		target_layer.clear()
		return
	var cell := get_target_grid(pos, dir)
	target_layer.clear()
	var covered := ToolArea.cells(action, tier, cell, cell - cell_of(pos))
	for i in covered.size():
		var valid := is_tool_valid(action, covered[i])
		if valid or i == 0:
			target_layer.set_cell(covered[i], 0, HIGHLIGHT_GREEN if valid else HIGHLIGHT_RED)


## Highlight just `cell`, green when `valid` (build mode).
func highlight_cell(cell: Vector2i, valid: bool) -> void:
	target_layer.clear()
	target_layer.set_cell(cell, 0, HIGHLIGHT_GREEN if valid else HIGHLIGHT_RED)


func clear_highlight() -> void:
	target_layer.clear()


# ---------------------------------------------------------------- save data

## The `farm` save section: tilled and wet cells as [x, y] pairs, plus every crop.
func to_dict() -> Dictionary:
	return {"tilled": GridSearch.cells_to_pairs(tilled_cells()), "wet": GridSearch.cells_to_pairs(wet_cells()),
			"crops": crop_field.to_dict()}


## Restore from to_dict() output (replaces soil and crops). Accepts `{}`.
func _restore(data: Dictionary) -> void:
	soil_layer.clear()
	wet_layer.clear()
	var tilled := GridSearch.pairs_to_cells(data.get("tilled", []))
	if not tilled.is_empty():
		soil_layer.set_cells_terrain_connect(tilled, SOIL_TERRAIN_SET, SOIL_TERRAIN)
	for cell in GridSearch.pairs_to_cells(data.get("wet", [])):
		water(cell)
	crop_field.from_dict(data.get("crops", []))


## New game: bare soil and no crops.
func _new_game_setup() -> void:
	_restore({})


func _in_house(cell: Vector2i) -> bool:
	return house != null and house.is_point_inside_house(Vector2(cell))

class_name Workstations extends Node
## Feature root for crafting stations. Add scenes/world/workstations.tscn as a child of
## Level: it spawns Stations into level.stations(), lays out a starter yard on a new
## game, saves them under `stations`, and opens the crafting screen on interaction.

## Group of the crafting screen (found, or created under the first CanvasLayer).
const SCREEN_GROUP := &"CraftingScreen"
const SCREEN_SCENE := preload("res://scenes/ui/crafting_screen.tscn")
## Stations per row of the starter yard and the cell gap between stations.
const YARD_COLUMNS := 4
const YARD_SPACING := 2

## The starter yard is laid out as close to this cell as free ground allows.
@export var anchor_cell: Vector2i = Vector2i(19, -8)
## Place the starter yard when a new game begins.
@export var starter_yard: bool = true
## Largest ring searched around the anchor.
@export var search_radius: int = 30

var _level: Level
var _stations: Array[Station] = []
var _screen: CraftingScreen


func _ready() -> void:
	SaveManager.register(&"stations", self)
	_bind.call_deferred()


func _exit_tree() -> void:
	if SaveManager.is_registered(&"stations"):
		SaveManager.unregister(&"stations")


# ---------------------------------------------------------------- API

## All live stations.
func stations() -> Array[Station]:
	return _stations.duplicate()


## The station standing on `cell`, or null.
func station_at(cell: Vector2i) -> Station:
	for station in _stations:
		if station.coord == cell:
			return station
	return null


## Place a station of type `station_id` on `cell` (no cost, no free-cell check beyond
## the grid claiming it). Null if there is no level yet.
func place(station_id: StringName, cell: Vector2i) -> Station:
	if _level == null:
		return null
	var station := Station.create(station_id)
	station.setup(cell, _level, _level.stations())
	station.interaction_requested.connect(_open_screen)
	station.tree_exited.connect(_forget.bind(station))
	_stations.append(station)
	return station


## Remove the station on `cell` (its output is lost). True if there was one.
func remove(cell: Vector2i) -> bool:
	var station := station_at(cell)
	if station == null:
		return false
	_stations.erase(station)
	station.remove()
	return true


## True if the Inventory holds the station's build cost.
func can_afford_build(station_id: StringName) -> bool:
	var row := Content.station(station_id)
	if row == null:
		return false
	for id: StringName in row.build_cost:
		if not Inventory.has(id, int(row.build_cost[id])):
			return false
	return true


## Pay the build cost and place the station; null if unaffordable or the cell is
## not free for placement.
func build(station_id: StringName, cell: Vector2i) -> Station:
	if _level == null or not can_afford_build(station_id):
		return null
	if not _level.farm_grid.is_free_for_placement(cell):
		return null
	var row := Content.station(station_id)
	for id: StringName in row.build_cost:
		Inventory.remove(id, int(row.build_cost[id]))
	return place(station_id, cell)


# ---------------------------------------------------------------- save

## Save section: every station's id, cell, jobs and waiting output.
func to_dict() -> Dictionary:
	var list: Array = []
	for station in _stations:
		list.append(station.to_dict())
	return {"stations": list}


## Replace all stations with the saved ones.
func from_dict(data: Dictionary) -> void:
	_clear()
	if _level == null:
		return
	for entry: Dictionary in data.get("stations", []):
		var id := StringName(entry.get("id", ""))
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		if Content.station(id) == null:
			continue
		var station := place(id, cell)
		if station:
			station.from_dict(entry)


## New game: drop everything and lay out the starter yard again.
func reset() -> void:
	_clear()
	if _level and starter_yard:
		_place_starter_yard()


# ---------------------------------------------------------------- internals

func _bind() -> void:
	_level = get_parent() as Level
	if _level == null:
		_level = get_tree().get_first_node_in_group("Level") as Level
	if _level and _stations.is_empty() and starter_yard:
		_place_starter_yard()


func _clear() -> void:
	for station in _stations.duplicate():
		station.tree_exited.disconnect(_forget.bind(station))
		station.free()
	_stations.clear()


func _forget(station: Station) -> void:
	_stations.erase(station)


func _place_starter_yard() -> void:
	var rows := ceili(float(Content.stations().size()) / YARD_COLUMNS)
	var origin := _find_origin(rows)
	var i := 0
	for row in Content.stations():
		var cell := origin + Vector2i(i % YARD_COLUMNS, i / YARD_COLUMNS) * YARD_SPACING
		if not _usable(cell):
			cell = _nearest_free(cell)
		place(row.id, cell)
		i += 1


## Nearest block origin to the anchor where every yard cell is usable.
func _find_origin(rows: int) -> Vector2i:
	for radius in search_radius + 1:
		for cell in _ring(anchor_cell, radius):
			if _block_usable(cell, rows):
				return cell
	return anchor_cell


func _block_usable(origin: Vector2i, rows: int) -> bool:
	for i in Content.stations().size():
		if not _usable(origin + Vector2i(i % YARD_COLUMNS, i / YARD_COLUMNS) * YARD_SPACING):
			return false
	# Keep walkways: the whole block footprint must be dry and untilled too.
	for y in (rows - 1) * YARD_SPACING + 1:
		for x in (YARD_COLUMNS - 1) * YARD_SPACING + 1:
			var cell := origin + Vector2i(x, y)
			if _level.farm_grid.is_water(cell) or _level.farm_grid.is_tilled(cell):
				return false
	return true


func _nearest_free(from: Vector2i) -> Vector2i:
	for radius in search_radius + 1:
		for cell in _ring(from, radius):
			if _usable(cell):
				return cell
	return from


func _usable(cell: Vector2i) -> bool:
	var grid := _level.farm_grid
	return grid.is_free_for_placement(cell) and not grid.is_tilled(cell)


## Cells at Chebyshev distance `radius` from `center`, nearest-to-axis order not needed.
func _ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius == 0:
		out.append(center)
		return out
	for d in range(-radius, radius + 1):
		out.append(center + Vector2i(d, -radius))
		out.append(center + Vector2i(d, radius))
		if absi(d) != radius:
			out.append(center + Vector2i(-radius, d))
			out.append(center + Vector2i(radius, d))
	return out


# ---------------------------------------------------------------- crafting screen

func _open_screen(station: Station) -> void:
	if _screen == null or not is_instance_valid(_screen):
		_screen = ScreenLocator.find_or_create(get_tree(), SCREEN_GROUP, SCREEN_SCENE, self) as CraftingScreen
	_screen.open_for(station)

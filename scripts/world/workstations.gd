class_name Workstations extends LevelFeature
## Feature root for crafting stations. Add scenes/world/workstations.tscn as a child of
## Level: it spawns Stations into level.stations(), lays out a starter yard of
## Balance.STARTER_STATIONS on a new game (the rest are built, see BuildMode), saves them
## under `stations`, and opens the crafting screen on interaction.

## Group of the crafting screen (found, or created under the first CanvasLayer).
const SCREEN_GROUP := &"CraftingScreen"
const SCREEN_SCENE := preload("res://scenes/ui/crafting_screen.tscn")
## Stations per row of the starter yard and the cell gap between stations.
const YARD_COLUMNS := 2
const YARD_SPACING := 2

## The starter yard is laid out as close to this cell as free ground allows.
@export var anchor_cell: Vector2i = Vector2i(19, -8)
## Place the starter yard when a new game begins.
@export var starter_yard: bool = true
## Largest ring searched around the anchor.
@export var search_radius: int = 30

var _stations: Array[Station] = []
var _screen: CraftingScreen


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
	if level == null:
		return null
	var station := Station.create(station_id)
	station.setup(cell, level, level.stations())
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
	return row != null and Loot.has_all(row.build_cost)


## Pay the build cost and place the station; null if unaffordable or the cell is
## not buildable (water, house, tilled, planted or otherwise occupied).
func build(station_id: StringName, cell: Vector2i) -> Station:
	if level == null or not can_afford_build(station_id):
		return null
	if not level.farm_grid.is_buildable(cell):
		return null
	Loot.take(Content.station(station_id).build_cost)
	return place(station_id, cell)


## True if the station on `cell` can be removed: it exists, runs no job and holds no output.
func can_remove(cell: Vector2i) -> bool:
	var station := station_at(cell)
	return station != null and not station.is_working() and not station.has_output()


## What removing a `station_id` station refunds: Balance.BUILD_REFUND_SHARE of each
## cost item, rounded down; items that round to zero are left out.
func refund_of(station_id: StringName) -> Dictionary:
	var refund: Dictionary = {}
	var row := Content.station(station_id)
	if row == null:
		return refund
	for id: StringName in row.build_cost:
		var amount := floori(int(row.build_cost[id]) * Balance.BUILD_REFUND_SHARE)
		if amount > 0:
			refund[id] = amount
	return refund


# ---------------------------------------------------------------- save

## Save section: every station's id, cell, jobs and waiting output.
func to_dict() -> Dictionary:
	var list: Array = []
	for station in _stations:
		list.append(station.to_dict())
	return {"stations": list}


## Place the saved stations.
func _restore(data: Dictionary) -> void:
	for entry: Dictionary in data.get("stations", []):
		var id := StringName(entry.get("id", ""))
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		if Content.station(id) == null:
			continue
		var station := place(id, cell)
		if station:
			station.from_dict(entry)


## New game: lay out the starter yard.
func _new_game_setup() -> void:
	if starter_yard:
		_place_starter_yard()


# ---------------------------------------------------------------- internals

func _clear() -> void:
	for station in _stations.duplicate():
		station.tree_exited.disconnect(_forget.bind(station))
		station.free()
	_stations.clear()


func _forget(station: Station) -> void:
	_stations.erase(station)


func _place_starter_yard() -> void:
	var rows := ceili(float(Balance.STARTER_STATIONS.size()) / YARD_COLUMNS)
	var origin := _find_origin(rows)
	var i := 0
	for id in Balance.STARTER_STATIONS:
		var cell := origin + Vector2i(i % YARD_COLUMNS, i / YARD_COLUMNS) * YARD_SPACING
		if not _usable(cell):
			cell = GridSearch.nearest(cell, search_radius, _usable)
		place(id, cell)
		i += 1


## Nearest block origin to the anchor where every yard cell is usable.
func _find_origin(rows: int) -> Vector2i:
	return GridSearch.nearest(anchor_cell, search_radius, _block_usable.bind(rows))


func _block_usable(origin: Vector2i, rows: int) -> bool:
	for i in Balance.STARTER_STATIONS.size():
		if not _usable(origin + Vector2i(i % YARD_COLUMNS, i / YARD_COLUMNS) * YARD_SPACING):
			return false
	# Keep walkways: the whole block footprint must be dry and untilled too.
	for y in (rows - 1) * YARD_SPACING + 1:
		for x in (YARD_COLUMNS - 1) * YARD_SPACING + 1:
			var cell := origin + Vector2i(x, y)
			if level.farm_grid.is_water(cell) or level.farm_grid.is_tilled(cell):
				return false
	return true


func _usable(cell: Vector2i) -> bool:
	return level.farm_grid.is_buildable(cell)


# ---------------------------------------------------------------- crafting screen

func _open_screen(station: Station) -> void:
	if _screen == null or not is_instance_valid(_screen):
		_screen = ScreenLocator.find_or_create(get_tree(), SCREEN_GROUP, SCREEN_SCENE, self) as CraftingScreen
	_screen.open_for(station)

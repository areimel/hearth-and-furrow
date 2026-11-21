class_name CropField extends Node
## Owns every planted Crop: sowing, lookup, the daily growth pass, reaping and saving.
## A child of FarmGrid, which claims each crop's cell (occupancy) and registers the shared
## `farm` save section; this node supplies the crops part of it.

const Balance := preload("res://data/balance.gd")

@export var grid: FarmGrid
## Parent of crop nodes (the level's y-sorted Objects/Crops).
@export var container: Node2D

var rng := RandomNumberGenerator.new()
var _crops: Dictionary = {}  # Vector2i -> Crop


## Plant `crop_id` (a CropData id) on `cell`. Returns null when the cell is already
## occupied. Does not check the soil or consume a seed: callers decide that.
func sow(cell: Vector2i, crop_id: StringName) -> Crop:
	if crop_at(cell) != null or grid.is_occupied(cell):
		return null
	var crop: Crop = preload("res://scenes/objects/crop.tscn").instantiate()
	crop.setup(cell, crop_id, container)
	_crops[cell] = crop
	grid.occupy(cell, crop)
	return crop


## The crop on `cell`, or null.
func crop_at(cell: Vector2i) -> Crop:
	var crop: Variant = _crops.get(cell)
	if not is_instance_valid(crop):
		_crops.erase(cell)
		return null
	return crop as Crop


## Every planted crop.
func crops() -> Array[Crop]:
	var result: Array[Crop] = []
	for cell: Vector2i in _crops.keys():
		var crop := crop_at(cell)
		if crop:
			result.append(crop)
	return result


## Crops that can be reaped now.
func ripe_crops() -> Array[Crop]:
	return crops().filter(func(crop: Crop) -> bool: return crop.is_ripe())


## Reap the ripe crop on `cell` into the Inventory; it regrows or is removed per its row.
## Returns the items added (0 if there is no ripe crop).
func reap(cell: Vector2i) -> int:
	var crop := crop_at(cell)
	if crop == null or not crop.is_ripe():
		return 0
	var added := crop.collect()
	if crop.data.regrow_days > 0 and not crop.is_flattened():
		crop.regrow()
	else:
		remove(cell)
	return added


## Remove the crop on `cell` without yield.
func remove(cell: Vector2i) -> void:
	var crop := crop_at(cell)
	_crops.erase(cell)
	if crop:
		grid.release(cell)
		crop.queue_free()


## Evening pass (FarmGrid calls it from day_ending, before watering clears).
func resolve_day() -> void:
	for crop in crops():
		crop.resolve_day(grid.is_wet(crop.cell), rng)


## Remove every crop (new game, load).
func clear() -> void:
	for cell: Vector2i in _crops.keys():
		remove(cell)


## Save data: one dictionary per crop.
func to_dict() -> Array:
	return crops().map(func(crop: Crop) -> Dictionary: return crop.to_dict())


## Replace all crops with those from to_dict() output.
func from_dict(saved: Array) -> void:
	clear()
	for entry: Dictionary in saved:
		var pair: Array = entry.get("cell", [0, 0])
		var cell := Vector2i(int(pair[0]), int(pair[1]))
		var id := StringName(entry.get("id", ""))
		if not Content.crops().any(func(row: CropData) -> bool: return row.id == id):
			continue
		var crop := sow(cell, id)
		if crop:
			crop.from_dict(entry)

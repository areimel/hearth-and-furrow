class_name Livestock extends LevelFeature
## Feature root for farm animals. Add scenes/world/livestock.tscn as a child of Level: it
## spawns the animals into `level.animals()`, creates a starter herd on a new game around
## a free pen near `pen_anchor`, and saves under `livestock`.

const ANIMAL_SCENE := preload("res://scenes/actors/animal.tscn")
## Free cells a pen needs (width x height) and the grazing radius (pixels) inside it.
const PEN_CELLS := Vector2i(6, 5)
const PEN_RADIUS := 30.0
const SEARCH_RADIUS := 14

## Preferred top-left cell of the pen; the nearest free ground is used if it is blocked.
@export var pen_anchor: Vector2i = Vector2i(23, 4)
## Most animals of one species the farm can hold.
@export var max_per_species: int = 4

var _home: Vector2 = Vector2.ZERO
var _animals: Array[Animal] = []


## Every animal currently on the farm.
func animals() -> Array[Animal]:
	return _animals.filter(is_instance_valid)


## How many animals of `animal_id` are on the farm.
func count(animal_id: StringName) -> int:
	return animals().filter(func(a: Animal) -> bool: return a.animal_id == animal_id).size()


## True if the species exists and its per-species cap is not reached.
func can_add(animal_id: StringName) -> bool:
	return Content.has_animal(animal_id) and count(animal_id) < max_per_species


## Spawn a new animal in the pen (used by the shepherd's shop). Null if `can_add` is false.
func add_animal(animal_id: StringName) -> Animal:
	if not can_add(animal_id):
		return null
	return _spawn(animal_id, _random_pen_point())


## Centre of the grazing area in world pixels.
func pen_center() -> Vector2:
	return _home


# ---------------------------------------------------------------- save

## Snapshot of every animal.
func to_dict() -> Dictionary:
	var list: Array = []
	for animal in animals():
		list.append(animal.to_dict())
	return {"animals": list}


## Restore the saved herd; an empty dict keeps the starter herd.
func _restore(data: Dictionary) -> void:
	var list: Array = data.get("animals", [])
	if list.is_empty() and data.is_empty():
		_new_game_setup()
		return
	for entry: Dictionary in list:
		var id := StringName(entry.get("id", &""))
		if Content.has_animal(id):
			_spawn(id, entry.get("pos", _home), entry)


func _on_level_ready() -> void:
	_home = _find_pen_center()


## New game: starter herd of 1 cow, 1 sheep and 2 chickens.
func _new_game_setup() -> void:
	for id: StringName in Balance.STARTER_HERD:
		for i in int(Balance.STARTER_HERD[id]):
			_spawn(id, _random_pen_point())


func _spawn(animal_id: StringName, at: Vector2, state: Dictionary = {}) -> Animal:
	var animal: Animal = ANIMAL_SCENE.instantiate()
	animal.home_radius = PEN_RADIUS
	animal.setup(animal_id, _home)
	animal.position = at
	level.animals().add_child(animal)
	if not state.is_empty():
		animal.from_dict(state)
	_animals.append(animal)
	return animal


func _clear() -> void:
	for animal in animals():
		animal.queue_free()
	_animals.clear()


func _random_pen_point() -> Vector2:
	return _home + Vector2.from_angle(randf() * TAU) * randf() * PEN_RADIUS * 0.8


## Centre (pixels) of the nearest block of PEN_CELLS free ground cells to `pen_anchor`.
func _find_pen_center() -> Vector2:
	var best := GridSearch.nearest_block(pen_anchor, PEN_CELLS, SEARCH_RADIUS,
			level.farm_grid.is_free_for_placement)
	return Vector2(best * Balance.TILE_SIZE) + Vector2(PEN_CELLS * Balance.TILE_SIZE) / 2.0

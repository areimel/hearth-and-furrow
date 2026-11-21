class_name Livestock extends Node2D
## Feature root for farm animals. Add scenes/world/livestock.tscn as a child of Level: it
## spawns the animals into `level.animals()`, creates a starter herd on a new game around
## a free pen near `pen_anchor`, and registers with SaveManager under `livestock`.

const ANIMAL_SCENE := preload("res://scenes/actors/animal.tscn")
const SAVE_KEY := &"livestock"
## Starter herd: species id -> count.
const STARTER_HERD: Dictionary = {&"cow": 1, &"sheep": 1, &"chicken": 2}
## Free cells a pen needs (width x height) and the grazing radius (pixels) inside it.
const PEN_CELLS := Vector2i(6, 5)
const PEN_RADIUS := 30.0
const SEARCH_RADIUS := 14

## Preferred top-left cell of the pen; the nearest free ground is used if it is blocked.
@export var pen_anchor: Vector2i = Vector2i(28, -6)
## Most animals of one species the farm can hold.
@export var max_per_species: int = 4

var _level: Level
var _home: Vector2 = Vector2.ZERO
var _animals: Array[Animal] = []
var _ready_done: bool = false
var _pending: Dictionary = {}
var _has_pending: bool = false


func _ready() -> void:
	_level = get_parent() as Level
	SaveManager.register(SAVE_KEY, self)
	_start.call_deferred()  # the Level's own @onready members are not set until after us


func _exit_tree() -> void:
	SaveManager.unregister(SAVE_KEY)


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


## Replace the herd with the saved one; an empty dict keeps the starter herd.
func from_dict(data: Dictionary) -> void:
	if not _ready_done:
		_pending = data
		_has_pending = true
		return
	_clear()
	var list: Array = data.get("animals", [])
	if list.is_empty() and data.is_empty():
		_spawn_starter_herd()
		return
	for entry: Dictionary in list:
		var id := StringName(entry.get("id", &""))
		if Content.has_animal(id):
			_spawn(id, entry.get("pos", _home), entry)


## New game: starter herd of 1 cow, 1 sheep and 2 chickens.
func reset() -> void:
	_has_pending = false
	_clear()
	_spawn_starter_herd()


# ---------------------------------------------------------------- internals

func _start() -> void:
	if _level == null:
		return
	_home = _find_pen_center()
	_ready_done = true
	if _has_pending:
		from_dict(_pending)
	elif _animals.is_empty():
		_spawn_starter_herd()


func _spawn_starter_herd() -> void:
	if not _ready_done:
		return
	for id: StringName in STARTER_HERD:
		for i in int(STARTER_HERD[id]):
			_spawn(id, _random_pen_point())


func _spawn(animal_id: StringName, at: Vector2, state: Dictionary = {}) -> Animal:
	var animal: Animal = ANIMAL_SCENE.instantiate()
	animal.home_radius = PEN_RADIUS
	animal.setup(animal_id, _home)
	animal.position = at
	_level.animals().add_child(animal)
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


## Nearest block of PEN_CELLS free ground cells to `pen_anchor` (rings outward).
func _find_pen_center() -> Vector2:
	var grid := _level.get_node("FarmGrid") as FarmGrid
	var best := pen_anchor
	for ring in SEARCH_RADIUS + 1:
		var found := false
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				if _block_free(grid, pen_anchor + Vector2i(dx, dy)):
					best = pen_anchor + Vector2i(dx, dy)
					found = true
					break
			if found:
				break
		if found:
			break
	var size := Vector2(PEN_CELLS * Balance.TILE_SIZE)
	return Vector2(best * Balance.TILE_SIZE) + size / 2.0


func _block_free(grid: FarmGrid, origin: Vector2i) -> bool:
	for x in PEN_CELLS.x:
		for y in PEN_CELLS.y:
			if not grid.is_free_for_placement(origin + Vector2i(x, y)):
				return false
	return true

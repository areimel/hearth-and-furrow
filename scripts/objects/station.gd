class_name Station extends Placeable
## One generic crafting station; `station_id` picks the StationData row (sprite, name,
## job slots) and Content.recipes_for_station() supplies what it can make.
## Jobs run on GameClock: timed recipes finish when their end minute is reached,
## overnight recipes (and anything still running) finish in GameClock.day_ending.
## Finished output waits inside the station until collect().

## Something about jobs or output changed (UI refresh).
signal changed
## A job completed and its output is waiting.
signal job_finished(recipe_id: StringName)
## collect() moved items into the Inventory: item id -> count.
signal collected(items: Dictionary)
## The player pressed action next to the station.
signal interaction_requested(station: Station)

const SCENE := preload("res://scenes/objects/station.tscn")
const DAY_MINUTES := 1440
const LABEL_WIDTH := 80

@export var station_id: StringName:
	set(value):
		station_id = value
		if is_node_ready():
			_apply_data()

## Output waiting to be collected: item id -> count.
var output: Dictionary = {}
var _jobs: Array[Dictionary] = []  # {recipe: StringName, end: int (-1 = overnight)}
var _data: StationData
var _time: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _interactable: Interactable = $Interactable
@onready var _name_label: Label = $NameLabel
@onready var _output_icon: Sprite2D = $OutputIcon


## New unplaced station of type `id`; add it with setup().
static func create(id: StringName) -> Station:
	var station: Station = SCENE.instantiate()
	station.station_id = id
	return station


func _ready() -> void:
	_interactable.interacted.connect(func(_p: Node) -> void: interaction_requested.emit(self))
	GameClock.minute_passed.connect(_on_minute_passed)
	GameClock.day_ending.connect(_on_day_ending)
	_apply_data()


func _process(delta: float) -> void:
	_name_label.visible = _interactable.focused
	_time += delta
	if has_output():
		_output_icon.position.y = _icon_rest_y() + roundf(sin(_time * 4.0))
	elif is_working():
		queue_redraw()


func _draw() -> void:
	if not is_working() or has_output():
		return
	var lit := int(_time * 3.0) % 3
	for i in 3:
		var shade := UIPalette.GOLD if i == lit else UIPalette.WOOD_LIGHT
		draw_rect(Rect2(5 + i * 3, _top() - 3, 2, 2), shade)


# ---------------------------------------------------------------- queries

## The StationData row (null for an unknown id).
func data() -> StationData:
	return _data


## Display name from the row.
func display_name() -> String:
	return _data.display_name if _data else String(station_id)


## True while at least one job is running.
func is_working() -> bool:
	return not _jobs.is_empty()


## True if finished goods are waiting.
func has_output() -> bool:
	return not output.is_empty()


## Number of running jobs.
func job_count() -> int:
	return _jobs.size()


## True if a job slot is free.
func has_free_slot() -> bool:
	return _data != null and _jobs.size() < _data.slots


## Running jobs as {recipe: StringName, minutes_left: int (-1 = overnight)}.
func jobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for job in _jobs:
		var left := -1 if int(job["end"]) < 0 else maxi(int(job["end"]) - _now(), 0)
		out.append({"recipe": job["recipe"], "minutes_left": left})
	return out


## Whether start_job() would succeed right now.
func can_start(recipe_id: StringName) -> bool:
	var recipe := Content.recipe(recipe_id)
	if recipe == null or _data == null or recipe.station != station_id:
		return false
	if not Progress.has_flag(recipe.unlock_flag) or not has_free_slot():
		return false
	return inputs_missing(recipe).is_empty()


## Inputs of `recipe` the Inventory lacks: item id -> shortfall.
func inputs_missing(recipe: RecipeData) -> Dictionary:
	return Loot.missing(recipe.inputs)


# ---------------------------------------------------------------- jobs

## Consume the recipe's inputs and start a job. False if the recipe is unknown here,
## locked, a slot is not free, or inputs are missing. Instant recipes finish at once.
func start_job(recipe_id: StringName) -> bool:
	if not can_start(recipe_id):
		return false
	var recipe := Content.recipe(recipe_id)
	Loot.take(recipe.inputs)
	if not recipe.overnight and recipe.minutes <= 0:
		_finish(recipe)
	else:
		_jobs.append({"recipe": recipe_id, "end": -1 if recipe.overnight else _now() + recipe.minutes})
	_update_visuals()
	changed.emit()
	return true


## Move waiting output into the Inventory (Loot: records Progress `crafted`, toasts). Anything
## that does not fit stays in the station. True only if everything was taken.
func collect() -> bool:
	if output.is_empty():
		return false
	var leftover := Loot.deliver(get_tree(), output, &"crafted")
	var taken: Dictionary = {}
	for id: StringName in output:
		var moved: int = int(output[id]) - int(leftover.get(id, 0))
		if moved > 0:
			taken[id] = moved
	output = leftover
	_update_visuals()
	if not taken.is_empty():
		collected.emit(taken)
	changed.emit()
	return output.is_empty()


func _finish(recipe: RecipeData) -> void:
	for id: StringName in recipe.outputs:
		output[id] = int(output.get(id, 0)) + int(recipe.outputs[id])
	job_finished.emit(recipe.id)


func _on_minute_passed(_hour: int, _minute: int) -> void:
	_complete_jobs(false)


func _on_day_ending(_day: int) -> void:
	_complete_jobs(true)


func _complete_jobs(day_end: bool) -> void:
	var now := _now()
	var keep: Array[Dictionary] = []
	var done := false
	for job in _jobs:
		var end := int(job["end"])
		if day_end or (end >= 0 and end <= now):
			_finish(Content.recipe(job["recipe"]))
			done = true
		else:
			keep.append(job)
	if done:
		_jobs = keep
		_update_visuals()
		changed.emit()


## Absolute minute counter; monotonic across days (hours never pass 26).
func _now() -> int:
	return GameClock.day_index * DAY_MINUTES + GameClock.total_minutes()


# ---------------------------------------------------------------- save

## Plain-value snapshot: id, cell, running jobs, waiting output.
func to_dict() -> Dictionary:
	return {"id": station_id, "cell": coord, "jobs": _jobs.duplicate(true), "output": output.duplicate()}


## Restore jobs and output from to_dict() (id and cell are applied by the loader).
func from_dict(saved: Dictionary) -> void:
	_jobs.clear()
	for job: Dictionary in saved.get("jobs", []):
		_jobs.append({"recipe": StringName(job.get("recipe", "")), "end": int(job.get("end", -1))})
	output.clear()
	var waiting: Dictionary = saved.get("output", {})
	for id: Variant in waiting:
		output[StringName(id)] = int(waiting[id])
	_update_visuals()
	changed.emit()


# ---------------------------------------------------------------- visuals

func _apply_data() -> void:
	_data = Content.station(station_id) if not station_id.is_empty() else null
	if _data == null:
		return
	_sprite.texture = _data.texture
	_sprite.position = Vector2(0, _top())
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf(_data.texture.get_size().x - 2, 4), 10)
	_shape.shape = box
	_shape.position = Vector2(8, 11)
	_interactable.position = Vector2(8, 8)
	_name_label.text = _data.display_name
	_name_label.custom_minimum_size.x = LABEL_WIDTH
	_name_label.size.x = LABEL_WIDTH
	_name_label.position = Vector2(8 - LABEL_WIDTH / 2.0, 17)
	_output_icon.position = Vector2(8, _icon_rest_y())
	_update_visuals()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	_sprite.modulate = Color(0.85, 0.85, 1.0) if is_working() else Color.WHITE
	_output_icon.visible = has_output()
	_interactable.prompt_text = "Collect" if has_output() else "Open %s" % display_name()
	if has_output():
		_output_icon.texture = Content.item(output.keys()[0]).icon
	queue_redraw()


## Y of the sprite's top edge relative to the station's cell origin.
func _top() -> float:
	return 16.0 - (_data.texture.get_size().y if _data else 16.0)


func _icon_rest_y() -> float:
	return _top() - 6.0

class_name NPC extends CharacterBody2D
## A villager. Set `npc_id` (before or after adding to the tree) and everything else comes
## from Content.npc(): sprite, schedule, gift tastes. Walks between village places by the
## hour, idles on arrival, and talks or accepts gifts through its Interactable child.
## Other systems attach dialogue choices with add_dialogue_option() instead of editing NPC.

## A conversation with this villager started (every talk, not only the first of the day).
signal talked(npc_id: StringName)
## Reached the place it was walking to.
signal arrived(place_id: StringName)

enum Dir { DOWN, UP, LEFT, RIGHT }

const WALK_SPEED: float = 26.0
const WALK_FRAME_TIME: float = 0.18

## Villager id, e.g. &"miller".
@export var npc_id: StringName = &"":
	set(value):
		npc_id = value
		if is_node_ready():
			_configure()

## The NPCData row (null until configured).
var data: NPCData
## Place id the villager stands at or is walking to.
var place_id: StringName = &""
## True while a festival (or similar) holds the villager away from the schedule.
var held: bool = false

var _path: PackedVector2Array = PackedVector2Array()
var _facing: int = Dir.DOWN
var _walk_time: float = 0.0
var _idle_left: float = 4.0
var _talk: NPCTalk

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _emote: Emote = $Emote


func _ready() -> void:
	_talk = NPCTalk.new(self, _emote)
	_interactable.interacted.connect(_on_interacted)
	GameClock.hour_passed.connect(_on_hour_passed)
	GameClock.day_passed.connect(_on_day_passed)
	SaveManager.loaded.connect(_on_loaded)
	_configure()
	snap_to_schedule()


func _physics_process(delta: float) -> void:
	if data == null or _talk.busy:
		return
	if not _path.is_empty():
		_walk(delta)
		return
	_idle_left -= delta
	if _idle_left <= 0.0:
		_idle_left = randf_range(3.0, 8.0)
		_facing = [Dir.DOWN, Dir.DOWN, Dir.LEFT, Dir.RIGHT].pick_random()
		_update_frame(0)


# --- Schedule ---

## Where the schedule says this villager should be right now ("" if nowhere).
func scheduled_place() -> StringName:
	if data == null:
		return &""
	return data.location_at(GameClock.hour, Calendar.weekday(), Calendar.season(),
			Weather.is_raining())


## Teleport to the scheduled place (scene load, load-game, new morning). No-op when the
## map has no such marker or a festival holds the villager.
func snap_to_schedule() -> void:
	if held:
		return
	var place := scheduled_place()
	var marker := Places.marker(get_tree(), place)
	if marker == null:
		return
	global_position = marker.global_position
	place_id = place
	_path.clear()
	_update_frame(0)


## Walk to `place` (default: the scheduled one) unless already there or held.
func walk_to_schedule() -> void:
	if held or _talk.busy:
		return
	_walk_to_place(scheduled_place())


## Take over from the schedule: walk to `target` (optionally via the map route to
## `via_place`) and stay until release_hold(). Used by festivals.
func hold_at(target: Vector2, via_place: StringName = &"") -> void:
	held = true
	var from_id: StringName = place_id if _path.is_empty() else &""
	_path = Places.route(get_tree(), global_position, from_id, via_place) if via_place != &"" \
			else PackedVector2Array()
	_path.append(target)


## Return to the schedule after hold_at().
func release_hold() -> void:
	held = false
	walk_to_schedule()


func _walk_to_place(place: StringName) -> void:
	if place == &"" or (place == place_id and _path.is_empty()):
		return
	var from_id: StringName = place_id if _path.is_empty() else &""
	var route := Places.route(get_tree(), global_position, from_id, place)
	if route.is_empty():
		return
	place_id = place
	_path = route


func _walk(delta: float) -> void:
	var to_next := _path[0] - global_position
	var step := WALK_SPEED * delta
	if to_next.length() <= step:
		global_position = _path[0]
		_path.remove_at(0)
		if _path.is_empty():
			_facing = Dir.DOWN
			_update_frame(0)
			arrived.emit(place_id)
			return
	else:
		global_position += to_next.normalized() * step
		_face(to_next)
	_walk_time += delta
	_update_frame(int(_walk_time / WALK_FRAME_TIME) % 4)


func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		_facing = Dir.RIGHT if direction.x > 0.0 else Dir.LEFT
	else:
		_facing = Dir.DOWN if direction.y > 0.0 else Dir.UP


func _update_frame(row: int) -> void:
	_sprite.frame = row * _sprite.hframes + _facing


func _on_hour_passed(_hour: int) -> void:
	walk_to_schedule()


func _on_day_passed(_day: int) -> void:
	snap_to_schedule()


func _on_loaded(_path_loaded: String) -> void:
	snap_to_schedule()


func _configure() -> void:
	data = Content.npc(npc_id) if npc_id != &"" else null
	if data == null:
		return
	_sprite.texture = data.sprite


# --- Talking ---

## Attach a dialogue choice shown at the end of every conversation. `callback` runs with
## no arguments after the dialogue closes; `condition` (optional, returns bool) hides the
## choice while false. The "Give <item>" choice is built in and needs no registration.
func add_dialogue_option(text: String, callback: Callable, condition: Callable = Callable()) -> void:
	_talk.add_option(text, callback, condition)


## The registered choices currently offered ({text, payload}), conditions applied.
func dialogue_options() -> Array[Dictionary]:
	return _talk.options()


## Say `lines` in the dialogue box (no choices). No-op without a DialogueBox in the tree.
func say(lines: Array[String]) -> void:
	_talk.say(lines)


func _on_interacted(player: Node) -> void:
	if _talk.busy or data == null:
		return
	if player is Node2D:
		_face((player as Node2D).global_position - global_position)
		_update_frame(0)
	_talk.talk()

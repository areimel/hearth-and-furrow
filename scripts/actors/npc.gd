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
var _busy: bool = false
var _talk_count: int = 0
var _options: Array[Dictionary] = []
var _box: DialogueBox

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _prompt: Label = $PromptLabel
@onready var _emote: NPCEmote = $Emote


func _ready() -> void:
	_prompt.add_theme_color_override(&"font_color", UIPalette.PARCHMENT_LIGHT)
	_prompt.add_theme_color_override(&"font_outline_color", UIPalette.INK)
	_prompt.add_theme_constant_override(&"outline_size", 3)
	_interactable.interacted.connect(_on_interacted)
	GameClock.hour_passed.connect(_on_hour_passed)
	GameClock.day_passed.connect(_on_day_passed)
	SaveManager.loaded.connect(_on_loaded)
	_configure()
	snap_to_schedule()


func _process(_delta: float) -> void:
	var show_prompt := _interactable.focused and not _busy and data != null
	_prompt.visible = show_prompt
	if show_prompt:
		_prompt.text = prompt_text()


func _physics_process(delta: float) -> void:
	if data == null or _busy:
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
	var target: Variant = NPCNav.position_of(get_tree(), place)
	if target == null:
		return
	global_position = target
	place_id = place
	_path.clear()
	_update_frame(0)


## Walk to `place` (default: the scheduled one) unless already there or held.
func walk_to_schedule() -> void:
	if held or _busy:
		return
	_walk_to_place(scheduled_place())


## Take over from the schedule: walk to `target` (optionally via the map route to
## `via_place`) and stay until release_hold(). Used by festivals.
func hold_at(target: Vector2, via_place: StringName = &"") -> void:
	held = true
	var from_id: StringName = place_id if _path.is_empty() else &""
	_path = NPCNav.route(get_tree(), global_position, from_id, via_place) if via_place != &"" \
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
	var route := NPCNav.route(get_tree(), global_position, from_id, place)
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


# --- Talking and gifts ---

## What the interaction prompt should say: "Give <item>" or "Talk".
func prompt_text() -> String:
	var item := Inventory.selected_item()
	if item != null and item.is_giftable():
		return "Give %s" % item.display_name
	return "Talk"


## Attach a dialogue choice shown at the end of every conversation. `callback` runs with
## no arguments after the dialogue closes; `condition` (optional, returns bool) hides the
## choice while false.
func add_dialogue_option(text: String, callback: Callable, condition: Callable = Callable()) -> void:
	_options.append({"text": text, "callback": callback, "condition": condition})


## Remove every choice added with this text.
func remove_dialogue_option(text: String) -> void:
	_options = _options.filter(func(o: Dictionary) -> bool: return o["text"] != text)


## Say `lines` in the dialogue box (no choices). No-op without a DialogueBox in the tree.
func say(lines: Array[String]) -> void:
	_converse(lines, false)


func _on_interacted(player: Node) -> void:
	if _busy or data == null:
		return
	if player is Node2D:
		_face((player as Node2D).global_position - global_position)
		_update_frame(0)
	var item := Inventory.selected_item()
	if item != null and item.is_giftable():
		_give(item)
	else:
		_talk()


func _talk() -> void:
	var first := Relationships.talk(npc_id)
	_talk_count += 1
	talked.emit(npc_id)
	var lines := DialogueLines.conversation(npc_id, Relationships.hearts(npc_id), first,
			Calendar.season(), Weather.is_raining(), Calendar.is_market_day(), Weather.forecast,
			_salt())
	_converse(lines, true)


func _give(item: ItemData) -> void:
	var reaction := Relationships.gift(npc_id, item.id)
	if reaction == G.GiftReaction.NOT_GIFTABLE:
		_talk()
		return
	_emote.show_reaction(reaction)
	_talk_count += 1
	var line := DialogueLines.gift_line(npc_id, reaction, _salt())
	_converse([line] as Array[String], false)


func _salt() -> int:
	return GameClock.day_index * 31 + _talk_count + hash(npc_id) % 97


func _converse(lines: Array[String], with_options: bool) -> void:
	var box := get_tree().get_first_node_in_group(&"DialogueBox") as DialogueBox
	if box == null or data == null:
		return
	_busy = true
	_box = box
	if not box.finished.is_connected(_on_dialogue_finished):
		box.finished.connect(_on_dialogue_finished)
		box.option_chosen.connect(_on_option_chosen)
	var options: Array[Dictionary] = []
	if with_options:
		options = dialogue_options()
	box.show_dialogue(data, lines, options)


## The choices currently offered ({text, payload}), conditions applied.
func dialogue_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option in _options:
		var condition: Callable = option["condition"]
		if condition.is_valid() and not condition.call():
			continue
		out.append({"text": option["text"], "payload": option["callback"]})
	return out


func _on_option_chosen(payload: Variant) -> void:
	if payload is Callable and (payload as Callable).is_valid():
		(payload as Callable).call()


func _on_dialogue_finished() -> void:
	_box.finished.disconnect(_on_dialogue_finished)
	_box.option_chosen.disconnect(_on_option_chosen)
	_busy = false
	walk_to_schedule()

class_name Gatherable extends Placeable
## One world node the player gathers by hand (hazel coppice, bramble, stone, clay, reeds),
## fully described by its GatherableData row (`gatherable_id`). Interacting rolls the
## row's in-season yields into the Inventory, records `gathered.<item>` progress and
## depletes the node; it regrows `regrow_days` day-ends later. Whatever does not fit
## in a full pack stays on the node for the next visit. The prompt is published as
## meta `prompt_text` on the Interactable.

## Care state changed (prompt or sprite may be stale).
signal state_changed

const SCENE := preload("res://scenes/objects/gatherable.tscn")
const SPRITE_ROW := 16

## Row id; set before adding to the tree (see `create`).
@export var gatherable_id: StringName

## Waiting for regrowth.
var depleted: bool = false
## Day-ends left until the node is ready again (only while depleted).
var regrow_left: int = 0
## Rolled but not yet delivered yield (pack was full): item id -> count.
var pending: Dictionary = {}
## Row, null until set up.
var data: GatherableData

var _rng := RandomNumberGenerator.new()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _interactable: Interactable = $Interactable


## New unplaced node of kind `id`; add it with `setup()`.
static func create(id: StringName) -> Gatherable:
	var node: Gatherable = SCENE.instantiate()
	node.gatherable_id = id
	return node


func _ready() -> void:
	_rng.randomize()
	data = Content.gatherable(gatherable_id)
	_interactable.interacted.connect(func(_p: Node) -> void: gather())
	GameClock.day_ending.connect(_on_day_ending)
	GameClock.day_passed.connect(func(_d: int) -> void: refresh())
	Calendar.season_changed.connect(func(_s: int) -> void: refresh())
	Inventory.changed.connect(refresh)
	refresh()


## Gathering nodes cannot be deleted in build mode.
func remove() -> void:
	pass


# ---------------------------------------------------------------- gathering

## True if the node is ready and something is ripe this season.
func is_ripe() -> bool:
	return data != null and not depleted and (not pending.is_empty() or not _rows().is_empty())


## True if the player holds whatever tool the row asks for (always true for none).
func has_required_tool() -> bool:
	if data == null or not data.needs_tool():
		return true
	for i in Inventory.size():
		var item := Inventory.slot_item(i)
		if item != null and item.tool_kind == data.tool_kind:
			return true
	return false


## Roll the yield for the current season: item id -> count (empty if nothing is ripe).
func roll_yields() -> Dictionary:
	var out: Dictionary = {}
	for row in _rows():
		var item := StringName(row.get("item", &""))
		var n := _rng.randi_range(int(row.get("min", 1)), int(row.get("max", 1)))
		out[item] = int(out.get(item, 0)) + n
	return out


## Gather into the pack. True if anything was taken; the node depletes once nothing
## is left over. Shows a toast explaining why when nothing could be taken.
func gather() -> bool:
	if data == null or depleted:
		return false
	if not has_required_tool():
		_toast(prompt_text())
		return false
	if pending.is_empty():
		pending = roll_yields()
	if pending.is_empty():
		_toast("Nothing ripe yet")
		return false
	var taken := _deliver()
	if pending.is_empty():
		depleted = true
		regrow_left = data.regrow_days
	elif taken == 0:
		_toast("Pack full")
	else:
		_toast("Pack full: the rest stays here")
	_pop()
	_changed()
	return taken > 0


## What interacting would do now: the row's verb, "Needs an axe", "Nothing ripe yet"
## or "" when depleted.
func prompt_text() -> String:
	if data == null or depleted:
		return ""
	if not has_required_tool():
		var tool := String(G.ToolKind.keys()[data.tool_kind]).to_lower().replace("_", " ")
		return "Needs %s %s" % ["an" if tool[0] in "aeiou" else "a", tool]
	return data.verb if is_ripe() else "Nothing ripe yet"


## Re-evaluate sprite, prompt and collision from the current state.
func refresh() -> void:
	if data == null or not is_node_ready():
		return
	var texture := data.full_texture if is_ripe() else data.empty_texture
	_sprite.texture = texture
	_sprite.position = Vector2(0, SPRITE_ROW - texture.get_height())
	var text := prompt_text()
	_interactable.enabled = text != ""
	_interactable.set_meta(&"prompt_text", text)
	_shape.set_deferred(&"disabled", depleted or not data.blocks_movement)


# ---------------------------------------------------------------- save

## Plain-value snapshot.
func to_dict() -> Dictionary:
	return {"id": gatherable_id, "cell": coord, "depleted": depleted, "regrow": regrow_left,
		"pending": pending.duplicate()}


## Restore the state part of `to_dict()` (id and cell are applied by `create`/`setup`).
func from_dict(d: Dictionary) -> void:
	depleted = bool(d.get("depleted", false))
	regrow_left = int(d.get("regrow", 0))
	pending.clear()
	var saved: Dictionary = d.get("pending", {})
	for item: Variant in saved:
		pending[StringName(item)] = int(saved[item])
	refresh()


# ---------------------------------------------------------------- internals

func _rows() -> Array[Dictionary]:
	return data.yields_for(Calendar.season(), Calendar.day_of_season())


## Move `pending` into the pack; returns how many items went in.
func _deliver() -> int:
	var taken := 0
	for item: StringName in pending.keys():
		var want := int(pending[item])
		var got := want - Inventory.add(item, want)
		if got > 0:
			taken += got
			Progress.record(&"gathered", item, got)
			_toast("+%d %s" % [got, Content.item(item).display_name], Content.item(item).icon)
		if got == want:
			pending.erase(item)
		else:
			pending[item] = want - got
	return taken


func _on_day_ending(_day: int) -> void:
	if depleted:
		regrow_left -= 1
		if regrow_left <= 0:
			depleted = false
			regrow_left = 0
	_changed()


func _changed() -> void:
	refresh()
	state_changed.emit()


func _toast(text: String, icon: Texture2D = null) -> void:
	if is_inside_tree():
		Toast.show_message(get_tree(), text, icon)


## Small shake so a gather feels physical.
func _pop() -> void:
	if not is_inside_tree() or _sprite == null:
		return
	var tween := create_tween()
	for dx in [1.5, -1.5, 1.0, 0.0]:
		tween.tween_property(_sprite, "offset:x", dx, 0.04)

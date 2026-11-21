class_name Animal extends CharacterBody2D
## One farm animal, fully described by its AnimalData row (`animal_id`): sprite, product,
## feed and cadence. It wanders around a home point, can be fed / harvested / petted through
## its Interactable child, and produces on GameClock.day_ending. Animals never die: neglect
## only lowers mood, which delays (never cancels) the product.

## Emitted when care state changed (prompt text may be stale).
signal state_changed

## What interacting would do right now.
enum Action { NONE, FEED, COLLECT, PET }

## Product item -> verb shown on the prompt; other products read "Collect <item>".
const PRODUCT_VERBS: Dictionary = {&"milk": "Milk", &"fleece": "Shear"}
## Seasons in which grazing is not enough and the feed item is needed.
const FEED_SEASONS: Array[int] = [G.Season.WINTER]
const MOOD_MAX := 100
const MOOD_START := 60
## Below this mood the product takes one extra day.
const LOW_MOOD := 30
const MOOD_FED := 4
const MOOD_GRAZED := 1
const MOOD_PET := 6
const MOOD_UNFED := -4

## Species id; set before adding to the tree (or call `setup`).
@export var animal_id: StringName
## Radius in pixels the animal may stray from `home`.
@export var home_radius: float = 40.0

## Mood 0..100; a low mood slows the product by a day.
var mood: int = MOOD_START
## Fed by hand today (cleared at day end).
var fed_today: bool = false
## Petted today (cleared at day end).
var petted_today: bool = false
## Product is waiting to be collected.
var product_ready: bool = false
## Fed days accumulated towards the next product.
var progress_days: int = 0
## Centre of the grazing area (world pixels).
var home: Vector2 = Vector2.ZERO
## Frames in the sprite sheet row (1 = standing sprite).
var frames: int = 1
## Species row, null until set up.
var data: AnimalData

var _wander: Wander

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interactable: Interactable = $Interactable
@onready var _emote: Emote = $Emote


func _ready() -> void:
	_wander = Wander.new(self, _sprite)
	_interactable.interacted.connect(_on_interacted)
	Inventory.hotbar_selection_changed.connect(func(_i: int) -> void: refresh())
	Inventory.changed.connect(refresh)
	GameClock.day_ending.connect(end_day)
	if home == Vector2.ZERO:
		home = position
	if animal_id != &"":
		_apply_data()


## Configure species and pen point; call before or after adding to the tree.
func setup(id: StringName, home_point: Vector2) -> void:
	animal_id = id
	home = home_point
	position = home_point
	if is_node_ready():
		_apply_data()


# ---------------------------------------------------------------- care

## What interacting would do with the currently selected hotbar item.
func current_action() -> Action:
	if data == null:
		return Action.NONE
	if not fed_today and Inventory.selected_id() == data.feed_item:
		return Action.FEED
	if product_ready:
		return Action.COLLECT
	if not petted_today:
		return Action.PET
	return Action.NONE


## Prompt text for `current_action()` ("Feed", "Milk", "Shear", "Collect egg", "Pet").
func prompt_text() -> String:
	match current_action():
		Action.FEED:
			return "Feed"
		Action.COLLECT:
			var item := Content.item(data.product_item)
			return PRODUCT_VERBS.get(data.product_item, "Collect %s" % item.display_name.to_lower())
		Action.PET:
			return "Pet"
	return ""


## Eat one feed item from the pack. False if none is held or already fed today.
func feed() -> bool:
	if data == null or fed_today or not Inventory.remove(data.feed_item, 1):
		return false
	fed_today = true
	add_mood(MOOD_FED)
	_emote.pop(Emote.HEART)
	_changed()
	return true


## Hand over the waiting product into the pack. False if none, or the pack is full.
func collect() -> bool:
	if data == null or not product_ready or not Inventory.can_add(data.product_item, data.product_amount):
		return false
	Loot.give(get_tree(), data.product_item, data.product_amount, &"gathered")
	product_ready = false
	_changed()
	return true


## Pet once per day for a small mood bump. False if already petted today.
func pet() -> bool:
	if data == null or petted_today:
		return false
	petted_today = true
	add_mood(MOOD_PET)
	_emote.pop(Emote.HEART)
	_changed()
	return true


## Change mood, clamped to 0..100.
func add_mood(delta: int) -> void:
	mood = clampi(mood + delta, 0, MOOD_MAX)


## Fed days one product takes at the current mood.
func days_needed() -> int:
	return data.product_days + (1 if mood < LOW_MOOD else 0)


## Resolve a finished day (connected to GameClock.day_ending). Grazing (outside
## FEED_SEASONS) or hand feeding counts as fed; fed days advance the product, an unfed
## winter day only costs mood.
func end_day(day: int = -1) -> void:
	if data == null:
		return
	var grazed := Calendar.season(day) not in FEED_SEASONS
	if not fed_today:
		add_mood(MOOD_GRAZED if grazed else MOOD_UNFED)
	if (fed_today or grazed) and not product_ready:
		progress_days += 1
		if progress_days >= days_needed():
			product_ready = true
			progress_days = 0
	fed_today = false
	petted_today = false
	_changed()


## Re-evaluate the prompt and whether the interactable is usable: the prompt is
## published as the Interactable's `prompt_text`; with nothing to do it is disabled.
func refresh() -> void:
	if data == null:
		return
	var text := prompt_text()
	_interactable.enabled = text != ""
	if text != "":
		_interactable.prompt_text = text


# ---------------------------------------------------------------- save

## Plain-value snapshot.
func to_dict() -> Dictionary:
	return {"id": animal_id, "mood": mood, "progress": progress_days, "ready": product_ready,
		"fed": fed_today, "petted": petted_today, "pos": position, "home": home}


## Restore from `to_dict()` (the id is applied separately via `setup`).
func from_dict(d: Dictionary) -> void:
	mood = clampi(int(d.get("mood", MOOD_START)), 0, MOOD_MAX)
	progress_days = int(d.get("progress", 0))
	product_ready = bool(d.get("ready", false))
	fed_today = bool(d.get("fed", false))
	petted_today = bool(d.get("petted", false))
	home = d.get("home", home)
	position = d.get("pos", home)
	if is_node_ready():
		_changed()


# ---------------------------------------------------------------- internals

func _apply_data() -> void:
	data = Content.animal(animal_id)
	if data == null:
		return
	var tex := data.sprite
	_sprite.texture = tex
	var size := tex.get_size()
	frames = maxi(1, roundi(size.x / maxf(size.y, 1.0)))
	_sprite.hframes = frames
	_sprite.frame = 0
	_sprite.offset = Vector2(0, -size.y / 2.0 + 2.0)  # feet on the node origin
	refresh()


func _changed() -> void:
	refresh()
	state_changed.emit()


func _on_interacted(_player: Node) -> void:
	match current_action():
		Action.FEED:
			feed()
		Action.COLLECT:
			if not collect():
				Toast.show_message(get_tree(), Loot.PACK_FULL)
		Action.PET:
			pet()


func _physics_process(delta: float) -> void:
	if data != null:
		_wander.tick(delta)

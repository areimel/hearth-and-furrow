class_name HUD extends Control
## The always-on overlay: clock card, coin purse, hotbar, interaction prompt and pickup
## toasts. Instance scenes/ui/hud.tscn under the level's CanvasLayer; it is found by
## group "HUD". Everything updates from signals. It hides itself while any UIScreen is
## open (UIScreen tells the group) and on demand via set_hud_visible() for feasts and
## cutscenes; toasts stay visible so screens can still report things.

const GROUP := &"HUD"
## Seconds in which repeated pickups of one item merge into a single toast.
const PICKUP_WINDOW := 0.5
## Seconds the selected item's name stays above the hotbar.
const NAME_HOLD := 1.4
const NAME_FADE := 0.3

var _hidden_by_game: bool = false
var _pending: Dictionary[StringName, int] = {}
var _name_tween: Tween

@onready var _shown: Control = $Shown
@onready var _bottom: VBoxContainer = $Shown/Bottom
@onready var _item_name: Label = $Shown/Bottom/ItemName
@onready var _prompt: Prompt = $Shown/Prompt
@onready var _toasts: Toast = $Toasts
@onready var _pickup_timer: Timer = $PickupTimer


func _ready() -> void:
	add_to_group(GROUP)
	_item_name.modulate.a = 0.0
	_pickup_timer.wait_time = PICKUP_WINDOW
	_pickup_timer.timeout.connect(flush_pickups)
	Inventory.item_added.connect(_on_item_added)
	Inventory.hotbar_selection_changed.connect(_on_selection_changed)
	_bottom.resized.connect(_place_prompt)
	_place_prompt.call_deferred()


## Show "[glyph for action] text" above the hotbar (e.g. show_prompt(&"action", "Talk")).
func show_prompt(action: StringName, text: String) -> void:
	_prompt.show_prompt(action, text)


## Hide the interaction prompt.
func hide_prompt() -> void:
	_prompt.hide_prompt()


## Hide or restore the HUD for feasts and cutscenes. Open screens keep it hidden anyway.
func set_hud_visible(value: bool) -> void:
	_hidden_by_game = not value
	refresh_screen_state()


## True when the card, purse and hotbar are currently drawn.
func is_hud_visible() -> bool:
	return _shown.visible


## Re-evaluate visibility; UIScreen calls this on every open and close.
func refresh_screen_state() -> void:
	_shown.visible = not _hidden_by_game and not UIScreen.any_open(get_tree())


## Items gathered since the last flush, as {item id: amount}.
func pending_pickups() -> Dictionary:
	return _pending.duplicate()


## The selected item's name as shown above the hotbar.
func shown_item_name() -> String:
	return _item_name.text


## Push a toast now, bypassing pickup coalescing.
func push_toast(text: String, icon: Texture2D = null) -> void:
	_toasts.push(text, icon)


## Emit one toast per item gathered since the last flush ("+3 Wheat sheaf").
func flush_pickups() -> void:
	for id in _pending:
		var item := Content.item(id)
		_toasts.push("+%d %s" % [_pending[id], item.display_name], item.icon)
	_pending.clear()


func _on_item_added(id: StringName, amount: int) -> void:
	# Only while the day is running, so new-game and load setup stays silent.
	if not GameClock.running:
		return
	_pending[id] = _pending.get(id, 0) + amount
	if _pickup_timer.is_stopped():
		_pickup_timer.start()


func _on_selection_changed(_index: int) -> void:
	var item := Inventory.selected_item()
	if item == null:
		_item_name.modulate.a = 0.0
		return
	_item_name.text = item.display_name
	_item_name.modulate.a = 1.0
	if _name_tween:
		_name_tween.kill()
	_name_tween = create_tween()
	_name_tween.tween_interval(NAME_HOLD)
	_name_tween.tween_property(_item_name, "modulate:a", 0.0, NAME_FADE)


# Lift the prompt clear of the hotbar block, whatever the font size.
func _place_prompt() -> void:
	_prompt.offset_bottom = -(_bottom.size.y + 4.0)

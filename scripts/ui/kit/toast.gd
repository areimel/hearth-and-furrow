class_name Toast extends Control
## Transient messages stacked in the top-right corner that fade by themselves.
## Instance scenes/ui/kit/toasts.tscn once (the HUD does); from anywhere else call
## Toast.show_message(get_tree(), "Picked up apple", icon), which is a no-op when no
## Toasts node exists.

const GROUP := &"Toasts"

## Seconds a toast stays fully visible.
@export var hold_time: float = 2.5
## Seconds the fade-out takes.
@export var fade_time: float = 0.4
## Oldest toasts are dropped beyond this many.
@export var max_visible: int = 4

@onready var _stack: VBoxContainer = $Stack


func _ready() -> void:
	add_to_group(GROUP)


## Find the Toasts node in `tree` and push a message; does nothing if absent.
static func show_message(tree: SceneTree, text: String, icon: Texture2D = null) -> void:
	var toasts := tree.get_first_node_in_group(GROUP) as Toast
	if toasts:
		toasts.push(text, icon)


## Add a toast with optional icon; it removes itself after hold_time + fade_time.
func push(text: String, icon: Texture2D = null) -> void:
	var toast := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	toast.add_child(row)
	if icon:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(12, 12)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(rect)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	_stack.add_child(toast)
	while _stack.get_child_count() > max_visible:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()
	var tween := toast.create_tween()
	tween.tween_interval(hold_time)
	tween.tween_property(toast, "modulate:a", 0.0, fade_time)
	tween.tween_callback(toast.queue_free)

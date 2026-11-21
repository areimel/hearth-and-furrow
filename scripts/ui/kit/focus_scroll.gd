class_name FocusScroll extends ScrollContainer
## A vertical ScrollContainer that keeps the focused child in view. With `scroll_keys`
## it also takes focus itself and scrolls with ui_up / ui_down, so pages of plain text
## stay reachable with a keyboard or gamepad.

## Pixels moved per ui_up / ui_down press.
const STEP := 12

## Take focus and scroll with the arrow keys / d-pad (for pages without focusable rows).
@export var scroll_keys: bool = false:
	set(value):
		scroll_keys = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	visibility_changed.connect(_on_visibility_changed)


# A freshly shown page may have scrolled to a stale position when focus landed before
# layout finished; once layout is done, start at the top (or on the focused child).
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_settle.call_deferred()


func _settle() -> void:
	scroll_vertical = 0
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused and is_ancestor_of(focused):
		ensure_control_visible(focused)


func _gui_input(event: InputEvent) -> void:
	if not scroll_keys:
		return
	if event.is_action_pressed(&"ui_down", true):
		scroll_vertical += STEP
		accept_event()
	elif event.is_action_pressed(&"ui_up", true):
		scroll_vertical -= STEP
		accept_event()


func _draw() -> void:
	if scroll_keys and has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), UIPalette.GOLD, false)

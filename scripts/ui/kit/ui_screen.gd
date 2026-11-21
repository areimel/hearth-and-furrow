class_name UIScreen extends Control
## Base for modal screens (inventory, shop, menu...). Call open() / close(); the screen
## grabs focus on open and closes itself on ui_cancel or menu. Gameplay code should ask
## UIScreen.any_open(get_tree()) and ignore its input while it is true.

signal opened
signal closed

const GROUP := &"UIScreen"
## Group of the HUD, told (refresh_screen_state) whenever a screen opens or closes.
const HUD_GROUP := &"HUD"

## Start hidden (the usual case for screens instanced into a HUD).
@export var start_closed: bool = true
## Control to focus on open; if empty the first focusable descendant is used.
@export var initial_focus: NodePath

var is_open: bool = false
var _opened_frame: int = -1


## True while any UIScreen under `tree` is open.
static func any_open(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		if node is UIScreen and node.is_open:
			return true
	return false


func _ready() -> void:
	add_to_group(GROUP)
	if start_closed:
		hide()


## Show the screen and move focus into it. No-op when already open.
func open() -> void:
	if is_open:
		return
	is_open = true
	_opened_frame = Engine.get_process_frames()
	show()
	_grab_initial_focus()
	get_tree().call_group(HUD_GROUP, &"refresh_screen_state")
	opened.emit()


## Hide the screen and release focus. No-op when already closed.
func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused):
		focused.release_focus()
	get_tree().call_group(HUD_GROUP, &"refresh_screen_state")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the press that opened us, since menu and ui_cancel can share a key.
	if not is_open or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func _grab_initial_focus() -> void:
	var target: Control = null
	if not initial_focus.is_empty():
		target = get_node_or_null(initial_focus) as Control
	if target == null:
		target = _first_focusable(self)
	if target:
		target.grab_focus()


func _first_focusable(root: Node) -> Control:
	for child in root.get_children():
		var control := child as Control
		if control and control.visible:
			if control.focus_mode == Control.FOCUS_ALL:
				return control
			var found := _first_focusable(control)
			if found:
				return found
	return null

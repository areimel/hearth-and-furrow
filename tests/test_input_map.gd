extends TestCase
## The [input] map in project.godot: every gameplay action is reachable on keyboard and
## gamepad, all bindings are all-devices, no gamepad control drives two gameplay actions, and
## the d-pad walks (and steers menus). Layout (Xbox naming): left stick + d-pad move, A action
## and accept, B cancel, X highlighter, Y build, LB/RB tool_backward/forward, Start menu.

const MOVE: Array[StringName] = [&"left", &"right", &"up", &"down"]
const UI_MOVE: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
## Joypad button indices (JoyButton): A, B, X, Y, Start, LB, RB, d-pad up/down/left/right.
const BTN_A := 0
const BTN_B := 1
const BTN_X := 2
const BTN_Y := 3
const BTN_START := 6
const BTN_LB := 9
const BTN_RB := 10
const DPAD: Dictionary = {&"up": 11, &"down": 12, &"left": 13, &"right": 14}
## Gameplay actions that need a gamepad binding (hotbar_N has number keys only; day_change
## is a debug key).
const PADDED: Array[StringName] = [&"left", &"right", &"up", &"down", &"action", &"tool_backward",
	&"tool_forward", &"build", &"highlighter", &"menu"]
const KEYBOARD_ONLY: Array[StringName] = [&"day_change"]


func _gameplay() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(PADDED)
	out.append_array(KEYBOARD_ONLY)
	for i in range(1, 11):
		out.append(StringName("hotbar_%d" % i))
	return out


func _buttons(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			out.append((event as InputEventJoypadButton).button_index)
	return out


func _count(action: StringName, type: String) -> int:
	var n := 0
	for event in InputMap.action_get_events(action):
		n += 1 if event.is_class(type) else 0
	return n


func test_every_gameplay_action_has_keyboard_and_gamepad() -> void:
	for action in _gameplay():
		check(InputMap.has_action(action), "%s exists" % action)
		check(_count(action, "InputEventKey") >= 1, "%s has a keyboard event" % action)
		if action in PADDED:
			var pad := _count(action, "InputEventJoypadButton") + _count(action, "InputEventJoypadMotion")
			check(pad >= 1, "%s has a gamepad event" % action)
		else:
			eq(_count(action, "InputEventJoypadButton") + _count(action, "InputEventJoypadMotion"), 0,
					"%s is not on the gamepad" % action)


func test_all_events_are_all_devices() -> void:
	var actions := _gameplay()
	actions.append_array([&"ui_accept", &"ui_cancel", &"ui_select"])
	actions.append_array(UI_MOVE)
	for action in actions:
		for event in InputMap.action_get_events(action):
			eq(event.device, -1, "%s event %s is all-devices" % [action, event.as_text()])


func test_no_gamepad_control_drives_two_gameplay_actions() -> void:
	var owner_of: Dictionary = {}
	for action in _gameplay():
		for event in InputMap.action_get_events(action):
			var key := ""
			if event is InputEventJoypadButton:
				key = "button %d" % (event as InputEventJoypadButton).button_index
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				key = "axis %d %s" % [motion.axis, "+" if motion.axis_value > 0.0 else "-"]
			if key.is_empty():
				continue
			check(not owner_of.has(key), "%s is bound to both %s and %s" % [key, owner_of.get(key), action])
			owner_of[key] = action


func test_dpad_and_stick_both_move() -> void:
	for action in MOVE:
		check(DPAD[action] in _buttons(action), "d-pad %s moves" % action)
		eq(_count(action, "InputEventJoypadMotion"), 1, "%s also has its stick direction" % action)
	for i in MOVE.size():
		check(DPAD[MOVE[i]] in _buttons(UI_MOVE[i]), "d-pad steers %s" % UI_MOVE[i])
		eq(_count(UI_MOVE[i], "InputEventJoypadMotion"), 1, "stick steers %s" % UI_MOVE[i])


func test_face_buttons_and_shoulders() -> void:
	check(BTN_A in _buttons(&"action") and BTN_A in _buttons(&"ui_accept"), "A acts and accepts")
	check(BTN_B in _buttons(&"ui_cancel"), "B cancels")
	check(BTN_X in _buttons(&"highlighter"), "X toggles the highlighter")
	check(BTN_Y in _buttons(&"build"), "Y opens build")
	check(BTN_LB in _buttons(&"tool_backward") and BTN_RB in _buttons(&"tool_forward"), "LB/RB cycle")
	check(BTN_START in _buttons(&"menu"), "Start opens the menu")
	check(not InputMap.has_action(&"diagnose"), "the dead diagnose action is gone")

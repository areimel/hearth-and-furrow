class_name InputGlyphs extends RefCounted
## Maps input ACTION names to the keyboard or gamepad icon for the device last used, so UI
## code never builds icon paths itself. Gamepad icons come from whatever the InputMap binds
## to the action (face, shoulder, trigger, start/back, d-pad and stick buttons all have an
## icon); only a few keyboard keys are curated. An action with no gamepad binding shows its
## keyboard key. Nodes whose glyphs must follow the device join GROUP and implement
## refresh_glyphs(); whoever reads input (the HUD) calls note_event() and refreshes the group.

const _INPUT_DIR := "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/"
const _KEYBOARD_DIR := _INPUT_DIR + "Keyboard/"
const _GAMEPAD_DIR := _INPUT_DIR + "Gamepad/"

## Group of nodes that show glyphs; each has refresh_glyphs().
const GROUP := &"GlyphUsers"

## Keyboard icons that differ from the key's own name (Space is a wide key).
const _KEYBOARD_CURATED := {&"action": "Space.png"}

## Gamepad button index (JoyButton) to icon file name (Gamepad/ folder: ButtonDown, ButtonRight,
## ButtonLeft, ButtonUp, ButtonLB, ButtonRB, ButtonLT, ButtonRT, Start, Select, DPad*,
## Joystick{Left,Right}[Pressed]). ButtonPlus*/ButtonMinus/DPad are alternates left unused.
const _PAD_FILES := {
	JOY_BUTTON_A: "ButtonDown", JOY_BUTTON_B: "ButtonRight", JOY_BUTTON_X: "ButtonLeft",
	JOY_BUTTON_Y: "ButtonUp", JOY_BUTTON_LEFT_SHOULDER: "ButtonLB",
	JOY_BUTTON_RIGHT_SHOULDER: "ButtonRB", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_DPAD_UP: "DPadUp", JOY_BUTTON_DPAD_DOWN: "DPadDown",
	JOY_BUTTON_DPAD_LEFT: "DPadLeft", JOY_BUTTON_DPAD_RIGHT: "DPadRight",
	JOY_BUTTON_LEFT_STICK: "JoystickLeftPressed", JOY_BUTTON_RIGHT_STICK: "JoystickRightPressed",
}
## Gamepad axis (JoyAxis) to icon file name.
const _AXIS_FILES := {
	JOY_AXIS_LEFT_X: "JoystickLeft", JOY_AXIS_LEFT_Y: "JoystickLeft",
	JOY_AXIS_RIGHT_X: "JoystickRight", JOY_AXIS_RIGHT_Y: "JoystickRight",
	JOY_AXIS_TRIGGER_LEFT: "ButtonLT", JOY_AXIS_TRIGGER_RIGHT: "ButtonRT",
}

## True while a gamepad is the device last used (note_event() keeps it current).
static var controller_connected: bool = false


## Record the device behind `event` (a pad button or stick push = pad; a key or mouse click
## = keyboard). True when that changed which glyphs should show.
static func note_event(event: InputEvent) -> bool:
	var pad := controller_connected
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or (event is InputEventMouseButton and event.pressed):
		pad = false
	if pad == controller_connected:
		return false
	controller_connected = pad
	return true


## Icon for `action` on the device last used, or null when the action has none.
static func texture_for(action: StringName) -> Texture2D:
	if not InputMap.has_action(action):
		return null
	if controller_connected:
		for event in InputMap.action_get_events(action):
			var pad_path := _pad_path(event)
			if pad_path != "" and ResourceLoader.exists(pad_path):
				return load(pad_path)
	if _KEYBOARD_CURATED.has(action):
		return load(_KEYBOARD_DIR + _KEYBOARD_CURATED[action])
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.keycode == KEY_NONE else event.keycode
			var path := _KEYBOARD_DIR + "Key%s.png" % OS.get_keycode_string(code)
			if ResourceLoader.exists(path):
				return load(path)
	return null


## Icon for a fixed key / gamepad button pair that has no input action (e.g. X to split).
static func texture_for_keys(key: Key, button: JoyButton) -> Texture2D:
	var path := _GAMEPAD_DIR + "%s.png" % _PAD_FILES.get(button, "") if controller_connected \
			else _KEYBOARD_DIR + "Key%s.png" % OS.get_keycode_string(key)
	return load(path) if ResourceLoader.exists(path) else null


static func _pad_path(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return _GAMEPAD_DIR + "%s.png" % _PAD_FILES.get(event.button_index, "")
	if event is InputEventJoypadMotion:
		return _GAMEPAD_DIR + "%s.png" % _AXIS_FILES.get(event.axis, "")
	return ""

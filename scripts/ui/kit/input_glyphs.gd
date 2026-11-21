class_name InputGlyphs extends RefCounted
## Maps input ACTION names to the keyboard or gamepad icon for the device in use,
## so UI code never touches Data.KEYBOARD_KEYS / Data.KEYBOARD_CONTROLLER directly.

const _INPUT_DIR := "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/"

## Actions that already have curated icons in Data's tables.
const _TABLE_KEYS := {
	&"action": Enum.KEYBOARD.ACTION,
	&"tool_forward": Enum.KEYBOARD.CHANGE_TOOL,
	&"seed_forward": Enum.KEYBOARD.CHANGE_SEED,
	&"day_change": Enum.KEYBOARD.CHANGE_DAY,
	&"build": Enum.KEYBOARD.CHANGE_MODE,
	&"highlighter": Enum.KEYBOARD.CHANGE_HIGHLIGHT,
}

## Gamepad button index (JoyButton) to icon file name.
const _PAD_FILES := {
	JOY_BUTTON_A: "ButtonDown", JOY_BUTTON_B: "ButtonRight", JOY_BUTTON_X: "ButtonLeft",
	JOY_BUTTON_Y: "ButtonUp", JOY_BUTTON_LEFT_SHOULDER: "ButtonLB",
	JOY_BUTTON_RIGHT_SHOULDER: "ButtonRB", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_DPAD_UP: "DPadUp", JOY_BUTTON_DPAD_DOWN: "DPadDown",
	JOY_BUTTON_DPAD_LEFT: "DPadLeft", JOY_BUTTON_DPAD_RIGHT: "DPadRight",
}


## Icon for `action` on the current device (gamepad when one is connected), or null.
static func texture_for(action: StringName) -> Texture2D:
	var pad: bool = Data.ControllerConnected
	if _TABLE_KEYS.has(action):
		var table: Dictionary = Data.KEYBOARD_CONTROLLER if pad else Data.KEYBOARD_KEYS
		return table[_TABLE_KEYS[action]]
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		var path := _path_for(event, pad)
		if path != "" and ResourceLoader.exists(path):
			return load(path)
	return null


## Icon for a fixed key / gamepad button pair that has no input action (e.g. X to split).
static func texture_for_keys(key: Key, button: JoyButton) -> Texture2D:
	var pad: bool = Data.ControllerConnected
	var path := _INPUT_DIR + ("Gamepad/%s.png" % _PAD_FILES.get(button, "") if pad
			else "Keyboard/Key%s.png" % OS.get_keycode_string(key))
	return load(path) if ResourceLoader.exists(path) else null


static func _path_for(event: InputEvent, pad: bool) -> String:
	if pad and event is InputEventJoypadButton:
		return _INPUT_DIR + "Gamepad/%s.png" % _PAD_FILES.get(event.button_index, "")
	if not pad and event is InputEventKey:
		var code: Key = event.physical_keycode if event.keycode == KEY_NONE else event.keycode
		return _INPUT_DIR + "Keyboard/Key%s.png" % OS.get_keycode_string(code)
	return ""

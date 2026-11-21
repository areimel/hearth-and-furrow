class_name InputGlyphs extends RefCounted
## Maps input ACTION names to the keyboard or gamepad icon for the device in use,
## so UI code never builds icon paths itself.

const _INPUT_DIR := "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/"

const _KEYBOARD_DIR := _INPUT_DIR + "Keyboard/"
const _GAMEPAD_DIR := _INPUT_DIR + "Gamepad/"

## Actions with curated icons: [keyboard file, gamepad file] under the input folder.
const _CURATED := {
	&"action": ["Keyboard/Space.png", "Gamepad/ButtonDown.png"],
	&"tool_forward": ["Keyboard/KeyE.png", "Gamepad/ButtonRB.png"],
	&"day_change": ["Keyboard/KeyTab.png", "Gamepad/ButtonPlusUp.png"],
	&"build": ["Keyboard/KeyM.png", "Gamepad/ButtonPlusLeft.png"],
	&"highlighter": ["Keyboard/KeyH.png", "Gamepad/ButtonPlusDown.png"],
}

## True while a gamepad is the device in use (Level keeps it current).
static var controller_connected: bool = false

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
	var pad := controller_connected
	if _CURATED.has(action):
		return load(_INPUT_DIR + _CURATED[action][1 if pad else 0])
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		var path := _path_for(event, pad)
		if path != "" and ResourceLoader.exists(path):
			return load(path)
	return null


## Icon for a fixed key / gamepad button pair that has no input action (e.g. X to split).
static func texture_for_keys(key: Key, button: JoyButton) -> Texture2D:
	var pad := controller_connected
	var path := _INPUT_DIR + ("Gamepad/%s.png" % _PAD_FILES.get(button, "") if pad
			else "Keyboard/Key%s.png" % OS.get_keycode_string(key))
	return load(path) if ResourceLoader.exists(path) else null


static func _path_for(event: InputEvent, pad: bool) -> String:
	if pad and event is InputEventJoypadButton:
		return _GAMEPAD_DIR + "%s.png" % _PAD_FILES.get(event.button_index, "")
	if not pad and event is InputEventKey:
		var code: Key = event.physical_keycode if event.keycode == KEY_NONE else event.keycode
		return _KEYBOARD_DIR + "Key%s.png" % OS.get_keycode_string(code)
	return ""

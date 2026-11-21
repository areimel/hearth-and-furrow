class_name KeyHints extends HBoxContainer
## A footer line of "[glyph] Label" pairs, e.g. "[A] Select  [B] Close". Glyphs follow
## the active device (keyboard or gamepad) and refresh when a pad connects.

var _hints: Array[Dictionary] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_id: int, _on: bool) -> void: _rebuild())


## Replace the hints. Each: {text: String} plus either `action: StringName` (an input
## action) or `key: Key` and `button: JoyButton` (a fixed pair with no action).
func set_hints(hints: Array[Dictionary]) -> void:
	_hints = hints
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
		remove_child(child)
	for hint in _hints:
		var item := IconLabel.new()
		item.add_theme_constant_override("separation", 2)
		item.set_content(_texture(hint), hint.get("text", ""))
		item.label().theme_type_variation = &"SmallLabel"
		add_child(item)


func _texture(hint: Dictionary) -> Texture2D:
	if hint.has("action"):
		return InputGlyphs.texture_for(hint["action"])
	return InputGlyphs.texture_for_keys(hint.get("key", KEY_NONE), hint.get("button", JOY_BUTTON_INVALID))

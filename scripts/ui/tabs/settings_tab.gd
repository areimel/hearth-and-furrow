class_name SettingsTab extends MenuTab
## Text size, time options, volumes, fullscreen, and the save-and-quit / quit buttons.
## Values live in the Settings autoload (GameSettings); this tab only edits them. The
## two buttons emit signals; what they do is up to the game.

## The player asked to save and return to the title screen.
signal save_and_quit_requested
## The player asked to quit the game.
signal quit_requested

var _settings: GameSettings
var _rows: Dictionary[StringName, SettingRow] = {}
var _focus_order: Array[Control] = []
var _buttons: HBoxContainer


func _ready() -> void:
	_settings = GameSettings.instance(get_tree())
	var scroll := FocusScroll.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	scroll.add_child(column)
	_option(column, &"text_size", "Text size", ["Normal", "Large"])
	_option(column, &"pause_in_menus", "Pause time in menus", ["Off", "On"])
	_option(column, &"relaxed_time", "Relaxed time (slower clock)", ["Off", "On"])
	_slider(column, &"master_volume", "Volume")
	if _settings.has_bus(&"music_volume"):
		_slider(column, &"music_volume", "Music")
	if _settings.has_bus(&"sfx_volume"):
		_slider(column, &"sfx_volume", "Sound effects")
	_option(column, &"fullscreen", "Fullscreen", ["Off", "On"])
	_build_buttons(column)
	_link_focus()


func tab_title() -> String:
	return "Settings"


func on_shown() -> void:
	for key in _rows:
		var setting := _rows[key]
		if setting is OptionRow:
			setting.select(_option_index(key))
		elif setting is SliderRow:
			setting.setup(setting.caption(), float(_settings.get_value(key)))


func initial_focus() -> Control:
	return _focus_order[0] if not _focus_order.is_empty() else null


func _option(parent: Control, key: StringName, caption: String, options: Array[String]) -> void:
	var option := OptionRow.new()
	option.setup(caption, options)
	option.option_changed.connect(func(index: int) -> void: _on_option(key, index, options))
	parent.add_child(option)
	_rows[key] = option
	_focus_order.append(option.button())


func _slider(parent: Control, key: StringName, caption: String) -> void:
	var slider := SliderRow.new()
	slider.setup(caption, float(_settings.get_value(key)))
	slider.value_changed.connect(func(value: float) -> void: _settings.set_value(key, value))
	parent.add_child(slider)
	_rows[key] = slider
	_focus_order.append(slider.slider())


func _build_buttons(parent: Control) -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	parent.add_child(_buttons)
	for entry in [["Save and quit to title", save_and_quit_requested], ["Quit", quit_requested]]:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var request: Signal = entry[1]
		button.pressed.connect(request.emit)
		_buttons.add_child(button)
	_focus_order.append(_buttons.get_child(0) as Control)


func _on_option(key: StringName, index: int, options: Array[String]) -> void:
	if key == &"text_size":
		_settings.set_value(key, options[index].to_lower())
	else:
		_settings.set_value(key, index == 1)


func _option_index(key: StringName) -> int:
	var value: Variant = _settings.get_value(key)
	if key == &"text_size":
		return 1 if value == "large" else 0
	return 1 if value else 0


# Wrap up/down through the rows; the button pair counts as one stop.
func _link_focus() -> void:
	var count := _focus_order.size()
	for i in count:
		var current := _focus_order[i]
		var above := _focus_order[posmod(i - 1, count)]
		var below := _focus_order[posmod(i + 1, count)]
		current.focus_neighbor_top = above.get_path()
		current.focus_neighbor_bottom = below.get_path()
	for button in _buttons.get_children():
		button.focus_neighbor_top = _focus_order[count - 2].get_path()
		button.focus_neighbor_bottom = _focus_order[0].get_path()

class_name OptionRow extends SettingRow
## A caption with a button that cycles through named options: accept or ui_right moves
## forward, ui_left back (wrapping). Use two options for an On / Off switch.

## The chosen option changed (by the player, not by select()).
signal option_changed(index: int)

var _button: Button
var _options: Array[String] = []
var _index: int = 0


func _init() -> void:
	super()
	_button = Button.new()
	_button.pressed.connect(func() -> void: _step(1))
	_button.gui_input.connect(_on_button_input)
	set_control(_button)


## Set the caption and the option names.
func setup(caption: String, options: Array[String]) -> void:
	set_caption(caption)
	_options = options
	select(_index)


## Show option `index` without emitting option_changed.
func select(index: int) -> void:
	_index = clampi(index, 0, maxi(_options.size() - 1, 0))
	_button.text = _options[_index] if not _options.is_empty() else ""


## Index of the shown option.
func selected() -> int:
	return _index


## The button, so a screen can focus it.
func button() -> Button:
	return _button


## Move `step` options (wrapping) as if the player had pressed the button.
func _step(step: int) -> void:
	select(posmod(_index + step, _options.size()))
	option_changed.emit(_index)


func _on_button_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		_step(1)
		_button.accept_event()
	elif event.is_action_pressed(&"ui_left"):
		_step(-1)
		_button.accept_event()

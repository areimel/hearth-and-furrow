class_name SettingRow extends HBoxContainer
## One line of a settings list: a caption on the left and a control on the right.
## OptionRow and SliderRow build on it; add other controls with set_control().

## Width given to the control column.
const CONTROL_WIDTH := 96

var _caption: Label
var _control: Control


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.clip_text = true
	add_child(_caption)


## Set the caption text.
func set_caption(text: String) -> void:
	_caption.text = text


## The caption text.
func caption() -> String:
	return _caption.text


## Place `control` in the right-hand column.
func set_control(control: Control) -> void:
	_control = control
	control.custom_minimum_size.x = CONTROL_WIDTH
	add_child(control)


## The focusable control, for focus setup and tests.
func control() -> Control:
	return _control

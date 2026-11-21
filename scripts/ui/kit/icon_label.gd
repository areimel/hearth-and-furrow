class_name IconLabel extends HBoxContainer
## A small icon followed by text on one line (a coin and its amount, a tick and its
## caption). The icon hides itself when there is no texture.

## Label text.
var text: String = "":
	set(value):
		text = value
		_label.text = value

## Icon shown before the text; null hides it.
var icon: Texture2D = null:
	set(value):
		icon = value
		_rect.texture = value
		_rect.visible = value != null

var _rect: TextureRect
var _label: Label


func _init() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = TextureRect.new()
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Set icon and text together.
func set_content(new_icon: Texture2D, new_text: String) -> void:
	icon = new_icon
	text = new_text


## The inner Label, for wrapping or size overrides.
func label() -> Label:
	return _label

class_name SliderRow extends SettingRow
## A caption with a 0..100 % slider and its value. Left/right (d-pad) change it in 10 %
## steps. Styled from UIPalette so it matches the rest of the kit.

## The value changed (0.0 .. 1.0).
signal value_changed(value: float)

var _slider: HSlider
var _percent: Label


func _init() -> void:
	super()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size.y = 10
	_slider.value_changed.connect(_on_slider_changed)
	_style(_slider)
	box.add_child(_slider)
	_percent = Label.new()
	_percent.custom_minimum_size.x = 24
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_percent)
	set_control(box)


## Set the caption and the starting value (no signal).
func setup(caption: String, value: float) -> void:
	set_caption(caption)
	_slider.set_value_no_signal(value)
	_percent.text = "%d%%" % roundi(value * 100.0)


## The slider, so a screen can focus it.
func slider() -> HSlider:
	return _slider


func _on_slider_changed(value: float) -> void:
	_percent.text = "%d%%" % roundi(value * 100.0)
	value_changed.emit(value)


func _style(slider: HSlider) -> void:
	var rail := _box(UIPalette.WOOD_DARK, UIPalette.INK, 2)
	var fill := _box(UIPalette.MOSS, UIPalette.MOSS, 2)
	var grabber := Image.create(5, 9, false, Image.FORMAT_RGBA8)
	grabber.fill(UIPalette.WOOD)
	for x in 5:
		grabber.set_pixel(x, 0, UIPalette.WOOD_DARK)
		grabber.set_pixel(x, 8, UIPalette.WOOD_DARK)
	var light := grabber.duplicate() as Image
	light.fill_rect(Rect2i(1, 1, 3, 7), UIPalette.GOLD)
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", ImageTexture.create_from_image(grabber))
	slider.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(light))
	slider.add_theme_icon_override("grabber_disabled", ImageTexture.create_from_image(grabber))
	slider.add_theme_stylebox_override("focus", _focus_box())


func _box(fill: Color, edge: Color, height: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.content_margin_top = height
	box.content_margin_bottom = height
	return box


func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = UIPalette.GOLD
	box.set_border_width_all(1)
	box.anti_aliasing = false
	return box

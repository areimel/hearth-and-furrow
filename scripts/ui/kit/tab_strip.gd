class_name TabStrip extends HBoxContainer
## A row of tab titles with the selected one raised, flanked by the input glyphs that
## switch tabs (by default tool_backward / tool_forward: Q and E, or the shoulder
## buttons). The strip is display-only: buttons take no focus, the owner calls select().

## A tab title was clicked.
signal tab_pressed(index: int)

## Show the back/forward glyphs at either end.
@export var show_hints: bool = true

var _buttons: Array[Button] = []
var _selected: int = -1
var _back_action: StringName = &"tool_backward"
var _forward_action: StringName = &"tool_forward"
var _back: TextureRect
var _forward: TextureRect
var _tabs_box: HBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 3)
	_back = _glyph_rect()
	add_child(_back)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 1)
	_tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_tabs_box)
	_forward = _glyph_rect()
	add_child(_forward)


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_id: int, _on: bool) -> void: _refresh_glyphs())
	_refresh_glyphs()


## Use other actions for the glyphs (e.g. ui_left / ui_right for a sub-page strip).
func set_hint_actions(back: StringName, forward: StringName) -> void:
	_back_action = back
	_forward_action = forward
	_refresh_glyphs()


## Replace the tabs with buttons titled `titles`; the first becomes selected.
func set_tabs(titles: Array[String]) -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for i in titles.size():
		var button := Button.new()
		button.text = titles[i]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: tab_pressed.emit(i))
		_tabs_box.add_child(button)
		_buttons.append(button)
	_selected = -1
	select(0)


## Raise the tab at `index`.
func select(index: int) -> void:
	if _buttons.is_empty():
		return
	_selected = clampi(index, 0, _buttons.size() - 1)
	for i in _buttons.size():
		_style(_buttons[i], i == _selected)


## Index of the raised tab.
func selected_index() -> int:
	return _selected


## Number of tabs.
func count() -> int:
	return _buttons.size()


## `index + step` wrapped into 0 .. count-1.
func wrapped(index: int, step: int) -> int:
	return posmod(index + step, maxi(_buttons.size(), 1))


func _style(button: Button, raised: bool) -> void:
	var fill := UIPalette.PARCHMENT_LIGHT if raised else UIPalette.WOOD
	var edge := UIPalette.GOLD if raised else UIPalette.WOOD_DARK
	var font := UIPalette.INK if raised else UIPalette.PARCHMENT_LIGHT
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = edge
		box.set_border_width_all(1)
		box.border_width_bottom = 2 if raised else 1
		box.content_margin_left = 4
		box.content_margin_right = 4
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		box.anti_aliasing = false
		button.add_theme_stylebox_override(state, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, font)


func _glyph_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.custom_minimum_size = Vector2(14, 0)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _refresh_glyphs() -> void:
	_back.texture = InputGlyphs.texture_for(_back_action)
	_forward.texture = InputGlyphs.texture_for(_forward_action)
	_back.visible = show_hints
	_forward.visible = show_hints

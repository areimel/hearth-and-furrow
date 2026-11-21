class_name TabStrip extends HBoxContainer
## A row of tab titles with the selected one raised, flanked by the input glyphs that
## switch tabs (by default tool_backward / tool_forward: Q and E, or the shoulder
## buttons). While visible it listens for those actions and emits `tab_stepped`; buttons
## take no focus and the owner calls select().

## A tab title was clicked.
signal tab_pressed(index: int)
## The back / forward action was pressed while the strip is visible; `index` is the tab to
## show next (wrapped). The strip does not select it: the owner calls select().
signal tab_stepped(index: int)

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
	add_to_group(InputGlyphs.GROUP)
	refresh_glyphs()


## Use other actions for glyphs and stepping (e.g. ui_left / ui_right for a sub-page strip).
func set_hint_actions(back: StringName, forward: StringName) -> void:
	_back_action = back
	_forward_action = forward
	refresh_glyphs()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo() or _buttons.size() < 2:
		return
	for step in [-1, 1]:
		if event.is_action_pressed(_forward_action if step > 0 else _back_action):
			get_viewport().set_input_as_handled()
			tab_stepped.emit(wrapped(_selected, step))
			return


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
		_buttons[i].theme_type_variation = &"TabButtonRaised" if i == _selected else &"TabButton"


## Index of the raised tab.
func selected_index() -> int:
	return _selected


## Number of tabs.
func count() -> int:
	return _buttons.size()


## `index + step` wrapped into 0 .. count-1.
func wrapped(index: int, step: int) -> int:
	return posmod(index + step, maxi(_buttons.size(), 1))


func _glyph_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.custom_minimum_size = Vector2(14, 0)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Redraw the back / forward glyphs for the current device (InputGlyphs.GROUP calls this).
func refresh_glyphs() -> void:
	_back.texture = InputGlyphs.texture_for(_back_action)
	_forward.texture = InputGlyphs.texture_for(_forward_action)
	_back.visible = show_hints
	_forward.visible = show_hints

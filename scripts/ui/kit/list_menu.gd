class_name ListMenu extends ScrollContainer
## Vertical list of focusable text entries for keyboard and gamepad (ui_up/ui_down move,
## ui_accept selects, ui_cancel emits `cancelled`). Longer lists scroll and the focused
## entry is kept in view. Focus wraps from last to first and back.

## An entry was activated (ui_accept or click). Disabled entries never emit this.
signal entry_selected(payload: Variant)
## Focus moved onto an entry.
signal entry_focused(payload: Variant)
## ui_cancel was pressed while focus was inside the list.
signal cancelled

## Every row is this tall so icon and text-only entries line up.
const ROW_HEIGHT := 16

## Rows visible before the list starts scrolling.
@export var max_rows: int = 6

var _rows: VBoxContainer
var _buttons: Array[Button] = []


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 1)
	add_child(_rows)


## Replace the entries. Each: {text: String, icon: Texture2D (optional),
## disabled: bool (optional), payload: Variant (optional)}.
func set_entries(entries: Array[Dictionary]) -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for entry in entries:
		_buttons.append(_make_button(entry))
	for i in _buttons.size():
		var button := _buttons[i]
		button.focus_neighbor_top = _buttons[posmod(i - 1, _buttons.size())].get_path()
		button.focus_neighbor_bottom = _buttons[posmod(i + 1, _buttons.size())].get_path()
	_fit_height.call_deferred()


## Number of entries.
func entry_count() -> int:
	return _buttons.size()


## Focus the first enabled entry (call after the menu becomes visible).
func focus_first() -> void:
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


## The button for entry `index`, e.g. for tests or custom decoration.
func entry_button(index: int) -> Button:
	return _buttons[index]


## Show entry `index` greyed (still focusable and selectable, unlike `disabled`), e.g. a
## recipe that cannot be started or a ware that cannot be afforded.
func set_entry_greyed(index: int, greyed: bool) -> void:
	var button := _buttons[index]
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		if greyed:
			button.add_theme_color_override(state, UIPalette.INK_DISABLED)
		else:
			button.remove_theme_color_override(state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _focus_inside():
		cancelled.emit()


func _make_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"ListEntry"
	button.text = entry.get("text", "")
	button.icon = entry.get("icon") as Texture2D
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.disabled = entry.get("disabled", false)
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = ROW_HEIGHT
	var payload: Variant = entry.get("payload")
	button.pressed.connect(func() -> void: entry_selected.emit(payload))
	button.focus_entered.connect(func() -> void: entry_focused.emit(payload))
	_rows.add_child(button)
	return button


func _fit_height() -> void:
	if _buttons.is_empty():
		custom_minimum_size.y = 0
		return
	var row_height := ROW_HEIGHT
	for button in _buttons:
		row_height = maxi(row_height, ceili(button.get_combined_minimum_size().y))
	var row := row_height + _rows.get_theme_constant("separation")
	custom_minimum_size.y = min(_buttons.size(), max_rows) * row - 1


func _focus_inside() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and is_ancestor_of(focused)

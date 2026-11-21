class_name AlmanackTab extends MenuTab
## Two pages under one tab: the Almanack (date, weather lore, calendar, what to sow)
## and the Discoveries list. ui_left / ui_right switch pages.

var _strip: TabStrip
var _page: AlmanackPage
var _items: AlmanackItemsPage
var _index: int = 0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	_strip = TabStrip.new()
	_strip.set_hint_actions(&"ui_left", &"ui_right")
	_strip.set_tabs(["Almanack", "Discoveries"])
	_strip.tab_pressed.connect(show_page)
	column.add_child(_strip)
	_page = AlmanackPage.new()
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_page)
	_items = AlmanackItemsPage.new()
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_items)


func tab_title() -> String:
	return "Almanack"


func on_shown() -> void:
	_page.refresh()
	_items.refresh()
	show_page(_index)


func initial_focus() -> Control:
	if _index == 1:
		var target := _items.focus_target()
		if target:
			return target
	return _page


func hints() -> Array[Dictionary]:
	return [{"action": &"ui_left", "text": "Page"}]


## Show page 0 (almanack) or 1 (discoveries) and move focus into it.
func show_page(index: int) -> void:
	_index = posmod(index, 2)
	_strip.select(_index)
	_page.visible = _index == 0
	_items.visible = _index == 1
	if is_visible_in_tree():
		var target := initial_focus()
		if target:
			target.grab_focus()


## The shown page index.
func page_index() -> int:
	return _index


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_right"):
		show_page(_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		show_page(_index - 1)
		get_viewport().set_input_as_handled()

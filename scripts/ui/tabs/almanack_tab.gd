class_name AlmanackTab extends MenuTab
## Three pages under one tab: the Almanack (date, weather lore, calendar, what to sow),
## the Discoveries list and Lore (history notes for what the player has met).
## ui_left / ui_right switch pages.

var _strip: TabStrip
var _pages: Array[Control] = []
var _index: int = 0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	_strip = TabStrip.new()
	_strip.set_hint_actions(&"ui_left", &"ui_right")
	_strip.set_tabs(["Almanack", "Discoveries", "Lore"])
	_strip.tab_pressed.connect(show_page)
	_strip.tab_stepped.connect(show_page)
	column.add_child(_strip)
	for page: Control in [AlmanackPage.new(), AlmanackItemsPage.new(), AlmanackLorePage.new()]:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(page)
		_pages.append(page)


func tab_title() -> String:
	return "Almanack"


func on_shown() -> void:
	for page in _pages:
		page.refresh()
	show_page(_index)


func initial_focus() -> Control:
	if _index == 1:
		var target := (_pages[1] as AlmanackItemsPage).focus_target()
		if target:
			return target
	return _pages[_index]


func hints() -> Array[Dictionary]:
	return [{"action": &"ui_left", "text": "Page"}]


## Show page 0 (almanack), 1 (discoveries) or 2 (lore) and move focus into it.
func show_page(index: int) -> void:
	_index = posmod(index, _pages.size())
	_strip.select(_index)
	for i in _pages.size():
		_pages[i].visible = i == _index
	if is_visible_in_tree():
		var target := initial_focus()
		if target:
			target.grab_focus()

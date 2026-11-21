class_name GameMenu extends UIScreen
## The tabbed pause menu. Instance scenes/ui/menu.tscn once under the level's overlay and
## call open() (or open_tab()) when the `menu` action is pressed; it closes itself on
## menu / ui_cancel. tool_backward / tool_forward (Q / E, shoulder buttons) switch tabs.
## The game clock is paused while it is open (unless the player turned that off).
##
## Adding a tab: write a scene whose root script extends MenuTab and add ONE line to TABS.

## "Save and quit to title" was chosen in the Settings tab.
signal save_and_quit_requested
## "Quit" was chosen in the Settings tab.
signal quit_requested
## A different tab became the visible one.
signal tab_changed(tab_id: StringName)

const MENU_GROUP := &"GameMenu"
## Every tab, in strip order. Each scene's root script extends MenuTab.
const TABS: Array[Dictionary] = [
	{"id": &"pack", "scene": "res://scenes/ui/tabs/pack_tab.tscn"},
	{"id": &"journal", "scene": "res://scenes/ui/tabs/journal_tab.tscn"},
	{"id": &"folk", "scene": "res://scenes/ui/tabs/folk_tab.tscn"},
	{"id": &"almanack", "scene": "res://scenes/ui/tabs/almanack_tab.tscn"},
	{"id": &"settings", "scene": "res://scenes/ui/tabs/settings_tab.tscn"},
]
## Window size in screen pixels; fits 320x180 with a small margin.
const WINDOW_SIZE := Vector2(304, 170)

var _tabs: Array[MenuTab] = []
var _index: int = 0
var _last_focus: Dictionary[int, Control] = {}
var _clock_paused_by_menu: bool = false
var _strip: TabStrip
var _hints: KeyHints


func _ready() -> void:
	super()
	add_to_group(MENU_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UIPalette.SHADOW
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var window := PanelContainer.new()
	window.custom_minimum_size = WINDOW_SIZE
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	window.add_child(column)
	_strip = TabStrip.new()
	_strip.tab_pressed.connect(show_tab)
	column.add_child(_strip)
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	column.add_child(host)
	_hints = KeyHints.new()
	column.add_child(_hints)
	_build_tabs(host)


func _exit_tree() -> void:
	_set_clock_paused(false)


## Open the menu on the tab remembered from last time.
func open() -> void:
	if is_open:
		return
	_set_clock_paused(true)
	_show_tab_content(_index)
	super()


## Close the menu and let the clock run again.
func close() -> void:
	if not is_open:
		return
	_set_clock_paused(false)
	super()


## Open the menu (if closed) on the tab with id `tab_id`; unknown ids are ignored.
func open_tab(tab_id: StringName) -> void:
	var index := tab_ids().find(tab_id)
	if index < 0:
		return
	_index = index
	if is_open:
		show_tab(index)
	else:
		open()


## Open if closed, close if open.
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Show the tab at `index` (wrapped) and move focus into it.
func show_tab(index: int) -> void:
	var previous := _tab_focus_owner()
	if previous:
		_last_focus[_index] = previous
	_index = posmod(index, _tabs.size())
	_show_tab_content(_index)
	_focus_tab(_index)


## Switch by `step` tabs (+1 forward, -1 back), wrapping around the ends.
func switch_tab(step: int) -> void:
	show_tab(_strip.wrapped(_index, step))


## Ids of all tabs in order.
func tab_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in TABS:
		out.append(entry["id"])
	return out


## The tab scene shown now.
func current_tab() -> MenuTab:
	return _tabs[_index]


## The tab with id `tab_id`, or null.
func tab(tab_id: StringName) -> MenuTab:
	var index := tab_ids().find(tab_id)
	return _tabs[index] if index >= 0 else null


## Index of the visible tab.
func current_index() -> int:
	return _index


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"tool_forward"):
		switch_tab(1)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(&"tool_backward"):
		switch_tab(-1)
		get_viewport().set_input_as_handled()
	else:
		super(event)


func _grab_initial_focus() -> void:
	_focus_tab(_index, false)


func _build_tabs(host: Control) -> void:
	var titles: Array[String] = []
	for entry in TABS:
		var node: MenuTab = load(entry["scene"]).instantiate()
		node.hide()
		host.add_child(node)
		_tabs.append(node)
		titles.append(node.tab_title())
		for signal_name in [&"save_and_quit_requested", &"quit_requested"]:
			if node.has_signal(signal_name):
				node.connect(signal_name, func() -> void: emit_signal(signal_name))
	_strip.set_tabs(titles)


func _show_tab_content(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].visible = i == index
	_strip.select(index)
	_tabs[index].on_shown()
	var footer: Array[Dictionary] = _tabs[index].hints()
	footer.append({"action": &"ui_cancel", "text": "Close"})
	_hints.set_hints(footer)
	tab_changed.emit(TABS[index]["id"])


# Focus the remembered control of the tab (when `restore`) or its natural first one.
func _focus_tab(index: int, restore: bool = true) -> void:
	var target: Control = _last_focus.get(index) if restore else null
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		target = _tabs[index].initial_focus()
	if target == null:
		target = _first_focusable(_tabs[index])
	if target:
		target.grab_focus()


func _tab_focus_owner() -> Control:
	var focused := get_viewport().gui_get_focus_owner()
	if focused and _tabs[_index].is_ancestor_of(focused):
		return focused
	return null


func _set_clock_paused(paused: bool) -> void:
	if paused and not GameClock.paused:
		var settings := GameSettings.instance(get_tree())
		if settings.get_value(&"pause_in_menus", true):
			GameClock.set_paused(true)
			_clock_paused_by_menu = true
	elif not paused and _clock_paused_by_menu:
		GameClock.set_paused(false)
		_clock_paused_by_menu = false

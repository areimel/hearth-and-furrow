class_name BuildMenu extends UIScreen
## Modal list of every station the player can build, plus "Remove a structure". Left: the
## entries (greyed when the Inventory lacks the build cost); right: the focused station's
## description and cost as have/need item slots. Choosing an affordable station closes the
## menu and emits `station_chosen`; BuildMode takes it from there. Instance
## scenes/ui/build_menu.tscn once under the HUD menus; BuildMode finds it by group.

## A station was chosen to place.
signal station_chosen(station_id: StringName)
## "Remove a structure" was chosen.
signal remove_chosen

const BUILD_GROUP := &"BuildMenu"
const REMOVE_ENTRY := &"@remove"
const LIST_WIDTH := 104
const FRAME_WIDTH := 270
const WRAP_WIDTH := 120

var _menu: ListMenu
var _frame: PanelFrame
var _title: Label
var _desc: Label
var _needs: HBoxContainer
var _note: Label
var _ids: Array[StringName] = []
var _focused: StringName = &""


func _ready() -> void:
	super()
	add_to_group(BUILD_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UIPalette.SHADOW
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_frame = preload("res://scenes/ui/kit/panel_frame.tscn").instantiate()
	_frame.min_width = FRAME_WIDTH
	_frame.title = "Build"
	add_child(_frame)
	_build_body()
	Inventory.changed.connect(_refresh)


## Open the menu with the current Inventory counts.
func open_menu() -> void:
	_fill_list()
	open()
	_menu.entry_button(0).grab_focus()
	_focused = _ids[0]
	_refresh()


## Ids of the entries in list order (the last is REMOVE_ENTRY).
func entry_ids() -> Array[StringName]:
	return _ids.duplicate()


## Whether the entry at `index` is shown greyed (a station that cannot be afforded).
func is_entry_greyed(index: int) -> bool:
	return _ids[index] != REMOVE_ENTRY and not _affordable(_ids[index])


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 4)
	_menu = ListMenu.new()
	_menu.custom_minimum_size.x = LIST_WIDTH
	_menu.max_rows = 6
	_menu.entry_selected.connect(_on_entry_selected)
	_menu.entry_focused.connect(_on_entry_focused)
	columns.add_child(_menu)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	detail.add_child(_title)
	_desc = _wrapped_label(UIPalette.INK)
	detail.add_child(_desc)
	_needs = HBoxContainer.new()
	_needs.add_theme_constant_override("separation", 1)
	detail.add_child(_needs)
	_note = _wrapped_label(UIPalette.CRIMSON)
	detail.add_child(_note)
	columns.add_child(detail)
	_frame.add_content(columns)


func _wrapped_label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WRAP_WIDTH
	label.add_theme_color_override("font_color", color)
	return label


func _fill_list() -> void:
	var entries: Array[Dictionary] = []
	_ids.clear()
	for row in Content.stations():
		entries.append({"text": row.display_name, "payload": row.id})
		_ids.append(row.id)
	entries.append({"text": "Remove a structure", "payload": REMOVE_ENTRY})
	_ids.append(REMOVE_ENTRY)
	_menu.set_entries(entries)


func _refresh() -> void:
	if not is_open:
		return
	for i in _ids.size():
		_grey(_menu.entry_button(i), is_entry_greyed(i))
	_show_detail()


func _show_detail() -> void:
	for child in _needs.get_children():
		_needs.remove_child(child)
		child.queue_free()
	_note.visible = false
	if _focused == REMOVE_ENTRY:
		_title.text = "Remove a structure"
		_desc.text = "Take down a station. Half its materials come back; it must be idle and empty."
		return
	var row := Content.station(_focused)
	_title.text = row.display_name
	_desc.text = row.description
	var caption := Label.new()
	caption.text = "Needs"
	caption.custom_minimum_size.x = 30
	_needs.add_child(caption)
	for id: StringName in row.build_cost:
		var need: int = int(row.build_cost[id])
		var have := Inventory.count(id)
		var slot := ItemSlot.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_item(id, need)
		slot.set_count_text("%d/%d" % [have, need],
				UIPalette.CRIMSON if have < need else UIPalette.PARCHMENT_LIGHT)
		slot.dimmed = have < need
		_needs.add_child(slot)
	_note.text = "" if _affordable(_focused) else "Missing materials"
	_note.visible = not _note.text.is_empty()


func _affordable(station_id: StringName) -> bool:
	var row := Content.station(station_id)
	for id: StringName in row.build_cost:
		if not Inventory.has(id, int(row.build_cost[id])):
			return false
	return true


func _grey(button: Button, greyed: bool) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		if greyed:
			button.add_theme_color_override(state, UIPalette.INK_DISABLED)
		else:
			button.remove_theme_color_override(state)


func _on_entry_focused(payload: StringName) -> void:
	_focused = payload
	_show_detail()


func _on_entry_selected(payload: StringName) -> void:
	if payload == REMOVE_ENTRY:
		close()
		remove_chosen.emit()
	elif _affordable(payload):
		close()
		station_chosen.emit(payload)
	else:
		Toast.show_message(get_tree(), "Missing materials")

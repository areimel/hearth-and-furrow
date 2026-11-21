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

var _menu: ListMenu
var _frame: PanelFrame
var _detail: DetailPane
var _ids: Array[StringName] = []
var _focused: StringName = &""


func _ready() -> void:
	super()
	add_to_group(BUILD_GROUP)
	_frame = build_modal(FRAME_WIDTH)
	_frame.title = "Build"
	_detail = DetailPane.new()
	var columns := ListDetail.new(LIST_WIDTH, _detail)
	_menu = columns.menu
	_menu.entry_selected.connect(_on_entry_selected)
	_menu.entry_focused.connect(_on_entry_focused)
	_frame.add_content(columns)
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
		_menu.set_entry_greyed(i, is_entry_greyed(i))
	_show_detail()


func _show_detail() -> void:
	if _focused == REMOVE_ENTRY:
		_detail.show_info("Remove a structure",
				"Take down a station. Half its materials come back; it must be idle and empty.")
		return
	var row := Content.station(_focused)
	_detail.show_info(row.display_name, row.description, [], row.build_cost,
			Loot.shortfall(row.build_cost))


func _affordable(station_id: StringName) -> bool:
	return Loot.has_all(Content.station(station_id).build_cost)


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

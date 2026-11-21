class_name PackTab extends MenuTab
## Backpack (slots 10..) above the hotbar row (slots 0..9) with a detail panel and the
## coin total. Accept picks a slot up, accept on another slot moves / swaps / merges
## (Inventory.move); accept again on the picked-up slot uses a capacity item (linen
## sack) or puts it down. X (or the pad's X) splits the focused stack.

const COLUMNS := 6
const VISIBLE_ROWS := 5
const HOTBAR := 10
const CELL_STRIDE := ItemSlot.CELL + 1

var _pack: ItemGrid
var _hotbar: ItemGrid
var _scroll: FocusScroll
var _detail: ItemDetail
var _purse: IconLabel
var _pack_size: int = -1
## Inventory index picked up for a move, -1 when nothing is held.
var _held: int = -1
## Inventory index of the slot under the cursor.
var _focused: int = 0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	column.add_child(top)
	_scroll = FocusScroll.new()
	_scroll.custom_minimum_size = Vector2(COLUMNS * CELL_STRIDE + 2, VISIBLE_ROWS * CELL_STRIDE - 1)
	_pack = ItemGrid.new()
	_pack.columns = COLUMNS
	_scroll.add_child(_pack)
	top.add_child(_scroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = ItemDetail.new()
	panel.add_child(_detail)
	top.add_child(panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	column.add_child(bottom)
	_hotbar = ItemGrid.new()
	_hotbar.columns = HOTBAR
	bottom.add_child(_hotbar)
	_hotbar.bind_inventory(0, HOTBAR)
	_purse = IconLabel.new()
	_purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_purse.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(_purse)
	_hotbar.slot_activated.connect(_activate)
	_hotbar.slot_focused.connect(_focus_changed.bind(0))
	_pack.slot_activated.connect(func(i: int) -> void: _activate(HOTBAR + i))
	_pack.slot_focused.connect(_focus_changed.bind(HOTBAR))
	Economy.coins_changed.connect(func(_c: int, _d: int) -> void: _refresh_purse())
	Inventory.capacity_changed.connect(func(_c: int) -> void: _rebind_pack())


func tab_title() -> String:
	return "Pack"


func on_shown() -> void:
	_held = -1
	_rebind_pack()
	_refresh_purse()
	_refresh_marks()
	_show_detail()


func initial_focus() -> Control:
	return _hotbar.slot_at(Inventory.selected_hotbar_index)


func hints() -> Array[Dictionary]:
	return [{"action": &"ui_accept", "text": "Pick up / drop"},
		{"key": KEY_X, "button": JOY_BUTTON_X, "text": "Split"}]


## Pick up, drop or use the slot at inventory index `index` (what accept does).
func activate_slot(index: int) -> void:
	_activate(index)


## Split the stack at inventory index `index`; returns the new slot or -1.
func split_slot(index: int) -> int:
	var target := Inventory.split(index)
	_show_detail()
	return target


## Inventory index currently picked up, or -1.
func held_index() -> int:
	return _held


## The grids, for tests and layout checks.
func grids() -> Array[ItemGrid]:
	return [_pack, _hotbar]


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	if (key and key.physical_keycode == KEY_X) or (pad and pad.button_index == JOY_BUTTON_X):
		split_slot(_focused)
		get_viewport().set_input_as_handled()


func _activate(index: int) -> void:
	if _held < 0:
		if Inventory.is_slot_empty(index):
			return
		_held = index
	elif _held == index:
		var item := Inventory.slot_item(index)
		if item and item.backpack_slots > 0 and Inventory.use_capacity_item(index):
			Toast.show_message(get_tree(), "Pack grows by %d slots" % item.backpack_slots, item.icon)
		_held = -1
	else:
		Inventory.move(_held, index)
		_held = -1
	_refresh_marks()
	_show_detail()


func _focus_changed(grid_index: int, first: int) -> void:
	_focused = first + grid_index
	_show_detail()


func _show_detail() -> void:
	var item := Inventory.slot_item(_focused)
	var note := ""
	if _held >= 0 and Inventory.is_slot_empty(_held):
		_held = -1
	if _held >= 0 and _held != _focused:
		note = "Moving %s: choose a slot." % Inventory.slot_item(_held).display_name
	elif _held == _focused and item:
		note = "Press again to use." if item.backpack_slots > 0 else "Choose where to put it."
	elif item and item.backpack_slots > 0:
		note = "Pick up, then press again: +%d pack slots." % item.backpack_slots
	_detail.show_item(Inventory.slot_id(_focused), note)


func _refresh_marks() -> void:
	for i in _pack.slot_count():
		_pack.slot_at(i).selected = HOTBAR + i == _held
	for i in _hotbar.slot_count():
		_hotbar.slot_at(i).selected = i == _held


func _refresh_purse() -> void:
	_purse.set_content(StatusIcons.coin(), UIText.coins(Economy.coins))


func _rebind_pack() -> void:
	var count := Inventory.size() - HOTBAR
	if count != _pack_size:
		_pack_size = count
		_pack.bind_inventory(HOTBAR, count)
		var rows := ceili(float(count) / COLUMNS)
		_scroll.custom_minimum_size.y = mini(rows, VISIBLE_ROWS) * CELL_STRIDE - 1
		_link_grids()
	_refresh_marks()


# Down from the pack's last row lands on the hotbar and up from the hotbar returns.
func _link_grids() -> void:
	var count := _pack.slot_count()
	var rows := ceili(float(count) / COLUMNS)
	for col in COLUMNS:
		var last := col + (rows - 1) * COLUMNS
		while last >= count:
			last -= COLUMNS
		var hotbar_slot := _hotbar.slot_at(roundi(col * (HOTBAR - 1) / float(COLUMNS - 1)))
		_pack.slot_at(last).focus_neighbor_bottom = hotbar_slot.get_path()
	for i in HOTBAR:
		var target := mini(roundi(i * (COLUMNS - 1) / float(HOTBAR - 1)), count - 1)
		var column_last := target + ((count - 1 - target) / COLUMNS) * COLUMNS
		_hotbar.slot_at(i).focus_neighbor_top = _pack.slot_at(column_last).get_path()

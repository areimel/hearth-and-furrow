class_name ItemGrid extends GridContainer
## A grid of ItemSlots with keyboard/gamepad focus navigation (ui_* actions, wrapping
## at the edges). Either mirror live Inventory slots with bind_inventory() or show
## any list with set_items().

## A slot was pressed/accepted; `index` is its position in the grid.
signal slot_activated(index: int)
## Focus moved onto a slot.
signal slot_focused(index: int)

var _slots: Array[ItemSlot] = []
var _first_index: int = 0
var _bound: bool = false


func _init() -> void:
	columns = 5
	add_theme_constant_override("h_separation", 1)
	add_theme_constant_override("v_separation", 1)


func _exit_tree() -> void:
	_unbind()


## Number of slots.
func slot_count() -> int:
	return _slots.size()


## The slot at `index`.
func slot_at(index: int) -> ItemSlot:
	return _slots[index]


## Focus the first slot (call once the grid is visible).
func focus_first() -> void:
	if not _slots.is_empty():
		_slots[0].grab_focus()


## Mirror Inventory slots first_index .. first_index + count - 1, updating live.
func bind_inventory(first_index: int, count: int) -> void:
	_unbind()
	_bound = true
	_first_index = first_index
	_resize(count)
	Inventory.slot_changed.connect(_on_slot_changed)
	Inventory.changed.connect(_refresh_bound)
	_refresh_bound()


## Show an arbitrary list of {id: StringName, count: int}; stops any inventory binding.
func set_items(items: Array[Dictionary]) -> void:
	_unbind()
	_resize(items.size())
	for i in items.size():
		_slots[i].set_item(items[i].get("id", &""), int(items[i].get("count", 1)))


func _unbind() -> void:
	if not _bound:
		return
	_bound = false
	if Inventory.slot_changed.is_connected(_on_slot_changed):
		Inventory.slot_changed.disconnect(_on_slot_changed)
	if Inventory.changed.is_connected(_refresh_bound):
		Inventory.changed.disconnect(_refresh_bound)


func _resize(count: int) -> void:
	while _slots.size() > count:
		_slots.pop_back().queue_free()
	while _slots.size() < count:
		var slot := ItemSlot.new()
		var index := _slots.size()
		slot.activated.connect(func(_s: ItemSlot) -> void: slot_activated.emit(index))
		slot.focus_entered.connect(func() -> void: slot_focused.emit(index))
		add_child(slot)
		_slots.append(slot)
	_link_focus()


func _link_focus() -> void:
	var n := _slots.size()
	var cols := maxi(columns, 1)
	for i in n:
		var slot := _slots[i]
		var row := i / cols
		var col := i % cols
		slot.focus_neighbor_left = _slots[_wrap_row(row, col - 1, n, cols)].get_path()
		slot.focus_neighbor_right = _slots[_wrap_row(row, col + 1, n, cols)].get_path()
		slot.focus_neighbor_top = _slots[_wrap_col(i - cols, col, n, cols)].get_path()
		slot.focus_neighbor_bottom = _slots[_wrap_col(i + cols, col, n, cols)].get_path()


# Index in `row` for a horizontal step, wrapping within the row's real length.
func _wrap_row(row: int, col: int, n: int, cols: int) -> int:
	var length := mini(cols, n - row * cols)
	return row * cols + posmod(col, length)


# Index for a vertical step; wraps to the last occupied cell of the column.
func _wrap_col(index: int, col: int, n: int, cols: int) -> int:
	if index >= 0 and index < n:
		return index
	var rows := ceili(float(n) / cols)
	var target := col + posmod(floori(float(index) / cols), rows) * cols
	while target >= n:
		target -= cols
	return target


func _on_slot_changed(index: int) -> void:
	var local := index - _first_index
	if local >= 0 and local < _slots.size():
		_refresh_one(local)


func _refresh_bound() -> void:
	for i in _slots.size():
		_refresh_one(i)


func _refresh_one(local: int) -> void:
	var index := _first_index + local
	if index < Inventory.size():
		_slots[local].set_item(Inventory.slot_id(index), Inventory.slot_count(index))
	else:
		_slots[local].clear()

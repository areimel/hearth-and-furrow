extends Node
## Autoload `Inventory`: the player's items as one flat slot array. Pure data, no UI.
## Slots 0..HOTBAR_SIZE-1 are the hotbar; the rest are the backpack. An empty slot has
## id &"" and count 0. The selected hotbar slot decides what the action button does.

signal changed
signal slot_changed(index: int)
signal hotbar_selection_changed(index: int)
signal item_added(id: StringName, amount: int)
signal item_removed(id: StringName, amount: int)
signal capacity_changed(backpack_capacity: int)

const HOTBAR_SIZE: int = Balance.HOTBAR_SLOTS

## Read-only outside this script; change it with select_hotbar()/cycle_hotbar().
var selected_hotbar_index: int = 0
## Backpack slots (excludes hotbar). Grows with expand_backpack().
var backpack_capacity: int = Balance.BACKPACK_SLOTS
var _ids: Array[StringName] = []
var _counts: Array[int] = []


func _ready() -> void:
	SaveManager.register(&"inventory", self)
	reset()


# --- Queries ---

## Total slots, hotbar + backpack.
func size() -> int:
	return _ids.size()


func is_hotbar_slot(index: int) -> bool:
	return index >= 0 and index < HOTBAR_SIZE


func slot_id(index: int) -> StringName:
	return _ids[index] if _valid(index) else &""


func slot_count(index: int) -> int:
	return _counts[index] if _valid(index) else 0


## ItemData in a slot, or null if empty.
func slot_item(index: int) -> ItemData:
	return null if is_slot_empty(index) else Content.item(_ids[index])


func is_slot_empty(index: int) -> bool:
	return slot_id(index).is_empty()


func count(id: StringName) -> int:
	var total := 0
	for i in size():
		if _ids[i] == id:
			total += _counts[i]
	return total


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


## How many more of `id` fit right now.
func space_for(id: StringName) -> int:
	var stack := _stack_size(id)
	if stack == 0:
		return 0
	var room := 0
	for i in size():
		if _ids[i].is_empty():
			room += stack
		elif _ids[i] == id:
			room += stack - _counts[i]
	return room


func can_add(id: StringName, amount: int = 1) -> bool:
	return space_for(id) >= amount


# --- Changes ---

## Adds up to `amount`, topping up existing stacks first, then empty slots (hotbar
## first). Returns the leftover that did not fit (0 = all added).
func add(id: StringName, amount: int = 1) -> int:
	var stack := _stack_size(id)
	if stack == 0 or amount <= 0:
		return maxi(amount, 0)
	var left := amount
	for pass_empty: bool in [false, true]:
		for i in size():
			if left == 0:
				break
			var fits := (_ids[i] == id) if not pass_empty else _ids[i].is_empty()
			if fits:
				var moved := mini(stack - _counts[i], left)
				if moved > 0:
					_set_slot(i, id, _counts[i] + moved)
					left -= moved
	if left < amount:
		item_added.emit(id, amount - left)
		changed.emit()
	return left


## Removes exactly `amount` (backpack first, last slot first). False and no change if
## there are not enough.
func remove(id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or not has(id, amount):
		return amount == 0
	var left := amount
	for i in range(size() - 1, -1, -1):
		if left == 0:
			break
		if _ids[i] == id:
			var taken := mini(_counts[i], left)
			_set_slot(i, id, _counts[i] - taken)
			left -= taken
	item_removed.emit(id, amount)
	changed.emit()
	return true


## Removes up to `amount` from one slot; returns how many were removed.
func remove_at(index: int, amount: int = 1) -> int:
	if is_slot_empty(index) or amount <= 0:
		return 0
	var id := _ids[index]
	var taken := mini(_counts[index], amount)
	_set_slot(index, id, _counts[index] - taken)
	item_removed.emit(id, taken)
	changed.emit()
	return taken


## Moves a slot onto another: merges same items up to the stack size, else swaps.
func move(from: int, to: int) -> void:
	if not _valid(from) or not _valid(to) or from == to or is_slot_empty(from):
		return
	if _ids[to] == _ids[from]:
		var moved := mini(_stack_size(_ids[to]) - _counts[to], _counts[from])
		if moved > 0:
			_set_slot(to, _ids[to], _counts[to] + moved)
			_set_slot(from, _ids[from], _counts[from] - moved)
			changed.emit()
		return
	swap(from, to)


func swap(a: int, b: int) -> void:
	if not _valid(a) or not _valid(b) or a == b:
		return
	var id_a := _ids[a]
	var count_a := _counts[a]
	_set_slot(a, _ids[b], _counts[b])
	_set_slot(b, id_a, count_a)
	changed.emit()


## Moves half a stack (rounded down) to the first empty slot. Returns the new slot
## index, or -1 if the stack has fewer than 2 items or there is no empty slot.
func split(index: int) -> int:
	if slot_count(index) < 2:
		return -1
	var target := _ids.find(&"")
	if target == -1:
		return -1
	var half := floori(_counts[index] / 2.0)
	_set_slot(target, _ids[index], half)
	_set_slot(index, _ids[index], _counts[index] - half)
	changed.emit()
	return target


# --- Hotbar selection ---

func select_hotbar(index: int) -> void:
	index = clampi(index, 0, HOTBAR_SIZE - 1)
	if index != selected_hotbar_index:
		selected_hotbar_index = index
		hotbar_selection_changed.emit(index)


## Moves the selection by `step` (+1 / -1), wrapping around the hotbar.
func cycle_hotbar(step: int) -> void:
	select_hotbar(posmod(selected_hotbar_index + step, HOTBAR_SIZE))


func selected_id() -> StringName:
	return slot_id(selected_hotbar_index)


## ItemData in the selected hotbar slot, or null if it is empty.
func selected_item() -> ItemData:
	return slot_item(selected_hotbar_index)


# --- Capacity ---

## Adds backpack slots up to Balance.BACKPACK_MAX_SLOTS. Returns slots actually added.
func expand_backpack(extra: int) -> int:
	var added := clampi(Balance.BACKPACK_MAX_SLOTS - backpack_capacity, 0, maxi(extra, 0))
	if added == 0:
		return 0
	backpack_capacity += added
	for i in added:
		_ids.append(&"")
		_counts.append(0)
	capacity_changed.emit(backpack_capacity)
	changed.emit()
	return added


## Uses one item with backpack_slots (a linen sack) from a slot. False if the item does
## nothing or the backpack is already at its maximum.
func use_capacity_item(index: int) -> bool:
	var item := slot_item(index)
	if item == null or item.backpack_slots <= 0:
		return false
	if backpack_capacity >= Balance.BACKPACK_MAX_SLOTS:
		return false
	remove_at(index, 1)
	expand_backpack(item.backpack_slots)
	return true


# --- New game and save ---

## Empties everything and gives the new-game loadout (Balance.START_LOADOUT).
func reset() -> void:
	_resize(Balance.BACKPACK_SLOTS)
	for entry: Array in Balance.START_LOADOUT:
		add(entry[0], entry[1])
	selected_hotbar_index = 0
	hotbar_selection_changed.emit(0)


func to_dict() -> Dictionary:
	return {"backpack_capacity": backpack_capacity, "selected": selected_hotbar_index,
		"ids": _ids.duplicate(), "counts": _counts.duplicate()}


func from_dict(data: Dictionary) -> void:
	_resize(int(data.get("backpack_capacity", Balance.BACKPACK_SLOTS)))
	var ids: Array = data.get("ids", [])
	var counts: Array = data.get("counts", [])
	for i in mini(size(), mini(ids.size(), counts.size())):
		var id := StringName(ids[i])
		if not id.is_empty() and Content.has_item(id) and int(counts[i]) > 0:
			_set_slot(i, id, int(counts[i]))
	selected_hotbar_index = clampi(int(data.get("selected", 0)), 0, HOTBAR_SIZE - 1)
	hotbar_selection_changed.emit(selected_hotbar_index)
	changed.emit()


# --- Internals ---

func _resize(backpack: int) -> void:
	backpack_capacity = clampi(backpack, 0, Balance.BACKPACK_MAX_SLOTS)
	_ids.clear()
	_counts.clear()
	_ids.resize(HOTBAR_SIZE + backpack_capacity)
	_counts.resize(HOTBAR_SIZE + backpack_capacity)
	_ids.fill(&"")
	_counts.fill(0)
	capacity_changed.emit(backpack_capacity)
	changed.emit()


func _set_slot(index: int, id: StringName, amount: int) -> void:
	_ids[index] = id if amount > 0 else &""
	_counts[index] = maxi(amount, 0)
	slot_changed.emit(index)


func _stack_size(id: StringName) -> int:
	var item := Content.item(id)
	return item.stack_size if item != null else 0


func _valid(index: int) -> bool:
	return index >= 0 and index < size()

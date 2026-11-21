class_name HudHotbar extends PanelContainer
## The ten hotbar slots (Inventory 0..9) in one row, the selected one framed in gold,
## each with its 1..0 key number. Display only: the slots take no focus or mouse.

var _grid: ItemGrid


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = ItemGrid.new()
	_grid.columns = Balance.HOTBAR_SLOTS
	add_child(_grid)
	_grid.bind_inventory(0, Balance.HOTBAR_SLOTS)
	for i in _grid.slot_count():
		_decorate(_grid.slot_at(i), i)
	Inventory.hotbar_selection_changed.connect(_on_selection_changed)
	_on_selection_changed(Inventory.selected_hotbar_index)


## True when the slot at `index` is drawn as the selected one.
func is_selected(index: int) -> bool:
	return _grid.slot_at(index).selected


func _decorate(slot: ItemSlot, index: int) -> void:
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := Label.new()
	number.text = str((index + 1) % 10)
	number.theme_type_variation = &"CountLabel"
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(number)


func _on_selection_changed(index: int) -> void:
	for i in _grid.slot_count():
		_grid.slot_at(i).selected = i == index

class_name FolkTab extends MenuTab
## The six villagers with friendship hearts and today's talk / gift ticks. Nothing about
## likes or dislikes is shown, so discovery stays in the game.

var _rows: Array[FolkRow] = []
var _list: VBoxContainer
var _scroll: FocusScroll


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	column.add_child(_header())
	_scroll = FocusScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := _scroll
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	column.add_child(scroll)
	for npc in Content.npcs():
		var row := FolkRow.new()
		_list.add_child(row)
		_rows.append(row)
	for i in _rows.size():
		_rows[i].focus_neighbor_top = _rows[posmod(i - 1, _rows.size())].get_path()
		_rows[i].focus_neighbor_bottom = _rows[posmod(i + 1, _rows.size())].get_path()


func tab_title() -> String:
	return "Folk"


func on_shown() -> void:
	var npcs := Content.npcs()
	for i in _rows.size():
		_rows[i].show_npc(npcs[i])


func initial_focus() -> Control:
	return _rows[0] if not _rows.is_empty() else null


## The rows, in Content order (for tests).
func rows() -> Array[FolkRow]:
	return _rows


# Column captions above the tick columns, aligned with the rows below.
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for caption in ["Today:", "Spoke", "Gift"]:
		var label := Label.new()
		label.text = caption
		label.theme_type_variation = &"SmallLabel"
		if caption == "Today:":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.custom_minimum_size.x = FolkRow.TICK_WIDTH
		row.add_child(label)
	return row

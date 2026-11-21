class_name ItemSlot extends Button
## One focusable inventory-style cell: an item icon with a count in the corner.
## Generic building block for inventory, shop and crafting screens; it knows items
## only through Content. Press (or ui_accept) emits `activated`.

## The slot was pressed or accepted.
signal activated(slot: ItemSlot)

## Cell edge in pixels; fits a 16 px icon with a 1 px frame.
const CELL := 18

## Item shown, empty when the slot is empty.
var item_id: StringName = &""
## Stack count shown (hidden when 1 or less, unless a count text is set).
var count: int = 0
## Highlight frame, e.g. the selected hotbar slot or the active recipe.
var selected: bool = false:
	set(value):
		selected = value
		_refresh_style()
## Greyed out (missing ingredient, unaffordable).
var dimmed: bool = false:
	set(value):
		dimmed = value
		modulate = Color(1, 1, 1, 0.45) if dimmed else Color.WHITE

var _icon: TextureRect
var _label: Label
var _text_override: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(CELL, CELL)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 1
	_icon.offset_top = 1
	_icon.offset_right = -1
	_icon.offset_bottom = -1
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", UIPalette.PARCHMENT_LIGHT)
	_label.add_theme_color_override("font_outline_color", UIPalette.WOOD_DARK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	pressed.connect(func() -> void: activated.emit(self))
	_refresh_style()


## Show `id` with `amount` (an empty id clears the slot).
func set_item(id: StringName, amount: int = 1) -> void:
	item_id = id
	count = amount if not id.is_empty() else 0
	_text_override = ""
	var data := Content.item(id) if not id.is_empty() else null
	_icon.texture = data.icon if data else null
	tooltip_text = data.display_name if data else ""
	_refresh_label()


## Empty the slot.
func clear() -> void:
	set_item(&"", 0)


## True when no item is shown.
func is_empty() -> bool:
	return item_id.is_empty()


## Replace the count with custom text (e.g. "3/2"), optionally coloured; cleared by
## the next set_item().
func set_count_text(text: String, color: Color = UIPalette.PARCHMENT_LIGHT) -> void:
	_text_override = text
	_label.add_theme_color_override("font_color", color)
	_refresh_label()


func _refresh_label() -> void:
	if not _text_override.is_empty():
		_label.text = _text_override
	else:
		_label.add_theme_color_override("font_color", UIPalette.PARCHMENT_LIGHT)
		_label.text = str(count) if count > 1 else ""


func _refresh_style() -> void:
	var edge := UIPalette.GOLD if selected else UIPalette.WOOD_DARK
	add_theme_stylebox_override("normal", _box(UIPalette.PARCHMENT_DARK, edge))
	add_theme_stylebox_override("hover", _box(UIPalette.PARCHMENT, edge))
	add_theme_stylebox_override("pressed", _box(UIPalette.PARCHMENT_LIGHT, UIPalette.GOLD))
	add_theme_stylebox_override("disabled", _box(UIPalette.PARCHMENT_DARK, edge))
	add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, UIPalette.GOLD, 2))


func _box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.set_border_width_all(width)
	box.border_color = border
	box.anti_aliasing = false
	return box

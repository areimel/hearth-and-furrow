class_name ShopDetail extends VBoxContainer
## Detail pane of the shop screen: a title, flavour text, a few fact lines, the
## materials a purchase consumes (have/need) and an optional refusal note. Pure
## display; the screen decides what to show. Same look as CraftingDetail.

var _title: Label
var _desc: Label
var _facts: Label
var _needs: ItemRow
var _note: Label


func _init(wrap_width: int = 120) -> void:
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc = _wrapped(UIPalette.WOOD, 8, wrap_width)
	_facts = _wrapped(UIPalette.INK, 9, wrap_width)
	_needs = ItemRow.new("Needs")
	_note = _wrapped(UIPalette.CRIMSON, 9, wrap_width)
	_title.custom_minimum_size.x = wrap_width
	for node: Control in [_title, _desc, _facts, _needs, _note]:
		add_child(node)


## Show one thing: `facts` are plain lines, `needs` ({item: n}) is counted against the
## Inventory, `note` is a reason it cannot be had (empty hides it).
func show_info(title: String, desc: String, facts: Array[String], needs: Dictionary = {},
		note: String = "") -> void:
	_title.text = title
	_desc.text = desc
	_facts.text = "\n".join(facts)
	_needs.show_items(needs, true)
	_needs.visible = not needs.is_empty()
	_note.text = note
	_note.visible = not note.is_empty()


func _wrapped(color: Color, size: int, width: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label

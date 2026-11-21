class_name CraftingDetail extends VBoxContainer
## Right-hand pane of the crafting screen: one recipe's inputs (have/need), outputs,
## duration and chain preview. Pure display; the screen decides what to show.

## Minimum width of wrapping text, so long chain lines wrap instead of widening the pane.
const WRAP_WIDTH := 120

var _title: Label
var _needs: HBoxContainer
var _makes: HBoxContainer
var _time: Label
var _chain: Label
var _note: Label


func _init() -> void:
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	add_child(_title)
	_needs = _row("Needs")
	_makes = _row("Makes")
	_time = Label.new()
	add_child(_time)
	_chain = Label.new()
	_chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chain.custom_minimum_size.x = WRAP_WIDTH
	_chain.add_theme_color_override("font_color", UIPalette.WOOD)
	_chain.add_theme_font_size_override("font_size", 8)
	add_child(_chain)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = WRAP_WIDTH
	_note.add_theme_color_override("font_color", UIPalette.CRIMSON)
	add_child(_note)


## Show `recipe`, with inputs counted against the Inventory; `note` is an optional
## reason it cannot start (locked, busy).
func show_recipe(recipe: RecipeData, note: String = "") -> void:
	_title.text = recipe.display_name
	_fill(_needs, recipe.inputs)
	_fill(_makes, recipe.outputs)
	_time.text = "Time: " + CraftingText.duration(recipe)
	_chain.text = CraftingText.chain_preview(recipe)
	_note.text = note
	_note.visible = not note.is_empty()


func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 30
	row.add_child(label)
	add_child(row)
	return row


func _fill(row: HBoxContainer, items: Dictionary) -> void:
	while row.get_child_count() > 1:
		var old := row.get_child(1)
		row.remove_child(old)
		old.queue_free()
	for id: StringName in items:
		var need: int = int(items[id])
		var slot := ItemSlot.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_item(id, need)
		if row == _needs:
			var have := Inventory.count(id)
			slot.set_count_text("%d/%d" % [have, need],
					UIPalette.CRIMSON if have < need else UIPalette.PARCHMENT_LIGHT)
			slot.dimmed = have < need
		row.add_child(slot)

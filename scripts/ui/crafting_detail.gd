class_name CraftingDetail extends VBoxContainer
## Right-hand pane of the crafting screen: one recipe's inputs (have/need), outputs,
## duration and chain preview. Pure display; the screen decides what to show.

## Minimum width of wrapping text, so long chain lines wrap instead of widening the pane.
const WRAP_WIDTH := 120

var _title: Label
var _needs: ItemRow
var _makes: ItemRow
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
	_needs.show_items(recipe.inputs, true)
	_makes.show_items(recipe.outputs)
	_time.text = "Time: " + CraftingText.duration(recipe)
	_chain.text = CraftingText.chain_preview(recipe)
	_note.text = note
	_note.visible = not note.is_empty()


func _row(caption: String) -> ItemRow:
	var row := ItemRow.new(caption)
	add_child(row)
	return row

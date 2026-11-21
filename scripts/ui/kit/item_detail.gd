class_name ItemDetail extends VBoxContainer
## Detail panel body for one item: icon, name, category, description and sell value.
## Used by the pack and the discoveries list; a shop could reuse it. Spoiler-free: it
## shows nothing about who likes the item.

const CATEGORY_NAMES: Dictionary = {
	G.ItemCategory.TOOL: "Tool", G.ItemCategory.SEED: "Seed", G.ItemCategory.CROP: "Crop",
	G.ItemCategory.ANIMAL_PRODUCT: "Animal product", G.ItemCategory.MATERIAL: "Material",
	G.ItemCategory.FORAGE: "Forage", G.ItemCategory.FISH: "Fish",
	G.ItemCategory.INGREDIENT: "Ingredient", G.ItemCategory.GOOD: "Goods",
	G.ItemCategory.UPGRADE: "Upgrade",
}

var _icon: TextureRect
var _name: Label
var _category: Label
var _description: Label
var _value: IconLabel
var _note: Label


func _init() -> void:
	add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = Label.new()
	_name.theme_type_variation = &"HeaderLabel"
	_name.clip_text = true
	_category = Label.new()
	_category.theme_type_variation = &"SmallLabel"
	titles.add_child(_name)
	titles.add_child(_category)
	head.add_child(titles)
	add_child(head)
	_description = _wrapped()
	add_child(_description)
	_value = IconLabel.new()
	add_child(_value)
	_note = _wrapped()
	_note.theme_type_variation = &"HeaderLabel"
	add_child(_note)


## Show item `id`; an empty id shows a hint instead. `note` adds a highlighted line.
func show_item(id: StringName, note: String = "") -> void:
	var item := Content.item(id) if not id.is_empty() else null
	_icon.texture = item.icon if item else null
	_name.text = item.display_name if item else "Empty slot"
	_category.text = CATEGORY_NAMES.get(item.category, "") if item else ""
	_description.text = item.description if item else ""
	_value.visible = item != null and item.is_sellable()
	if _value.visible:
		_value.set_content(StatusIcons.coin(), "Sells for %d" % Economy.sell_price(id))
	_note.text = note
	_note.visible = note != ""


## The shown item's name, for tests.
func shown_name() -> String:
	return _name.text


func _wrapped() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

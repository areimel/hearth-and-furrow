class_name ListDetail extends HBoxContainer
## The list-beside-detail layout of the crafting, shop, build and journal screens: a
## ListMenu `list_width` pixels wide on the left and a detail control filling the rest.
## The owner connects `menu`'s entry_selected / entry_focused and feeds the detail.

## The list on the left.
var menu: ListMenu


func _init(list_width: int, detail: Control, max_rows: int = 6) -> void:
	add_theme_constant_override("separation", 4)
	menu = ListMenu.new()
	menu.custom_minimum_size.x = list_width
	menu.max_rows = max_rows
	add_child(menu)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detail)

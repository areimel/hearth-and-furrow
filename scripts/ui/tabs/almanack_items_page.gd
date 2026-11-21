class_name AlmanackItemsPage extends HBoxContainer
## The small encyclopedia: every item the player has held at least once (an item in the
## pack, or any harvested / gathered / caught / crafted / bought counter above zero),
## with its one-line description. Undiscovered items are not listed at all.

const OBTAIN_VERBS: Array[StringName] = [&"harvested", &"gathered", &"caught", &"crafted", &"bought"]
const LIST_WIDTH := 112

var _list: ListMenu
var _detail: ItemDetail
var _count: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	_count = Label.new()
	_count.theme_type_variation = &"SmallLabel"
	left.add_child(_count)
	_list = ListMenu.new()
	_list.custom_minimum_size.x = LIST_WIDTH
	_list.max_rows = 6
	_list.entry_focused.connect(func(id: StringName) -> void: _detail.show_item(id))
	left.add_child(_list)
	add_child(left)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail = ItemDetail.new()
	panel.add_child(_detail)
	add_child(panel)


## Rebuild the list from Progress and the pack.
func refresh() -> void:
	var entries: Array[Dictionary] = []
	for id in discovered():
		var item := Content.item(id)
		entries.append({"text": item.display_name, "icon": item.icon, "payload": id})
	_count.text = "Discovered %d of %d" % [entries.size(), Content.items().size()]
	_list.set_entries(entries)
	if entries.is_empty():
		_detail.show_item(&"")
		return
	_detail.show_item(entries[0]["payload"])


## Ids of items obtained at least once, in Content order.
static func discovered() -> Array[StringName]:
	var out: Array[StringName] = []
	for item in Content.items():
		if Inventory.count(item.id) > 0 or OBTAIN_VERBS.any(
				func(verb: StringName) -> bool: return Progress.count(Progress.counter_key(verb, item.id)) > 0):
			out.append(item.id)
	return out


## The control that should take focus, or null when nothing is listed.
func focus_target() -> Control:
	return _list.entry_button(0) if _list.entry_count() > 0 else null

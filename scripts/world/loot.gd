class_name Loot extends RefCounted
## One place where world actions hand items to the player: adds to Inventory, records
## Progress and toasts. Whatever does not fit is lost (for now) with a "Pack is full" toast.


## Give `amount` of `item_id`, record `Progress.record(verb, item_id, added)` and toast.
## `verb` is one of Progress's verbs (&"harvested", &"gathered", &"caught", ...).
## Returns how many items were actually added.
static func give(tree: SceneTree, item_id: StringName, amount: int, verb: StringName) -> int:
	var leftover := Inventory.add(item_id, amount)
	var added := amount - leftover
	var item := Content.item(item_id)
	if added > 0:
		Progress.record(verb, item_id, added)
		Toast.show_message(tree, "+%d %s" % [added, item.display_name], item.icon)
	if leftover > 0:
		Toast.show_message(tree, "Pack is full")
	return added

class_name Loot extends RefCounted
## One place where world actions hand items to the player: adds to Inventory, records
## Progress and toasts, and where costs are checked and paid. Use these instead of calling
## Inventory.add/remove + Progress.record + Toast by hand.

## The one wording for a full pack.
const PACK_FULL := "Your pack is full"


## Give `amount` of `item_id`, record `Progress.record(verb, item_id, added)` and toast.
## `verb` is one of Progress's verbs (&"harvested", &"gathered", &"caught", ...); an empty
## verb (rewards, favours) records nothing.
## Returns how many items were actually added.
static func give(tree: SceneTree, item_id: StringName, amount: int, verb: StringName) -> int:
	var leftover := Inventory.add(item_id, amount)
	var added := amount - leftover
	var item := Content.item(item_id)
	if added > 0:
		if verb != &"":
			Progress.record(verb, item_id, added)
		Toast.show_message(tree, "+%d %s" % [added, item.display_name], item.icon)
	if leftover > 0:
		Toast.show_message(tree, PACK_FULL)
	return added


## True if the pack holds every `{item_id: count}` in `cost`.
static func has_all(cost: Dictionary) -> bool:
	return missing(cost).is_empty()


## What the pack still lacks of `cost` as `{item_id: shortfall}` (empty when it holds it all).
static func missing(cost: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in cost:
		var lacking: int = int(cost[id]) - Inventory.count(id)
		if lacking > 0:
			out[id] = lacking
	return out


## What is still missing from `cost` as text ("Need 2 Stone, 1 Clay"), or "" if nothing.
static func shortfall(cost: Dictionary) -> String:
	var lacking := missing(cost)
	var parts: Array[String] = []
	for id: StringName in lacking:
		parts.append("%d %s" % [lacking[id], Content.item(id).display_name])
	return "" if parts.is_empty() else "Need " + ", ".join(parts)


## Remove every `{item_id: count}` in `cost` from the pack. All or nothing.
static func take(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for id: StringName in cost:
		Inventory.remove(id, int(cost[id]))
	return true


## Give several `{item_id: count}` at once (see give()). Returns what did not fit as
## `{item_id: count}`, so callers that keep leftovers (stations, gatherables) can hold them.
## Unlike give(), nothing is lost here and the full-pack toast shows once.
static func deliver(tree: SceneTree, items: Dictionary, verb: StringName) -> Dictionary:
	var leftover: Dictionary = {}
	for id: StringName in items:
		var rest := Inventory.add(id, int(items[id]))
		var added: int = int(items[id]) - rest
		if added > 0:
			Progress.record(verb, id, added)
			Toast.show_message(tree, "+%d %s" % [added, Content.item(id).display_name], Content.item(id).icon)
		if rest > 0:
			leftover[id] = rest
	if not leftover.is_empty():
		Toast.show_message(tree, PACK_FULL)
	return leftover

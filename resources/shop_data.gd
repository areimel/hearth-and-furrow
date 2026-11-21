class_name ShopData extends Resource
## A shop run by one villager: what it sells (wares) and what it buys (buy rules).
## Built by Content from data/shops.gd; never edit at runtime.

## Unique shop id, e.g. &"chandler".
@export var id: StringName
## Name shown on the shop screen.
@export var display_name: String
## NPC id of the keeper (the "Trade" dialogue option is attached to that villager).
@export var keeper: StringName
## Wares, normalised by the builder. Keys: id (unique within the shop), kind
## (&"item" | &"animal" | &"tool_upgrade" | &"station"), target (item/animal/station id,
## or G.ToolKind for upgrades), price (coins, -1 = derive from the content row),
## stock (units per day, -1 = unlimited), seasons (G.Season values, empty = all),
## sowable (seeds: only while the crop can be sown), unlock (Progress flag), requires
## ({item: n} consumed per purchase), amount (units per purchase), label (shown name).
@export var wares: Array[Dictionary] = []
## What the keeper buys, first matching rule wins. Keys: cats (G.ItemCategory values),
## tags (item tags), ids (item ids), factor (multiplier on the base price).
@export var buy_rules: Array[Dictionary] = []


## The ware with `entry_id`, or an empty Dictionary.
func ware(entry_id: StringName) -> Dictionary:
	for entry: Dictionary in wares:
		if entry["id"] == entry_id:
			return entry
	return {}


## True if the keeper buys anything at all.
func buys_anything() -> bool:
	return not buy_rules.is_empty()


## Price factor the keeper pays for `item` (1.0 = base price); 0.0 if it is not bought.
func buy_factor(item: ItemData) -> float:
	if item == null or not item.is_sellable():
		return 0.0
	for rule: Dictionary in buy_rules:
		var matched: bool = item.id in rule.get("ids", []) or item.category in rule.get("cats", [])
		for tag: StringName in rule.get("tags", []):
			matched = matched or tag in item.tags
		if matched:
			return float(rule.get("factor", 1.0))
	return 0.0

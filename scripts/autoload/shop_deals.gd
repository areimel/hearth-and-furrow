class_name ShopDeals extends RefCounted
## What each kind of shop ware means in game terms: its display, default price,
## whether it can be handed over, and the hand-over itself (animal, tool upgrade,
## station kit, item or paid conversion). Economy decides coins, stock and season;
## this decides everything about the goods. Every delivery is all-or-nothing.


## The Livestock feature root of the running level, or null if there is none.
static func livestock() -> Livestock:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var found := tree.root.find_children("*", "Livestock", true, false)
	return found[0] as Livestock if not found.is_empty() else null


## The upgrade the blacksmith would do for a G.ToolKind, from what the Inventory holds.
## Keys: slot (inventory slot of the tool, -1 if none), from / to (ItemData, may be null),
## coins, items ({id: n} materials), flag (Progress flag), done (already the best tier).
static func upgrade_plan(kind: int) -> Dictionary:
	var plan := {"slot": -1, "from": null, "to": null, "coins": 0, "items": {}, "flag": &"",
		"done": false}
	var tier: ToolTierData = null
	for i in Inventory.size():
		var item := Inventory.slot_item(i)
		if item != null and item.tool_kind == kind:
			plan["slot"] = i
			plan["from"] = item
			tier = Content.tool_tier(item.tool_tier)
			break
	if tier == null:
		for candidate in Content.tool_tiers():
			if not candidate.next_tier.is_empty():
				tier = candidate
				break
	if tier == null or tier.next_tier.is_empty():
		plan["done"] = true
		return plan
	var next := Content.tool_tier(tier.next_tier)
	plan["to"] = Content.tool_item(kind, next.id)
	plan["coins"] = next.upgrade_coins
	plan["items"] = next.upgrade_items
	plan["flag"] = next.unlock_flag
	return plan


## Display facts for a ware: name, icon (Texture2D or null) and desc.
static func describe(entry: Dictionary) -> Dictionary:
	var target: Variant = entry["target"]
	var out := {"name": entry["label"], "icon": null, "desc": ""}
	match entry["kind"]:
		&"animal":
			var animal := Content.animal(target)
			out["name"] = out["name"] if out["name"] != "" else animal.display_name
			out["icon"] = Content.item(animal.product_item).icon
			out["desc"] = "Gives %s; eats %s." % [Content.item(animal.product_item).display_name,
				Content.item(animal.feed_item).display_name.to_lower()]
		&"tool_upgrade":
			var plan := upgrade_plan(target)
			var item: ItemData = plan["to"] if plan["to"] != null else plan["from"]
			out["name"] = out["name"] if out["name"] != "" else item.display_name
			out["icon"] = item.icon
			out["desc"] = item.description
		&"station":
			var station := Content.station(target)
			out["name"] = out["name"] if out["name"] != "" else station.display_name + " kit"
			out["icon"] = Content.item(station.build_cost.keys()[0]).icon
			out["desc"] = "Materials to build: " + station.description
		_:
			var item := Content.item(target)
			out["name"] = out["name"] if out["name"] != "" else item.display_name
			out["icon"] = item.icon
			out["desc"] = item.description
	return out


## Coins charged when the ware row has no price of its own.
static func default_price(entry: Dictionary) -> int:
	var target: Variant = entry["target"]
	match entry["kind"]:
		&"animal":
			return Content.animal(target).price
		&"tool_upgrade":
			return int(upgrade_plan(target)["coins"])
		&"station":
			var total := 0
			for id: StringName in Content.station(target).build_cost:
				total += Content.item(id).base_price * int(Content.station(target).build_cost[id])
			return total
	return Content.item(target).base_price * int(entry["amount"])


## Items a purchase consumes ({id: n}): upgrade materials plus the row's `requires`.
static func needs(entry: Dictionary) -> Dictionary:
	var out: Dictionary = entry["requires"].duplicate()
	if entry["kind"] == &"tool_upgrade":
		out.merge(upgrade_plan(entry["target"])["items"])
	return out


## Item id recorded as bought for Progress/signals (call before delivering an upgrade).
static func bought_id(entry: Dictionary) -> StringName:
	if entry["kind"] == &"tool_upgrade":
		var to: ItemData = upgrade_plan(entry["target"])["to"]
		return to.id if to != null else &""
	return entry["target"]


## Why the goods cannot be handed over right now ("" = they can). Coins, stock and
## season are Economy's business.
static func blocked(entry: Dictionary) -> String:
	if entry["kind"] == &"tool_upgrade":
		var plan := upgrade_plan(entry["target"])
		if plan["done"]:
			return "Already the finest tier"
		if plan["slot"] < 0:
			return "You have no tool to upgrade"
		if not Progress.has_flag(plan["flag"]):
			return "Not yet available"
	var lacking := Loot.shortfall(needs(entry))
	if not lacking.is_empty():
		return lacking
	match entry["kind"]:
		&"animal":
			var herd := livestock()
			if herd == null:
				return "No pen to keep animals in"
			if not herd.can_add(entry["target"]):
				return "No room for another"
		&"item":
			if entry["requires"].is_empty() and not Inventory.can_add(entry["target"], entry["amount"]):
				return "Your pack is full"
	return ""


## Hands over the goods (consuming materials) or returns the reason it could not.
## On failure nothing has changed.
static func deliver(entry: Dictionary) -> String:
	var reason := blocked(entry)
	if not reason.is_empty():
		return reason
	match entry["kind"]:
		&"animal":
			return "" if livestock().add_animal(entry["target"]) != null else "No room for another"
		&"tool_upgrade":
			return _upgrade(upgrade_plan(entry["target"]))
		&"station":
			return _exchange(needs(entry), Content.station(entry["target"]).build_cost)
	return _exchange(needs(entry), {entry["target"]: entry["amount"]})


# Swaps the old tool for the next tier in its own slot, consuming the materials.
static func _upgrade(plan: Dictionary) -> String:
	var slot: int = plan["slot"]
	var to: ItemData = plan["to"]
	Loot.take(plan["items"])
	Inventory.remove_at(slot, 1)
	Inventory.add(to.id, 1)
	for i in Inventory.size():
		if Inventory.slot_id(i) == to.id:
			Inventory.swap(i, slot)
			break
	return ""


# Removes `take`, adds `give`; restores the Inventory and fails if `give` does not fit.
static func _exchange(take: Dictionary, give: Dictionary) -> String:
	var snapshot := Inventory.to_dict()
	Loot.take(take)
	for id: StringName in give:
		if Inventory.add(id, int(give[id])) > 0:
			Inventory.from_dict(snapshot)
			return "Your pack is full"
	return ""

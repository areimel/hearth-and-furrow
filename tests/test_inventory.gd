extends TestCase
## Inventory: stacking, overflow, removal, slot ops, expansion and save round-trip.


func before_each() -> void:
	Inventory.from_dict({})  # empty 24-slot backpack + empty hotbar


func test_new_game_loadout() -> void:
	Inventory.reset()
	eq(Inventory.slot_id(0), &"hoe_wooden", "slot 0")
	eq(Inventory.selected_item().id, &"hoe_wooden", "selected item")
	eq(Inventory.count(&"wheat_seed"), 10, "seeds")
	eq(Inventory.size(), 34, "hotbar + backpack")


func test_stacking_and_tools() -> void:
	eq(Inventory.add(&"wheat_seed", 150), 0, "leftover")
	eq(Inventory.slot_count(0), 99, "first stack full")
	eq(Inventory.slot_count(1), 51, "second stack")
	Inventory.add(&"wheat_seed", 10)
	eq(Inventory.slot_count(1), 61, "tops up existing stack")
	Inventory.add(&"axe_wooden", 2)
	eq(Inventory.slot_count(2), 1, "tools do not stack")
	eq(Inventory.slot_id(3), &"axe_wooden", "second axe in own slot")


func test_overflow_returns_leftover() -> void:
	eq(Inventory.add(&"stone", 99 * 34), 0, "fills every slot")
	check(not Inventory.can_add(&"stone"), "full")
	eq(Inventory.space_for(&"stone"), 0, "no space")
	eq(Inventory.add(&"stone", 5), 5, "all left over")
	eq(Inventory.add(&"clay", 1), 1, "other items do not fit either")


func test_remove_is_atomic() -> void:
	Inventory.add(&"grain", 120)
	check(not Inventory.remove(&"grain", 121), "not enough")
	eq(Inventory.count(&"grain"), 120, "unchanged after failed remove")
	check(Inventory.remove(&"grain", 100), "remove across stacks")
	eq(Inventory.count(&"grain"), 20, "remaining")
	eq(Inventory.remove_at(0, 50), 20, "remove_at caps at slot count")
	check(Inventory.is_slot_empty(0), "slot emptied")


func test_move_swap_split() -> void:
	Inventory.add(&"stone", 10)
	Inventory.add(&"axe_wooden", 1)
	Inventory.swap(0, 1)
	eq(Inventory.slot_id(0), &"axe_wooden", "swapped")
	eq(Inventory.split(1), 2, "split target")
	eq(Inventory.slot_count(1), 5, "half stays")
	eq(Inventory.slot_count(2), 5, "half moves")
	Inventory.move(2, 1)
	eq(Inventory.slot_count(1), 10, "move merges")
	check(Inventory.is_slot_empty(2), "source emptied")
	eq(Inventory.split(0), -1, "cannot split a single tool")


func test_hotbar_selection() -> void:
	Inventory.add(&"sickle_wooden", 1)
	Inventory.select_hotbar(9)
	Inventory.cycle_hotbar(1)
	eq(Inventory.selected_hotbar_index, 0, "wraps forward")
	eq(Inventory.selected_id(), &"sickle_wooden", "selected id")
	Inventory.cycle_hotbar(-1)
	eq(Inventory.selected_hotbar_index, 9, "wraps backward")
	eq(Inventory.selected_item(), null, "empty slot selected")


func test_linen_sack_expands_to_cap() -> void:
	Inventory.add(&"linen_sack", 3)
	check(Inventory.use_capacity_item(0), "first sack")
	eq(Inventory.backpack_capacity, 30, "24 + 6")
	check(Inventory.use_capacity_item(0), "second sack")
	eq(Inventory.backpack_capacity, 36, "cap reached")
	check(not Inventory.use_capacity_item(0), "third sack refused at cap")
	eq(Inventory.count(&"linen_sack"), 1, "refused sack kept")
	eq(Inventory.size(), 46, "slot count grew")
	eq(Inventory.expand_backpack(6), 0, "expand beyond cap adds nothing")


func test_round_trip() -> void:
	Inventory.expand_backpack(6)
	Inventory.add(&"cheese", 7)
	Inventory.add(&"hoe_iron_shod", 1)
	Inventory.select_hotbar(1)
	var saved := Inventory.to_dict()
	Inventory.reset()
	Inventory.from_dict(saved)
	eq(Inventory.backpack_capacity, 30, "capacity")
	eq(Inventory.count(&"cheese"), 7, "cheese")
	eq(Inventory.selected_id(), &"hoe_iron_shod", "selection restored")

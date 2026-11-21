extends TestCase
## Gathering nodes (on bare Gatherable scenes) and the Foraging feature root (on a real
## Level instance).


var _spawned: Array[Node] = []


func before_each() -> void:
	SaveManager.new_game()


func _node(id: StringName) -> Gatherable:
	var node := Gatherable.create(id)
	tree.root.add_child(node)
	_spawned.append(node)
	return node


func _cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _on(season: int, day_of_season: int) -> void:
	GameClock.day_index = Calendar.day_index_for(1, season, day_of_season)


func _interactable(node: Gatherable) -> Interactable:
	return node.get_node("Interactable") as Interactable


func test_yield_rolls_stay_within_bounds_and_season() -> void:
	var hazel := _node(&"hazel")
	_on(G.Season.SPRING, 5)
	for i in 30:
		var roll := hazel.roll_yields()
		check(not roll.has(&"hazelnut"), "no hazelnuts in spring")
		check(int(roll.get(&"hazel_rod", 0)) in [2, 3], "rods 2-3, got %s" % roll)
	_on(G.Season.AUTUMN, 5)
	var seen_nut := false
	for i in 30:
		var roll := hazel.roll_yields()
		seen_nut = seen_nut or roll.has(&"hazelnut")
		check(int(roll.get(&"hazelnut", 1)) in [1, 2, 3], "nuts 1-3")
	check(seen_nut, "hazelnuts in autumn")
	_cleanup()


func test_bramble_is_only_ripe_late_summer_and_autumn() -> void:
	var bramble := _node(&"bramble")
	for when: Array in [[G.Season.SPRING, 10], [G.Season.SUMMER, 3], [G.Season.WINTER, 10]]:
		_on(when[0], when[1])
		check(not bramble.is_ripe(), "unripe %s" % [when])
		eq(bramble.prompt_text(), "Nothing ripe yet", "prompt %s" % [when])
		check(not bramble.gather(), "nothing gathered %s" % [when])
		check(not bramble.depleted, "stays undepleted")
	_on(G.Season.SUMMER, 20)
	check(bramble.is_ripe(), "ripe late summer")
	eq(bramble.prompt_text(), "Pick berries", "verb comes from the row")
	_on(G.Season.AUTUMN, 2)
	check(bramble.gather(), "gathered in autumn")
	var berries := Inventory.count(&"blackberry")
	check(berries >= 2 and berries <= 4, "2-4 berries, got %d" % berries)
	eq(Progress.count(&"gathered.blackberry"), berries, "progress recorded")
	_cleanup()


func test_depletes_and_regrows_through_day_ending() -> void:
	_on(G.Season.SPRING, 5)
	var stone := _node(&"stone")
	var row := Content.gatherable(&"stone")
	check(_interactable(stone).enabled, "enabled while ready")
	eq(_interactable(stone).prompt_text, "Gather stone", "prompt published")
	check(stone.gather(), "gathered")
	check(stone.depleted, "depleted")
	check(not _interactable(stone).enabled, "interactable disabled")
	eq(Progress.count(&"gathered.stone"), Inventory.count(&"stone"), "recorded")
	check(not stone.gather(), "cannot gather depleted")
	for i in row.regrow_days - 1:
		GameClock.advance_day()
		check(stone.depleted, "still depleted after %d days" % (i + 1))
	GameClock.advance_day()
	check(not stone.depleted, "regrown after %d days" % row.regrow_days)
	check(_interactable(stone).enabled, "enabled again")
	_cleanup()


func test_full_pack_keeps_node_gatherable() -> void:
	var clay := _node(&"clay")
	Inventory.add(&"log", 99 * Inventory.size())
	check(not Inventory.can_add(&"clay", 1), "pack is full")
	check(not clay.gather(), "nothing fits")
	check(not clay.depleted, "still gatherable")
	check(not clay.pending.is_empty(), "yield waits on the node")
	var rolled := clay.pending.duplicate()
	check(not clay.gather(), "still full")
	eq(clay.pending, rolled, "pending roll is not re-rolled")
	Inventory.remove(&"log", Inventory.count(&"log"))
	check(clay.gather(), "delivered once there is room")
	check(clay.depleted and clay.pending.is_empty(), "depleted after delivery")
	eq(Inventory.count(&"clay"), int(rolled[&"clay"]), "the waiting roll arrived")
	_cleanup()


func test_save_round_trip_keeps_depletion_timer_and_pending() -> void:
	var node := _node(&"reeds")
	node.depleted = true
	node.regrow_left = 3
	node.pending = {&"reed": 2}
	var saved := JSON.to_native(JSON.from_native(node.to_dict())) as Dictionary
	var copy := _node(&"reeds")
	copy.from_dict(saved)
	check(copy.depleted, "depleted")
	eq(copy.regrow_left, 3, "timer")
	eq(copy.pending, {&"reed": 2}, "pending")
	_cleanup()


# ---------------------------------------------------------------- feature root

func _signature(forage: Foraging) -> Array:
	var out: Array = forage.nodes().map(func(n: Gatherable) -> String: return "%s%s" % [n.gatherable_id, n.coord])
	out.sort()
	return out


func test_scatter_obeys_placement_rules_and_is_deterministic() -> void:
	var level := await spawn_level(5)
	var forage: Foraging = level.get_node("Foraging")
	var grid: FarmGrid = level.farm_grid
	check(SaveManager.is_registered(&"foraging"), "registered")
	var expected := 0
	for row in Content.gatherables():
		expected += row.scatter_count
		check(forage.nodes().filter(func(n: Gatherable) -> bool: return n.gatherable_id == row.id).size() > 0,
				"%s scattered" % row.id)
	eq(forage.nodes().size(), expected, "every row placed its count")
	eq(level.gatherables().get_child_count(), expected, "spawned into level.gatherables()")
	var reachable := GridSearch.flood(grid.cell_of(level.player.position), grid.is_walkable_land)
	check(reachable.size() > 100, "the farm has a walkable land mass")
	var cells: Dictionary = {}
	for node in forage.nodes():
		var cell := node.coord
		check(not cells.has(cell), "no two nodes share %s" % cell)
		cells[cell] = true
		check(not grid.is_water(cell), "%s on dry land" % node.gatherable_id)
		check(not grid._in_house(cell), "not inside the house")
		check(grid.occupant(cell) == node, "%s registered occupancy" % node.gatherable_id)
		check(not grid.is_tilled(cell), "not on tilled soil")
		check(reachable.has(cell), "%s at %s is reachable on foot" % [node.gatherable_id, cell])
		if Content.gatherable(node.gatherable_id).placement == GatherableData.PLACE_NEAR_WATER:
			var wet := false
			for r in range(1, Foraging.WATER_REACH + 1):
				wet = wet or GridSearch.ring(cell, r).any(grid.is_water)
			check(wet, "%s sits near water" % node.gatherable_id)
		for other in forage.nodes():
			if other != node:
				var gap := maxi(absi(other.coord.x - cell.x), absi(other.coord.y - cell.y))
				check(gap >= Foraging.MIN_SPACING, "spacing %d" % gap)
	Weather.world_seed = 4242
	forage.reset()
	var first := _signature(forage)
	forage.reset()
	eq(_signature(forage), first, "same seed, same world")
	Weather.world_seed = 4243
	forage.reset()
	check(_signature(forage) != first, "different seed, different world")
	await despawn_level()
	check(not SaveManager.is_registered(&"foraging"), "unregistered on exit")


func test_save_round_trip_and_forage_area_markers() -> void:
	var level := await spawn_level(5)
	var forage: Foraging = level.get_node("Foraging")
	var first := forage.nodes()[0]
	first.depleted = true
	first.regrow_left = 2
	var first_id := first.gatherable_id
	var first_cell := first.coord
	var first_pos := first.global_position
	var before := _signature(forage)
	var saved := JSON.to_native(JSON.from_native(forage.to_dict())) as Dictionary
	forage.reset()
	forage.from_dict(saved)
	eq(_signature(forage), before, "round trip restores every node")
	var restored := forage.node_at(first_cell)
	check(restored != null and restored.depleted and restored.regrow_left == 2, "depletion survives")
	eq(forage.count_ready(first_id), forage.nodes().filter(
			func(n: Gatherable) -> bool: return n.gatherable_id == first_id and n.is_ripe()).size(),
			"count_ready matches")

	var marker := Marker2D.new()
	marker.set_meta(&"gatherable_id", &"stone")
	marker.set_meta(&"count", 2)
	marker.set_meta(&"radius", 200.0)
	level.add_child(marker)
	marker.global_position = first_pos
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count_before := forage.nodes().size()
	var placed := forage.scatter_area(marker, rng)
	check(placed >= 1 and placed <= 2, "marker scattered 1-2 stones, got %d" % placed)
	eq(forage.nodes().size(), count_before + placed, "only the marker's nodes were added")
	for node in forage.nodes().slice(count_before):
		eq(node.gatherable_id, &"stone", "marker id")
		check(node.global_position.distance_to(marker.global_position) <= 216.0, "inside the radius")
	await despawn_level()

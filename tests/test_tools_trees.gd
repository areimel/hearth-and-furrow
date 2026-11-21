extends TestCase
## Axe tiers and renewable trees: hits to fell, logs, stump regrow, apple seasons, saving.

var level: Level
var _spawned: Array[AppleTree] = []


func before_each() -> void:
	SaveManager.new_game()
	_spawned.clear()


func _tree() -> AppleTree:
	var made: AppleTree = load("res://scenes/objects/tree.tscn").instantiate()
	tree.root.add_child.call_deferred(made)
	await tree.process_frame
	_spawned.append(made)
	return made


func _cleanup() -> void:
	for made in _spawned:
		made.free()


func _chop(target: AppleTree, tier_id: StringName) -> int:
	var tier := Content.tool_tier(tier_id)
	var hits := 0
	while not target.felled and hits < 20:
		target.hit(G.ToolKind.AXE, Vector2.RIGHT, tier)
		hits += 1
	return hits


func test_hits_to_fell_depend_on_tier() -> void:
	var wooden := AppleTree.hits_to_fell(Content.tool_tier(&"wooden"))
	var iron := AppleTree.hits_to_fell(Content.tool_tier(&"iron_shod"))
	eq(wooden, Balance.APPLE_TREE_HEALTH, "wooden takes full health")
	check(iron < wooden, "iron fells faster")
	var a := await _tree()
	var b := await _tree()
	eq(_chop(a, &"wooden"), wooden, "wooden hits in practice")
	eq(_chop(b, &"iron_shod"), iron, "iron hits in practice")
	_cleanup()


func test_felling_gives_logs_plus_tier_bonus() -> void:
	var a := await _tree()
	_chop(a, &"wooden")
	eq(Inventory.count(&"log"), Balance.TREE_LOGS, "wooden logs")
	var b := await _tree()
	_chop(b, &"iron_shod")
	eq(Inventory.count(&"log"), Balance.TREE_LOGS * 2 + Content.tool_tier(&"iron_shod").bonus_logs, "iron logs")
	eq(Progress.count("gathered.log"), Inventory.count(&"log"), "recorded as gathered")
	_cleanup()


func test_stump_regrows_after_the_set_days() -> void:
	var a := await _tree()
	_chop(a, &"wooden")
	check(not a.is_in_group("Axe_able"), "a stump cannot be chopped")
	for i in Balance.TREE_REGROW_DAYS - 1:
		GameClock.day_ending.emit(i)
	check(a.felled, "still a stump the evening before")
	GameClock.day_ending.emit(0)
	check(not a.felled, "regrown")
	check(a.is_in_group("Axe_able"), "choppable again")
	near(a.health, Balance.APPLE_TREE_HEALTH, 0.001, "full health")
	_cleanup()


func test_apples_are_picked_by_hand_without_hurting_the_tree() -> void:
	var a := await _tree()
	a._show_apples(3)
	var pad: Interactable = a.get_node("Interactable")
	check(pad.enabled, "pick prompt enabled with fruit")
	eq(pad.prompt_text, "Pick apples", "prompt")
	var health := a.health
	eq(a.pick_apples(), 3, "all picked")
	eq(Inventory.count(&"apple"), 3, "in the pack")
	eq(Progress.count(&"gathered.apple"), 3, "recorded")
	eq(a.health, health, "tree unhurt")
	check(not pad.enabled, "disabled when bare")
	a._show_apples(2)
	a.hit(G.ToolKind.AXE, Vector2.RIGHT, null)
	eq(a.apple_count(), 2, "the axe no longer knocks apples down")
	_cleanup()


func test_apples_regrow_only_in_summer_and_autumn() -> void:
	var a := await _tree()
	GameClock.day_index = Calendar.day_index_for(1, G.Season.WINTER, 5)
	a._show_apples(0)
	for i in 40:
		GameClock.day_ending.emit(i)
	eq(a.apple_count(), 0, "no apples in winter")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.SUMMER, 5)
	for i in 40:
		GameClock.day_ending.emit(i)
	check(a.apple_count() > 0, "apples return in summer")
	_cleanup()


func test_grove_saves_and_restores_every_tree() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	check(SaveManager.is_registered(&"trees"), "one provider registered")
	var grove: TreeGrove = level.get_node("Objects/Trees")
	var first := grove.trees()[0]
	var second := grove.trees()[1]
	_chop(first, &"iron_shod")
	second.health = 2.0
	var saved := grove.to_dict()
	grove.reset()
	check(not first.felled and is_equal_approx(second.health, Balance.APPLE_TREE_HEALTH), "reset restores all")
	grove.from_dict(saved)
	check(first.felled, "felled tree restored as a stump")
	near(second.health, 2.0, 0.001, "damage restored")
	check(not grove.trees()[2].felled, "untouched tree intact")
	level.free()
	await tree.process_frame

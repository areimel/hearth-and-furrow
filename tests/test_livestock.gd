extends TestCase
## Animal care/product rules (on bare animal scenes) and the Livestock feature root
## (on a real Level instance).

const ANIMAL_SCENE := preload("res://scenes/actors/animal.tscn")

var _spawned: Array[Node] = []


func before_each() -> void:
	SaveManager.new_game()


func _animal(id: StringName) -> Animal:
	var animal: Animal = ANIMAL_SCENE.instantiate()
	animal.animal_id = id
	tree.root.add_child(animal)
	_spawned.append(animal)
	return animal


func _cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


## Spring day index: animals graze, so every day counts as fed.
func _spring() -> int:
	return Calendar.day_index_for(1, G.Season.SPRING, 5)


func _winter() -> int:
	return Calendar.day_index_for(1, G.Season.WINTER, 5)


func test_product_cycle_per_species() -> void:
	for id: StringName in Content.animals().map(func(a: AnimalData) -> StringName: return a.id):
		var animal := _animal(id)
		var row := Content.animal(id)
		for i in row.product_days - 1:
			animal.end_day(_spring())
			check(not animal.product_ready, "%s not ready after %d days" % [id, i + 1])
		animal.end_day(_spring())
		check(animal.product_ready, "%s ready after %d days" % [id, row.product_days])
		eq(animal.prompt_text() != "", true, "%s has a prompt" % id)
		var before := Inventory.count(row.product_item)
		check(animal.collect(), "%s collect" % id)
		eq(Inventory.count(row.product_item), before + row.product_amount, "%s product added" % id)
		eq(Progress.count(&"gathered." + row.product_item), row.product_amount, "%s recorded" % id)
		check(not animal.product_ready, "%s cleared" % id)
	_cleanup()


func test_prompt_verbs() -> void:
	var cow := _animal(&"cow")
	var hen := _animal(&"chicken")
	eq(cow.prompt_text(), "Pet", "idle prompt")
	cow.end_day(_spring())
	hen.end_day(_spring())
	eq(cow.prompt_text(), "Milk", "milk verb")
	eq(hen.prompt_text(), "Collect egg", "egg verb")
	Inventory.add(&"grain", 1)
	for i in Inventory.size():
		if Inventory.slot_id(i) == &"grain" and Inventory.is_hotbar_slot(i):
			Inventory.select_hotbar(i)
	if Inventory.selected_id() == &"grain":
		eq(hen.prompt_text(), "Feed", "holding feed beats collecting")
	_cleanup()


func test_interactable_prompt_follows_the_animal() -> void:
	var cow := _animal(&"cow")
	var pad: Interactable = cow.get_node("Interactable")
	eq(pad.prompt_text, "Pet", "idle prompt published")
	cow.end_day(_spring())
	eq(pad.prompt_text, "Milk", "prompt updates to Milk, not a stale Pet")
	cow.pet()
	cow.collect()
	check(not pad.enabled, "nothing to do disables the interactable")
	_cleanup()


func test_feed_consumes_item_and_sets_fed() -> void:
	var cow := _animal(&"cow")
	check(not cow.feed(), "nothing to feed with")
	Inventory.add(&"straw", 3)
	var mood := cow.mood
	check(cow.feed(), "fed")
	eq(Inventory.count(&"straw"), 2, "one straw consumed")
	check(cow.fed_today, "fed_today")
	check(cow.mood > mood, "mood up")
	check(not cow.feed(), "only once a day")
	eq(Inventory.count(&"straw"), 2, "no second straw consumed")
	_cleanup()


func test_pet_once_per_day() -> void:
	var sheep := _animal(&"sheep")
	var mood := sheep.mood
	check(sheep.pet(), "petted")
	check(sheep.mood > mood, "mood up")
	check(not sheep.pet(), "second pet refused")
	sheep.end_day(_spring())
	check(sheep.pet(), "can pet again next day")
	_cleanup()


func test_winter_needs_feed_but_spring_grazes() -> void:
	var cow := _animal(&"cow")
	cow.end_day(_winter())
	check(not cow.product_ready, "unfed in winter: no milk")
	check(cow.mood < Animal.MOOD_START, "unfed in winter: mood drops")
	Inventory.add(&"straw", 1)
	cow.feed()
	cow.end_day(_winter())
	check(cow.product_ready, "fed in winter: milk")
	var grazer := _animal(&"cow")
	grazer.end_day(_spring())
	check(grazer.product_ready, "spring: grazes, milk")
	_cleanup()


func test_neglect_slows_but_never_stops_and_never_dies() -> void:
	var cow := _animal(&"cow")
	cow.mood = 0
	cow.end_day(_winter())
	eq(cow.mood, 0, "mood clamps at 0")
	for i in 40:
		cow.end_day(_winter())
	check(is_instance_valid(cow) and not cow.is_queued_for_deletion(), "still alive")
	check(not cow.product_ready, "no feed in winter: nothing yet")
	cow.mood = 0
	eq(cow.days_needed(), Content.animal(&"cow").product_days + 1, "low mood costs a day")
	cow.end_day(_spring())
	check(not cow.product_ready, "low mood: one day slower")
	cow.end_day(_spring())
	check(cow.product_ready, "neglected animal still produces eventually")
	cow.add_mood(500)
	eq(cow.mood, 100, "mood clamps at 100")
	_cleanup()


func test_collect_fails_when_pack_full() -> void:
	var cow := _animal(&"cow")
	cow.end_day(_spring())
	var milk := Content.item(&"milk")
	while Inventory.can_add(&"milk", 1):
		Inventory.add(&"milk", milk.stack_size)
	check(not cow.collect(), "pack full")
	check(cow.product_ready, "product kept")
	_cleanup()


func test_animal_save_round_trip() -> void:
	var a := _animal(&"sheep")
	a.mood = 77
	a.progress_days = 2
	a.product_ready = true
	a.petted_today = true
	var b := _animal(&"sheep")
	b.from_dict(JSON.to_native(JSON.from_native(a.to_dict())))
	eq(b.mood, 77, "mood")
	eq(b.progress_days, 2, "progress")
	check(b.product_ready and b.petted_today, "flags")
	b.from_dict({})
	eq(b.mood, Animal.MOOD_START, "defaults on empty dict")
	_cleanup()


func _spawn_level() -> Array:
	var level: Level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	var live: Livestock = level.get_node("Livestock")
	await tree.process_frame
	await tree.process_frame
	return [level, live]


func test_starter_herd_cap_and_save() -> void:
	var pair := await _spawn_level()
	var level: Level = pair[0]
	var live: Livestock = pair[1]
	eq(live.count(&"cow"), 1, "cow")
	eq(live.count(&"sheep"), 1, "sheep")
	eq(live.count(&"chicken"), 2, "chickens")
	eq(level.animals().get_child_count(), 4, "spawned into level.animals()")
	check(SaveManager.is_registered(&"livestock"), "registered")
	var grid: FarmGrid = level.farm_grid
	for animal in live.animals():
		check(grid.is_free_for_placement(grid.cell_of(animal.position)), "on free ground")
	while live.can_add(&"chicken"):
		check(live.add_animal(&"chicken") != null, "added")
	eq(live.count(&"chicken"), live.max_per_species, "cap reached")
	check(live.add_animal(&"chicken") == null, "over cap refused")
	check(live.can_add(&"cow"), "other species unaffected")

	live.animals()[0].mood = 11
	var saved := JSON.to_native(JSON.from_native(live.to_dict())) as Dictionary
	var total := live.animals().size()
	live.reset()
	eq(live.animals().size(), 4, "reset gives starter herd")
	live.from_dict(saved)
	eq(live.animals().size(), total, "round trip count")
	eq(live.animals()[0].mood, 11, "round trip mood")
	level.free()
	await tree.process_frame
	check(not SaveManager.is_registered(&"livestock"), "unregistered on exit")

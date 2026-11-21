extends TestCase
## Villager schedules, NPC placement on place markers, and Villagers spawning/options.

const MON := G.Weekday.MONDAY
const SAT := G.Weekday.SATURDAY
const SUN := G.Weekday.SUNDAY
const SPRING := G.Season.SPRING

var world: Node2D


func before_each() -> void:
	SaveManager.new_game()
	Weather.set_today(G.WeatherKind.CLEAR)


func _make_world(places: Dictionary) -> void:
	world = Node2D.new()
	for id: StringName in places:
		var marker := Marker2D.new()
		marker.name = String(id)
		marker.position = places[id]
		marker.add_to_group(&"Place")
		world.add_child(marker)
	tree.root.add_child.call_deferred(world)
	await tree.process_frame


func _drop_world() -> void:
	world.free()
	await tree.process_frame


func _entry(hour: int, place: StringName, seasons: Array[int] = []) -> NPCScheduleEntry:
	var entry := NPCScheduleEntry.new()
	entry.start_hour = hour
	entry.location = place
	entry.seasons.assign(seasons)
	return entry


func test_weekday_saturday_sunday_and_rain_resolution() -> void:
	var miller := Content.npc(&"miller")
	eq(miller.location_at(9, MON, SPRING, false), &"mill", "monday morning")
	eq(miller.location_at(12, MON, SPRING, false), &"village_green", "monday noon")
	eq(miller.location_at(19, MON, SPRING, false), &"alehouse", "monday evening")
	eq(miller.location_at(9, SAT, SPRING, false), &"market_cross", "market day")
	eq(miller.location_at(11, SUN, SPRING, false), &"village_green", "sunday rest")
	eq(miller.location_at(12, MON, SPRING, true), &"mill", "rain keeps him at work")
	eq(miller.location_at(9, SAT, SPRING, true), &"mill", "rain cancels the market trip")


func test_every_villager_has_full_schedule_variants() -> void:
	for villager in Content.npcs():
		var seen: Array[StringName] = []
		for hour in range(6, 24):
			var place := villager.location_at(hour, MON, SPRING, false)
			check(place != &"", "%s has a place at %d" % [villager.id, hour])
			if not place in seen:
				seen.append(place)
		check(seen.size() >= 3, "%s weekday beats: %s" % [villager.id, seen])
		var market: Array[StringName] = []
		for hour in range(6, 24):
			market.append(villager.location_at(hour, SAT, SPRING, false))
		check(&"market_cross" in market, "%s attends market" % villager.id)
		var sunday: Array[StringName] = []
		for hour in range(6, 24):
			sunday.append(villager.location_at(hour, SUN, SPRING, false))
		check(&"village_green" in sunday, "%s rests on the green" % villager.id)
		var wet := villager.location_at(14, MON, SPRING, true)
		check(wet != &"" and wet != &"village_green" and wet != &"market_cross",
				"%s stays indoors in rain" % villager.id)


func test_season_filtered_entries() -> void:
	var data := NPCData.new()
	data.schedule = [_entry(6, &"mill"), _entry(6, &"alehouse", [G.Season.WINTER] as Array[int])]
	eq(data.location_at(8, MON, G.Season.SUMMER, false), &"mill", "summer")
	eq(data.location_at(8, MON, G.Season.WINTER, false), &"alehouse", "winter override")


func test_npc_snaps_to_scheduled_place() -> void:
	await _make_world({&"mill": Vector2(10, 10), &"village_green": Vector2(200, 40),
			&"alehouse": Vector2(300, 80)})
	GameClock.day_index = 0
	GameClock.hour = 12
	var npc: NPC = load("res://scenes/actors/npc.tscn").instantiate()
	npc.npc_id = &"miller"
	world.add_child(npc)
	eq(npc.global_position, Vector2(200, 40), "monday noon on the green")
	eq(npc.place_id, &"village_green", "place id")
	GameClock.hour = 13
	GameClock.hour_passed.emit(13)
	eq(npc.place_id, &"mill", "heads back to the mill")
	check(npc.global_position.distance_to(Vector2(200, 40)) < 0.01, "still walking at start")
	for i in 20:
		await tree.physics_frame
	check(npc.global_position.distance_to(Vector2(200, 40)) > 1.0, "has set off")
	npc.snap_to_schedule()
	eq(npc.global_position, Vector2(10, 10), "load-game teleport")
	await _drop_world()


func test_npc_without_markers_stays_put() -> void:
	await _make_world({})
	var npc: NPC = load("res://scenes/actors/npc.tscn").instantiate()
	npc.npc_id = &"reeve"
	npc.position = Vector2(5, 6)
	world.add_child(npc)
	GameClock.hour_passed.emit(9)
	eq(npc.position, Vector2(5, 6), "unmoved")
	await _drop_world()


func test_option_registration_before_spawn() -> void:
	await _make_world({})
	var villagers: Villagers = load("res://scenes/world/villagers.tscn").instantiate()
	var hits: Array[int] = []
	villagers.register_option(&"miller", "Trade", func() -> void: hits.append(1))
	villagers.register_option(&"miller", "Secret", func() -> void: hits.append(2),
			func() -> bool: return false)
	world.add_child(villagers)
	eq(villagers.all().size(), Content.npcs().size(), "all spawned")
	var miller := villagers.npc(&"miller")
	check(miller != null, "miller exists")
	var options := miller.dialogue_options()
	eq(options.size(), 1, "condition hides one option")
	eq(options[0]["text"], "Trade", "visible option")
	(options[0]["payload"] as Callable).call()
	eq(hits, [1] as Array[int], "callback wired")
	villagers.register_option(&"reeve", "Errand", func() -> void: pass)
	eq(villagers.npc(&"reeve").dialogue_options().size(), 1, "after spawn")
	await _drop_world()


func test_line_override_replaces_the_greeting() -> void:
	await _make_world({})
	var villagers: Villagers = load("res://scenes/world/villagers.tscn").instantiate()
	world.add_child(villagers)
	eq(villagers.line_override(&"miller").size(), 0, "no provider, no lines")
	villagers.set_line_override(func(id: StringName) -> Array[String]:
		var lines: Array[String] = []
		if id == &"miller":
			lines.append("Merry feast, %s" % id)
		return lines)
	eq(villagers.line_override(&"miller"), ["Merry feast, miller"] as Array[String], "override lines")
	eq(villagers.line_override(&"reeve").size(), 0, "empty falls through")
	villagers.set_line_override(Callable())
	eq(villagers.line_override(&"miller").size(), 0, "cleared")
	await _drop_world()


func test_gather_and_release() -> void:
	await _make_world({&"village_green": Vector2(100, 100)})
	var spot := Marker2D.new()
	spot.name = "Feast1"
	spot.position = Vector2(8, 0)
	world.get_node("village_green").add_child(spot)
	var villagers: Villagers = load("res://scenes/world/villagers.tscn").instantiate()
	world.add_child(villagers)
	villagers.gather_at(&"village_green", "Feast")
	for villager in villagers.all():
		check(villager.held, "%s held" % villager.npc_id)
	villagers.release()
	for villager in villagers.all():
		check(not villager.held, "%s released" % villager.npc_id)
	await _drop_world()


func test_interaction_talks_then_gifts_through_the_box() -> void:
	await _make_world({&"mill": Vector2(10, 10)})
	var box: DialogueBox = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	world.add_child(box)
	var npc: NPC = load("res://scenes/actors/npc.tscn").instantiate()
	npc.npc_id = &"miller"
	world.add_child(npc)
	npc.add_dialogue_option("Trade", func() -> void: pass)
	Inventory.select_hotbar(0)
	eq((npc.get_node("Interactable") as Interactable).prompt_text, "Talk", "prompt is always Talk")
	var talked: Array[StringName] = []
	npc.talked.connect(func(id: StringName) -> void: talked.append(id))
	npc._on_interacted(null)
	check(box.is_open, "box opens on talk")
	eq(talked, [&"miller"] as Array[StringName], "talked signal")
	eq(Relationships.points(&"miller"), 20, "first talk of the day scores")
	box.close()
	npc._on_interacted(null)
	eq(Relationships.points(&"miller"), 20, "second talk does not")
	box.close()
	Inventory.add(&"bread", 1)
	for i in Inventory.size():
		if Inventory.slot_id(i) == &"bread":
			Inventory.move(i, 5)
	Inventory.select_hotbar(5)
	npc._on_interacted(null)
	check(box.is_open, "talk still opens with a giftable selected")
	eq(Relationships.points(&"miller"), 20, "holding bread does not give it")
	var texts: Array[String] = []
	for option in npc._talk._choices():
		texts.append(option["text"])
	eq(texts, ["Give Loaf", "Trade"] as Array[String], "give is a choice next to Trade")
	(npc._talk._choices()[0]["payload"] as Callable).call()
	eq(Relationships.points(&"miller"), 100, "loved bread")
	check(npc.get_node("Emote").visible, "emote shown")
	check(Inventory.count(&"bread") == 0, "the loaf was given")
	box.close()
	npc._on_interacted(null)
	texts.clear()
	for option in npc._talk._choices():
		texts.append(option["text"])
	eq(texts, ["Trade"] as Array[String], "no give after today's gift")
	box.close()
	await _drop_world()

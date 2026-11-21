extends TestCase
## Relationships and Progress behaviour (QuestManager: tests/test_quests.gd).


func before_each() -> void:
	SaveManager.new_game()


func test_talk_and_gift() -> void:
	check(Relationships.talk(&"miller"), "first talk")
	check(not Relationships.talk(&"miller"), "second talk ignored")
	eq(Relationships.points(&"miller"), 20, "talk points")
	eq(Relationships.gift(&"miller", &"bread"), G.GiftReaction.NOT_GIFTABLE, "no bread held")
	Inventory.add(&"bread", 2)
	eq(Relationships.gift(&"miller", &"bread"), G.GiftReaction.LOVED, "loves bread")
	eq(Inventory.count(&"bread"), 1, "gift consumed")
	eq(Relationships.gift(&"miller", &"bread"), G.GiftReaction.ALREADY_GIFTED, "once a day")
	eq(Relationships.hearts(&"miller"), 1, "100 points = 1 heart")
	eq(Relationships.gift(&"reeve", &"hoe_wooden"), G.GiftReaction.NOT_GIFTABLE, "tools")


func test_hearts_cap() -> void:
	Relationships.add_points(&"shepherd", 5000)
	eq(Relationships.hearts(&"shepherd"), 10, "capped at 10")
	Relationships.add_points(&"shepherd", -9999)
	eq(Relationships.points(&"shepherd"), 0, "floored at 0")


func test_progress_flags_and_counters() -> void:
	check(Progress.has_flag(&""), "empty flag counts as set")
	check(not Progress.has_flag(&"x"), "unset")
	Progress.set_flag(&"x")
	check(Progress.has_flag(&"x"), "set")
	eq(Progress.record(&"harvested", &"flax", 3), 3, "record")
	eq(Progress.count(&"harvested.flax"), 3, "counter key")


func test_talk_once_per_day_and_resets() -> void:
	check(Relationships.talk(&"reeve"), "first talk")
	check(not Relationships.talk(&"reeve"), "second talk")
	eq(Relationships.points(&"reeve"), 20, "points once")
	check(Relationships.talked_today(&"reeve"), "flag")
	Relationships.begin_day(1)
	check(not Relationships.talked_today(&"reeve"), "flag cleared")
	check(Relationships.talk(&"reeve"), "talk again next day")
	eq(Relationships.points(&"reeve"), 40, "points twice over two days")
	check(Relationships.has_met(&"reeve"), "met")


func test_gift_reactions_and_points() -> void:
	Inventory.add(&"cheese", 5)
	Inventory.add(&"bread", 5)
	Inventory.add(&"ale", 5)
	Inventory.add(&"stone", 5)
	eq(Relationships.gift(&"shepherd", &"cheese"), G.GiftReaction.LOVED, "loved")
	eq(Relationships.points(&"shepherd"), 80, "loved points")
	Relationships.begin_day(1)
	eq(Relationships.gift(&"shepherd", &"ale"), G.GiftReaction.DISLIKED, "disliked")
	eq(Relationships.points(&"shepherd"), 60, "dislike removes points")
	Relationships.begin_day(2)
	eq(Relationships.gift(&"reeve", &"bread"), G.GiftReaction.LIKED, "liked")
	eq(Relationships.points(&"reeve"), 45, "liked points")
	Relationships.begin_day(3)
	eq(Relationships.gift(&"reeve", &"stone"), G.GiftReaction.NEUTRAL, "neutral")
	eq(Relationships.points(&"reeve"), 65, "neutral points")
	eq(Relationships.gift(&"reeve", &"stone"), G.GiftReaction.ALREADY_GIFTED, "limit")
	eq(Inventory.count(&"stone"), 4, "limit keeps the item")


func test_dislike_never_goes_below_zero() -> void:
	Inventory.add(&"ale", 1)
	Relationships.gift(&"shepherd", &"ale")
	eq(Relationships.points(&"shepherd"), 0, "floored")


func test_signals_fire() -> void:
	var events: Array[String] = []
	Relationships.hearts_changed.connect(func(n: StringName, h: int) -> void:
		events.append("hearts %s %d" % [n, h]))
	Relationships.gifted.connect(func(n: StringName, i: StringName, r: int) -> void:
		events.append("gift %s %s %d" % [n, i, r]))
	Inventory.add(&"ale", 1)
	Relationships.gift(&"alewife", &"ale")
	Relationships.add_points(&"alewife", 20)
	eq(events, ["gift alewife ale 0", "hearts alewife 1"] as Array[String], "events")


func test_save_round_trip_keeps_daily_flags() -> void:
	Relationships.talk(&"miller")
	Inventory.add(&"bread", 1)
	Relationships.gift(&"miller", &"bread")
	var text := JSON.stringify(JSON.from_native(Relationships.to_dict()))
	Relationships.reset()
	eq(Relationships.points(&"miller"), 0, "reset")
	Relationships.from_dict(JSON.to_native(JSON.parse_string(text)))
	eq(Relationships.points(&"miller"), 100, "points restored")
	check(Relationships.talked_today(&"miller"), "talk flag")
	check(Relationships.gifted_today(&"miller"), "gift flag")
	check(Relationships.has_met(&"miller"), "met")
	Relationships.from_dict({})
	eq(Relationships.points(&"miller"), 0, "empty dict resets")


func test_dialogue_band_selection() -> void:
	eq(DialogueLines.greeting_key(0), "greet_low", "0")
	eq(DialogueLines.greeting_key(2), "greet_low", "2")
	eq(DialogueLines.greeting_key(3), "greet_mid", "3")
	eq(DialogueLines.greeting_key(5), "greet_mid", "5")
	eq(DialogueLines.greeting_key(6), "greet_high", "6")
	eq(DialogueLines.greeting_key(10), "greet_high", "10")
	for npc in Content.npcs():
		for key in ["greet_low", "greet_mid", "greet_high", "spring", "summer", "autumn",
				"winter", "rain", "market", "loved", "liked", "neutral", "disliked", "already",
				"lore"]:
			var pool := DialogueLines.pool(npc.id, key)
			check(pool.size() >= 1, "%s %s has lines" % [npc.id, key])
			check(pool.size() == 1 or DialogueLines.pool(npc.id, key)[0] != "", "%s %s" % [npc.id, key])
		var low := DialogueLines.conversation(npc.id, 0, true, 0, false, false, 0, 0)
		var high := DialogueLines.conversation(npc.id, 8, true, 0, false, false, 0, 0)
		eq(low[0], DialogueLines.pool(npc.id, "greet_low")[0], "low greeting")
		eq(high[0], DialogueLines.pool(npc.id, "greet_high")[0], "high greeting")


func test_conversation_context_and_followups() -> void:
	var rainy := DialogueLines.conversation(&"reeve", 0, true, 0, true, true, 0, 0)
	eq(rainy[1], DialogueLines.pool(&"reeve", "rain")[1], "rain beats market")
	var market := DialogueLines.conversation(&"reeve", 0, true, 0, false, true, 0, 0)
	eq(market[1], DialogueLines.pool(&"reeve", "market")[1], "market remark")
	var winter := DialogueLines.conversation(&"reeve", 0, true, G.Season.WINTER, false, false, 0, 0)
	eq(winter[1], DialogueLines.pool(&"reeve", "winter")[1], "season remark")
	var again := DialogueLines.conversation(&"reeve", 0, false, 0, false, false, 0, 3)
	eq(again.size(), 1, "follow-up is one lore line")
	eq(again[0], DialogueLines.pool(&"reeve", "lore")[3], "lore by salt")


func test_shepherd_hints_the_forecast() -> void:
	for kind in [G.WeatherKind.CLEAR, G.WeatherKind.RAIN, G.WeatherKind.STORM]:
		var lines := DialogueLines.conversation(&"shepherd", 0, true, 0, false, false, kind, 0)
		eq(lines.size(), 3, "forecast line appended for kind %d" % kind)
	var plain := DialogueLines.conversation(&"reeve", 0, true, 0, false, false, G.WeatherKind.RAIN, 0)
	eq(plain.size(), 2, "reeve has no forecast lore")

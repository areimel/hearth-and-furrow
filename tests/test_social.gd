extends TestCase
## Relationships, Progress and QuestManager skeleton behaviour.


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


func test_prologue_flow() -> void:
	check(not QuestManager.can_start(&"errand_miller_wheat"), "errand locked")
	var ready: Array[StringName] = []
	QuestManager.quest_ready.connect(func(q: StringName) -> void: ready.append(q))
	check(QuestManager.start(&"prologue"), "start")
	check(not QuestManager.is_ready(&"prologue"), "not ready before talking")
	Relationships.talk(&"reeve")
	eq(ready, [&"prologue"] as Array[StringName], "quest_ready fired once")
	check(QuestManager.complete(&"prologue"), "complete")
	check(QuestManager.is_complete(&"prologue"), "complete state")
	eq(Economy.coins, 150, "coin reward")
	check(Progress.has_flag(&"prologue_done"), "flag reward")
	check(QuestManager.can_start(&"errand_miller_wheat"), "errand unlocked")


func test_delivery_consumes_items() -> void:
	QuestManager.start(&"prologue")
	Relationships.talk(&"reeve")
	QuestManager.complete(&"prologue")
	QuestManager.start(&"errand_miller_wheat")
	Inventory.add(&"wheat_sheaf", 4)
	eq(QuestManager.condition_progress(&"errand_miller_wheat", 0), 4, "progress 4/5")
	check(not QuestManager.complete(&"errand_miller_wheat"), "not enough")
	Inventory.add(&"wheat_sheaf", 3)
	check(QuestManager.complete(&"errand_miller_wheat"), "complete")
	eq(Inventory.count(&"wheat_sheaf"), 2, "5 delivered")
	eq(Relationships.hearts(&"miller"), 1, "friendship reward")

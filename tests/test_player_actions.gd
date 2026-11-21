extends TestCase
## What the hotbar item does, and what happens to loot when the pack is full.


func before_each() -> void:
	SaveManager.new_game()


func test_actions_follow_the_item() -> void:
	eq(PlayerActions.for_item(Content.item(&"hoe_wooden")), G.ToolKind.HOE, "hoe")
	eq(PlayerActions.for_item(Content.item(&"sickle_wooden")), G.ToolKind.SICKLE, "sickle")
	eq(PlayerActions.for_item(Content.item(&"wheat_seed")), PlayerActions.SOW, "seed sows")
	eq(PlayerActions.for_item(Content.item(&"wheat_sheaf")), G.ToolKind.NONE, "produce does nothing")
	eq(PlayerActions.for_item(null), G.ToolKind.NONE, "empty slot")


func test_every_action_has_an_animation() -> void:
	for kind: int in Content.tool_kinds():
		check(PlayerActions.ANIMATIONS.has(kind), "animation for tool kind %d" % kind)
	check(PlayerActions.ANIMATIONS.has(PlayerActions.SOW), "animation for sowing")


func test_loot_adds_records_and_loses_the_overflow() -> void:
	eq(Loot.give(tree, &"apple", 3, &"gathered"), 3, "all added")
	eq(Inventory.count(&"apple"), 3, "in pack")
	eq(Progress.count("gathered.apple"), 3, "recorded")
	Inventory.add(&"log", Inventory.size() * Balance.STACK_SIZE)
	eq(Loot.give(tree, &"log", 5, &"gathered"), 0, "full pack loses loot")


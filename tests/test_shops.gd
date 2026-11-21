extends TestCase
## Shop data, shop-aware pricing, stock, and every kind of transaction.


func before_each() -> void:
	SaveManager.new_game()
	Inventory.reset()
	GameClock.day_index = 0  # a Monday in spring


## Base sell price of an item row (the tests never hard-code prices; data/ is the tuning knob).
func _p(id: StringName) -> int:
	return Content.item(id).base_price


func _shop(id: StringName) -> ShopData:
	return Content.shop(id)


func _ware(shop_id: StringName, entry_id: StringName) -> Dictionary:
	return _shop(shop_id).ware(entry_id)


func test_shop_rows_reference_real_content() -> void:
	eq(Content.shops().size(), 5, "five shops")
	for shop in Content.shops():
		check(Content.npc(shop.keeper) != null, "%s keeper exists" % shop.id)
		for w in shop.wares:
			match w["kind"]:
				&"animal":
					check(Content.has_animal(w["target"]), "%s animal %s" % [shop.id, w["target"]])
				&"station":
					check(Content.station(w["target"]) != null, "%s station" % shop.id)
				&"tool_upgrade":
					check(w["target"] in Content.tool_kinds(), "%s tool kind" % shop.id)
				_:
					check(Content.has_item(w["target"]), "%s item %s" % [shop.id, w["target"]])
			for id: StringName in w["requires"]:
				check(Content.has_item(id), "%s requires %s" % [shop.id, id])
		for rule in shop.buy_rules:
			for id: StringName in rule["ids"]:
				check(Content.has_item(id), "%s buys %s" % [shop.id, id])


func test_buy_rules_and_sell_prices() -> void:
	var chandler := _shop(&"chandler")
	eq(Economy.shop_sell_price(chandler, &"cheese"), _p(&"cheese"), "chandler pays base")
	eq(Economy.shop_sell_price(chandler, &"axe_wooden"), 0, "tools not bought")
	eq(Economy.shop_sell_price(chandler, &"wheat_seed"), 0, "seeds not bought")
	eq(Economy.shop_sell_price(chandler, &"no_such_item"), 0, "unknown item")
	eq(Economy.shop_sell_price(_shop(&"alewife"), &"ale"), roundi(_p(&"ale") * 1.2), "alewife premium")
	eq(Economy.shop_sell_price(_shop(&"alewife"), &"cheese"), 0, "alewife ignores cheese")
	eq(Economy.shop_sell_price(_shop(&"shepherd"), &"fleece"), roundi(_p(&"fleece") * 1.2), "wool premium")
	eq(Economy.shop_sell_price(_shop(&"miller"), &"grain"), _p(&"grain"), "miller grain")
	check(not _shop(&"blacksmith").buys_anything(), "smith buys nothing")
	eq(Economy.shop_sell_price(_shop(&"blacksmith"), &"cheese"), 0, "smith pays nothing")


func test_market_day_bonus_applies_to_shop_sales() -> void:
	var shepherd := _shop(&"shepherd")
	GameClock.day_index = 5
	check(Calendar.is_market_day(), "Saturday")
	eq(Economy.shop_sell_price(shepherd, &"fleece"), roundi(_p(&"fleece") * 1.2 * Balance.MARKET_DAY_SELL_BONUS), "market premium")
	Inventory.add(&"fleece", 2)
	var earned := Economy.shop_sell(&"shepherd", &"fleece", 2)
	eq(earned, 2 * roundi(_p(&"fleece") * 1.2 * Balance.MARKET_DAY_SELL_BONUS), "earned")
	eq(Economy.coins, Balance.START_COINS + earned, "coins")
	eq(Progress.count(&"sold.fleece"), 2, "recorded")
	eq(Inventory.count(&"fleece"), 0, "removed")
	eq(Economy.shop_sell(&"shepherd", &"cheese", 1), 0, "not in stock, not sold")
	eq(Economy.shop_sell(&"blacksmith", &"fleece", 1), 0, "smith refuses")


func test_seed_season_restriction() -> void:
	var chandler := _shop(&"chandler")
	var barley := _ware(&"chandler", &"item:barley_seed")
	var cabbage := _ware(&"chandler", &"item:cabbage_seed")
	eq(Economy.shop_block_reason(chandler, barley), "", "barley in spring")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.AUTUMN, 3)
	eq(Economy.shop_block_reason(chandler, barley), "Out of season", "barley in autumn")
	eq(Economy.shop_block_reason(chandler, cabbage), "", "cabbage in autumn")
	var before := Economy.coins
	eq(Economy.shop_buy(&"chandler", &"item:barley_seed"), "Out of season", "refused")
	eq(Economy.coins, before, "coins untouched")
	GameClock.day_index = Calendar.day_index_for(1, G.Season.WINTER, 3)
	for w in chandler.wares:
		check(Economy.shop_block_reason(chandler, w) == "Out of season", "nothing sown in winter")


func test_buy_item_stock_and_restock() -> void:
	Economy.add_coins(100)
	var entry := _ware(&"chandler", &"item:wheat_seed")
	var chandler := _shop(&"chandler")
	var price := _p(&"wheat_seed")
	eq(Economy.shop_buy_price(chandler, entry), price, "price from the item row")
	eq(Economy.shop_stock_left(chandler, entry), 30, "full stock")
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "", "bought")
	eq(Economy.coins, Balance.START_COINS + 100 - price, "paid")
	eq(Inventory.count(&"wheat_seed"), 11, "received")
	eq(Economy.shop_stock_left(chandler, entry), 29, "stock down")
	eq(Progress.count(&"bought.wheat_seed"), 1, "recorded")
	for i in 29:
		eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "", "buy %d" % i)
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "Sold out today", "sold out")
	GameClock.day_ending.emit(0)
	eq(Economy.shop_stock_left(chandler, entry), 30, "restocked at day end")
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "", "buy again")


func test_unaffordable_refusal_leaves_state_untouched() -> void:
	var price := _p(&"wheat_seed")
	Economy.coins = price - 1
	var chandler := _shop(&"chandler")
	var entry := _ware(&"chandler", &"item:wheat_seed")
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "Need %d coins" % price, "refused")
	eq(Economy.coins, price - 1, "coins")
	eq(Inventory.count(&"wheat_seed"), 10, "no seed")
	eq(Economy.shop_stock_left(chandler, entry), 30, "stock")
	eq(Progress.count(&"bought.wheat_seed"), 0, "not recorded")
	eq(Economy.shop_buy(&"chandler", &"nope"), "Not for sale", "unknown ware")


func test_full_pack_refuses_purchase() -> void:
	for i in Inventory.size():
		if Inventory.slot_id(i).is_empty():
			Inventory.add(&"stone", 99)
	check(not Inventory.can_add(&"barm", 1), "pack is full")
	eq(Economy.shop_buy(&"alewife", &"item:barm"), "Your pack is full", "refused")
	eq(Economy.coins, Balance.START_COINS, "no charge")


func test_tool_upgrade_swaps_in_place_and_consumes_materials() -> void:
	var tier := Content.tool_tier(&"iron_shod")
	Economy.add_coins(tier.upgrade_coins + 50)
	Inventory.add(&"log", int(tier.upgrade_items[&"log"]) + 2)
	Inventory.add(&"stone", int(tier.upgrade_items[&"stone"]))
	var slot := -1
	for i in Inventory.size():
		if Inventory.slot_id(i) == &"axe_wooden":
			slot = i
	check(slot >= 0, "start with an axe")
	var kind := G.ToolKind.AXE
	var before := Economy.coins
	eq(Economy.shop_buy(&"blacksmith", StringName("tool_upgrade:%d" % kind)), "", "upgraded")
	eq(Inventory.slot_id(slot), &"axe_iron_shod", "same slot")
	eq(Inventory.count(&"axe_wooden"), 0, "old tool gone")
	eq(Inventory.count(&"log"), 2, "upgrade logs used")
	eq(Economy.coins, before - tier.upgrade_coins, "paid")
	eq(Progress.count(&"bought.axe_iron_shod"), 1, "recorded")
	eq(Economy.shop_buy(&"blacksmith", StringName("tool_upgrade:%d" % kind)), "Already the finest tier", "no more")


func test_tool_upgrade_refusals() -> void:
	var tier := Content.tool_tier(&"iron_shod")
	var logs := int(tier.upgrade_items[&"log"])
	Economy.add_coins(tier.upgrade_coins)
	var id := StringName("tool_upgrade:%d" % G.ToolKind.HOE)
	eq(Economy.shop_buy(&"blacksmith", id), "Need %s" % Loot.shortfall(tier.upgrade_items).trim_prefix("Need "), "materials missing")
	eq(Inventory.count(&"hoe_wooden"), 1, "hoe kept")
	Inventory.add(&"log", logs)
	Inventory.add(&"stone", int(tier.upgrade_items[&"stone"]))
	Economy.coins = tier.upgrade_coins - 1
	eq(Economy.shop_buy(&"blacksmith", id), "Need %d coins" % tier.upgrade_coins, "coins short")
	eq(Inventory.count(&"log"), logs, "logs kept")
	Inventory.remove(&"hoe_wooden", 1)
	Economy.coins = 500
	eq(Economy.shop_buy(&"blacksmith", id), "You have no tool to upgrade", "no tool")


func test_paid_milling() -> void:
	Inventory.add(&"grain", 3)
	var before := Economy.coins
	eq(Economy.shop_buy(&"miller", &"mill_grain"), "", "milled")
	eq(Inventory.count(&"grain"), 2, "one grain consumed")
	eq(Inventory.count(&"flour"), 1, "flour made")
	eq(Economy.coins, before - _fee(), "fee paid")
	Inventory.remove(&"grain", 2)
	eq(Economy.shop_buy(&"miller", &"mill_grain"), "Need 1 Wheat Grain", "no grain")
	eq(Economy.coins, before - _fee(), "no second fee")
	eq(Economy.shop_buy(&"miller", &"item:flour"), "", "dear flour bought outright")
	eq(Economy.coins, before - _fee() - _ware(&"miller", &"item:flour")["price"], "flour at the miller's price")


func _fee() -> int:
	return _ware(&"miller", &"mill_grain")["price"]


func test_station_kit_gives_materials() -> void:
	var entry := {"id": &"station:quern", "kind": &"station", "target": &"quern", "price": -1,
		"stock": -1, "seasons": [], "sowable": false, "unlock": &"", "requires": {},
		"amount": 1, "label": ""}
	eq(ShopDeals.default_price(entry), _p(&"stone") * 8, "sum of materials")
	eq(ShopDeals.deliver(entry), "", "delivered")
	eq(Inventory.count(&"stone"), 8, "quern materials")


func test_animal_purchase_without_livestock() -> void:
	Economy.add_coins(2000)
	eq(Economy.shop_buy(&"shepherd", &"animal:sheep"), "No pen to keep animals in", "no node")
	eq(Economy.coins, Balance.START_COINS + 2000, "coins kept")
	eq(Progress.count(&"bought.sheep"), 0, "not recorded")


func test_animal_purchase_with_livestock() -> void:
	var level: Level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	var live: Livestock = level.get_node("Livestock")
	await tree.process_frame
	await tree.process_frame
	Economy.add_coins(3000)
	var sheep := live.count(&"sheep")
	eq(Economy.shop_buy(&"shepherd", &"animal:sheep"), "", "sheep bought")
	eq(live.count(&"sheep"), sheep + 1, "sheep in the pen")
	eq(Economy.coins, Balance.START_COINS + 3000 - Content.animal(&"sheep").price, "paid the sheep price")
	eq(Progress.count(&"bought.sheep"), 1, "recorded")
	while live.can_add(&"cow"):
		live.add_animal(&"cow")
	var coins := Economy.coins
	GameClock.day_ending.emit(0)  # restock, so only the pen limit can refuse
	eq(Economy.shop_buy(&"shepherd", &"animal:cow"), "No room for another", "pen full")
	eq(Economy.coins, coins, "no charge when refused")
	level.free()
	await tree.process_frame


func test_stock_survives_save_and_old_saves_load() -> void:
	Economy.add_coins(50)
	var price := _p(&"wheat_seed")
	Economy.shop_buy(&"chandler", &"item:wheat_seed")
	Economy.shop_buy(&"chandler", &"item:wheat_seed")
	var saved := JSON.to_native(JSON.from_native(Economy.to_dict())) as Dictionary
	Economy.reset()
	var entry := _ware(&"chandler", &"item:wheat_seed")
	eq(Economy.shop_stock_left(_shop(&"chandler"), entry), 30, "reset restocks")
	Economy.from_dict(saved)
	eq(Economy.shop_stock_left(_shop(&"chandler"), entry), 28, "stock restored")
	eq(Economy.coins, Balance.START_COINS + 50 - 2 * price, "coins restored")
	Economy.from_dict({"coins": 77})
	eq(Economy.coins, 77, "old save: coins")
	eq(Economy.shop_stock_left(_shop(&"chandler"), entry), 30, "old save: full stock")

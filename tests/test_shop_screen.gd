extends TestCase
## ShopScreen opening, populating, trading and closing; the Shops feature root.

const SCREEN_SCENE := preload("res://scenes/ui/shop_screen.tscn")
const SHOPS_SCENE := preload("res://scenes/world/shops.tscn")

## Stand-in for the NPC system's Villagers node: records register_option calls.
class FakeVillagers extends Node:
	var options: Array[Dictionary] = []

	func register_option(npc_id: StringName, text: String, callback: Callable,
			condition: Callable = Callable()) -> void:
		options.append({"npc": npc_id, "text": text, "callback": callback, "condition": condition})


func before_each() -> void:
	SaveManager.new_game()
	Inventory.reset()
	GameClock.day_index = 0


func _screen() -> ShopScreen:
	var screen: ShopScreen = SCREEN_SCENE.instantiate()
	tree.root.add_child(screen)
	return screen


func test_opens_populates_and_closes() -> void:
	var screen := _screen()
	await tree.process_frame
	check(not screen.open_for(&"no_such_shop"), "unknown shop refused")
	check(not screen.is_open, "still closed")
	check(screen.open_for(&"chandler"), "chandler opens")
	check(screen.is_open and screen.visible, "open")
	eq(screen._menu.entry_count(), 6, "six seeds listed")
	check(screen._menu.entry_button(0).text.begins_with("Seed Wheat"), "first ware named")
	eq(screen._grid.slot_count(), Inventory.size(), "sell grid mirrors the pack")
	eq(screen.tab, ShopScreen.Tab.BUY, "starts on buy")
	screen.show_tab(ShopScreen.Tab.SELL)
	check(screen._sell_box.visible and not screen._buy_box.visible, "sell tab shown")
	screen.close()
	check(not screen.is_open, "closed")
	screen.free()


func test_buy_and_sell_through_the_screen() -> void:
	var screen := _screen()
	await tree.process_frame
	screen.open_for(&"chandler")
	var seeds := Inventory.count(&"barley_seed")
	screen._on_ware_selected(&"item:barley_seed")
	eq(Inventory.count(&"barley_seed"), seeds + 1, "bought a seed")
	var seed_price := Economy.price_of(&"barley_seed")
	eq(Economy.coins, Balance.START_COINS - seed_price, "paid")
	Inventory.add(&"cheese", 3)
	var slot := -1
	for i in Inventory.size():
		if Inventory.slot_id(i) == &"cheese":
			slot = i
	screen._on_slot_activated(slot)
	eq(Inventory.count(&"cheese"), 2, "sold one")
	eq(Economy.coins, Balance.START_COINS - seed_price + Economy.price_of(&"cheese"), "chandler paid base")
	screen._on_slot_activated(0)  # the hoe: not bought
	eq(Inventory.count(&"hoe_wooden"), 1, "tool kept")
	screen._show_sale(slot)
	check(screen._sell_detail._facts.text.contains("Pays %d" % Economy.price_of(&"cheese")), "detail shows the price")
	screen._show_sale(0)
	eq(screen._sell_detail._note.text, "Won't buy that", "detail refuses a tool")
	screen.close()
	screen.free()


func test_unaffordable_ware_is_greyed_with_reason() -> void:
	var price := Economy.price_of(&"wheat_seed")
	Economy.coins = price - 1
	var screen := _screen()
	await tree.process_frame
	screen.open_for(&"chandler")
	screen._show_ware(&"item:wheat_seed")
	eq(screen._buy_detail._note.text, "Need %d coins" % price, "reason shown")
	eq(screen._menu.entry_button(0).theme_type_variation, &"ListEntryGrey", "greyed")
	screen.close()
	screen.free()


func test_one_sided_shops_hide_the_other_tab() -> void:
	var screen := _screen()
	await tree.process_frame
	screen.open_for(&"blacksmith")
	check(not screen._strip.visible, "smith has no sell tab, so no tab strip")
	screen.show_tab(ShopScreen.Tab.SELL)
	eq(screen.tab, ShopScreen.Tab.BUY, "stays on buy")
	eq(screen._menu.entry_count(), 5, "five tool upgrades")
	screen.close()
	screen.open_for(&"alewife")
	check(screen._strip.visible, "alewife buys and sells, so tabs show")
	screen.close()
	screen.free()


func test_shops_root_registers_trade_options_and_opens() -> void:
	var villagers := FakeVillagers.new()
	villagers.add_to_group(&"Villagers")
	tree.root.add_child(villagers)
	var shops: Shops = SHOPS_SCENE.instantiate()
	tree.root.add_child(shops)
	await tree.process_frame
	await tree.process_frame
	eq(villagers.options.size(), Content.shops().size(), "one option per shop")
	var keepers: Array = villagers.options.map(func(o: Dictionary) -> StringName: return o["npc"])
	for shop in Content.shops():
		check(shop.keeper in keepers, "%s has Trade" % shop.keeper)
	eq(villagers.options[0]["text"], "Trade", "option text")
	check(villagers.options[0]["condition"].call(), "open on a normal day")
	check(villagers.options[0]["callback"].call(), "callback opens the shop")
	var screen := tree.get_first_node_in_group(&"ShopScreen") as ShopScreen
	check(screen != null and screen.is_open, "screen created and open")
	screen.close()
	check(not shops.open(&"nonexistent"), "unknown shop")
	screen.free()
	shops.free()
	villagers.free()


func test_shops_root_without_villagers_is_harmless() -> void:
	var shops: Shops = SHOPS_SCENE.instantiate()
	tree.root.add_child(shops)
	await tree.process_frame
	await tree.process_frame
	check(shops.open(&"miller"), "open works alone")
	var screen := tree.get_first_node_in_group(&"ShopScreen") as ShopScreen
	check(screen.is_open, "open")
	screen.free()
	shops.free()

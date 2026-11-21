extends TestCase
## Economy: purse, prices, market-day bonus, buy/sell through the Inventory.


func before_each() -> void:
	SaveManager.new_game()
	Inventory.from_dict({})


func test_purse() -> void:
	eq(Economy.coins, Balance.START_COINS, "start coins")
	check(Economy.can_afford(100) and not Economy.can_afford(101), "can_afford")
	check(not Economy.spend(500), "cannot overspend")
	eq(Economy.coins, 100, "unchanged")
	check(Economy.spend(40), "spend")
	Economy.add_coins(15)
	eq(Economy.coins, 75, "after spend and add")


func test_prices() -> void:
	eq(Economy.price_of(&"cheese"), Content.item(&"cheese").base_price, "item price from row")
	eq(Economy.price_of(&"cow"), Content.animal(&"cow").price, "animal price from row")
	eq(Economy.price_of(&"axe_wooden"), 0, "tools unpriced")
	eq(Economy.price_of(&"no_such_thing"), 0, "unknown is 0")
	GameClock.day_index = 0  # Monday
	eq(Economy.sell_price(&"cheese"), Economy.price_of(&"cheese"), "weekday sale")
	GameClock.day_index = 5  # Saturday
	check(Calendar.is_market_day(), "Saturday is market day")
	eq(Economy.sell_price(&"cheese"), roundi(Economy.price_of(&"cheese") * Balance.MARKET_DAY_SELL_BONUS), "market")
	GameClock.day_index = 0


func test_buy_and_sell() -> void:
	var seed_price := Economy.price_of(&"wheat_seed")
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "", "buy a seed")
	eq(Economy.coins, Balance.START_COINS - seed_price, "paid the seed price")
	eq(Inventory.count(&"wheat_seed"), 1, "seed received")
	Economy.coins = 0
	eq(Economy.shop_buy(&"chandler", &"item:wheat_seed"), "Need %d coins" % seed_price, "too dear")
	eq(Economy.shop_sell(&"chandler", &"wheat_seed", 1), 0, "chandler does not buy seed")
	Inventory.add(&"cheese", 2)
	var each := Economy.shop_sell_price(Content.shop(&"shepherd"), &"cheese")
	eq(Economy.shop_sell(&"shepherd", &"cheese", 2), each * 2, "sold 2 cheese")
	eq(Economy.shop_sell(&"shepherd", &"cheese", 5), 0, "cannot sell more than held")
	eq(Progress.count(&"sold.cheese"), 2, "sale recorded")


func test_demand_falloff() -> void:
	var full := Balance.DEMAND_FULL_PRICE_UNITS
	var shop := Content.shop(&"shepherd")
	Inventory.add(&"cheese", full + 4)
	var base := Economy.shop_sell_price(shop, &"cheese")
	Economy.shop_sell(&"shepherd", &"cheese", full)
	eq(Economy.coins, Balance.START_COINS + base * full, "first units pay full price")
	check(Economy.shop_sell_price(shop, &"cheese") < base, "next unit pays less")
	Economy.shop_sell(&"shepherd", &"cheese", 4)
	check(Economy.coins < Balance.START_COINS + base * (full + 4), "bulk sale is discounted")
	GameClock.day_ending.emit(0)
	eq(Economy.shop_sell_price(shop, &"cheese"), base, "demand recovers overnight")


func test_round_trip() -> void:
	Economy.add_coins(250)
	var saved := Economy.to_dict()
	Economy.reset()
	Economy.from_dict(saved)
	eq(Economy.coins, 350, "coins restored")

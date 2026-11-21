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
	eq(Economy.price_of(&"cheese"), 90, "item price from row")
	eq(Economy.price_of(&"cow"), 1000, "animal price from row")
	eq(Economy.price_of(&"axe_wooden"), 0, "tools unpriced")
	eq(Economy.price_of(&"no_such_thing"), 0, "unknown is 0")
	GameClock.day_index = 0  # Monday
	eq(Economy.sell_price(&"cheese"), 90, "weekday sale")
	GameClock.day_index = 5  # Saturday
	check(Calendar.is_market_day(), "Saturday is market day")
	eq(Economy.sell_price(&"cheese"), roundi(90 * Balance.MARKET_DAY_SELL_BONUS), "market")
	GameClock.day_index = 0


func test_buy_and_sell() -> void:
	check(Economy.buy(&"wheat_seed", 4), "buy seeds")
	eq(Economy.coins, 80, "paid 4 x 5")
	eq(Inventory.count(&"wheat_seed"), 4, "seeds received")
	check(not Economy.buy(&"cabbage_seed", 10), "cannot afford 150")
	check(not Economy.buy(&"linen_sack", 1), "unpriced not for sale")
	eq(Economy.sell(&"wheat_seed", 2), 10, "sold 2")
	eq(Economy.sell(&"wheat_seed", 5), 0, "cannot sell more than held")
	eq(Progress.count(&"sold.wheat_seed"), 2, "sale recorded")


func test_round_trip() -> void:
	Economy.add_coins(250)
	var saved := Economy.to_dict()
	Economy.reset()
	Economy.from_dict(saved)
	eq(Economy.coins, 350, "coins restored")

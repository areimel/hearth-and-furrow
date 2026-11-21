extends Node
## Autoload `Economy`: the coin purse and shop prices. Prices come from the item row
## (ItemData.base_price) or the animal row (AnimalData.price); nothing else stores them.

signal coins_changed(coins: int, delta: int)
signal item_sold(id: StringName, amount: int, coins: int)
signal item_bought(id: StringName, amount: int, coins: int)

## Current purse. Change it only through add_coins()/spend().
var coins: int = Balance.START_COINS


## Units sold today per ware, "shop/ware" -> count; cleared when the day ends (restock).
var _sold_today: Dictionary = {}
## Units of each item id sold to any shop today; later units fetch less (see unit_demand()).
var _demand_today: Dictionary = {}


func _ready() -> void:
	SaveManager.register(&"economy", self)
	GameClock.day_ending.connect(_on_day_ending)


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins, amount)


func can_afford(amount: int) -> bool:
	return amount <= coins


## Takes `amount` coins if the purse has them; false and no change otherwise.
func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	add_coins(-amount)
	return true


## Base price of an item or animal id; 0 if unknown or not for sale.
func price_of(id: StringName) -> int:
	if Content.has_item(id):
		return Content.item(id).base_price
	if Content.has_animal(id):
		return Content.animal(id).price
	return 0


## What a shop charges for one.
func buy_price(id: StringName) -> int:
	return price_of(id)


## What a shop pays for one (base price x market-day bonus), rounded.
func sell_price(id: StringName) -> int:
	return roundi(price_of(id) * sell_multiplier())


## MARKET-DAY HOOK: the one place price modifiers are applied to sales. Seasonal or
## supply modifiers (v1) belong here too.
func sell_multiplier() -> float:
	return Balance.MARKET_DAY_SELL_BONUS if Calendar.is_market_day() else 1.0


## Buys `amount` of an item into the Inventory. False and no change if the item is not
## priced, the purse is short, or it will not fit. (Animals: use spend() + Livestock.)
func buy(id: StringName, amount: int = 1) -> bool:
	var cost := buy_price(id) * amount
	if amount <= 0 or not Content.has_item(id) or buy_price(id) <= 0:
		return false
	if not can_afford(cost) or not Inventory.can_add(id, amount):
		return false
	spend(cost)
	Inventory.add(id, amount)
	Progress.record(&"bought", id, amount)
	item_bought.emit(id, amount, cost)
	return true


# ---------------------------------------------------------------- shops

## Units left today of a ware, or -1 if it is unlimited.
func shop_stock_left(shop: ShopData, entry: Dictionary) -> int:
	var cap: int = entry["stock"]
	if cap < 0:
		return -1
	return maxi(cap - int(_sold_today.get(_key(shop.id, entry["id"]), 0)), 0)


## Coins a shop charges for one purchase of `entry` (its own price, else the content row's).
func shop_buy_price(_shop: ShopData, entry: Dictionary) -> int:
	var price: int = entry["price"]
	return price if price >= 0 else ShopDeals.default_price(entry)


## Coins `shop` pays for the next one `item_id` (base x the shop's factor x market-day
## bonus x today's demand falloff); 0 if the keeper will not buy it.
func shop_sell_price(shop: ShopData, item_id: StringName) -> int:
	return shop_sell_quote(shop, item_id, 1)


## Coins `shop` pays for `amount` of `item_id` sold now: each unit is worth a little less
## once more than Balance.DEMAND_FULL_PRICE_UNITS of it were sold today.
func shop_sell_quote(shop: ShopData, item_id: StringName, amount: int) -> int:
	if not Content.has_item(item_id):
		return 0
	var item := Content.item(item_id)
	var each := item.base_price * shop.buy_factor(item) * sell_multiplier()
	var sold := int(_demand_today.get(item_id, 0))
	var total := 0
	for n in amount:
		total += maxi(roundi(each * unit_demand(sold + n)), 1 if each > 0.0 else 0)
	return total


## Price factor of the (`sold_so_far` + 1)th unit of one item sold in a day: 1.0 for the
## first Balance.DEMAND_FULL_PRICE_UNITS, then falling by DEMAND_STEP each, never below DEMAND_FLOOR.
static func unit_demand(sold_so_far: int) -> float:
	var over := sold_so_far - Balance.DEMAND_FULL_PRICE_UNITS + 1
	return 1.0 if over <= 0 else maxf(1.0 - over * Balance.DEMAND_STEP, Balance.DEMAND_FLOOR)


## Why `entry` cannot be bought right now (locked, out of season, sold out, missing
## materials, no room, too dear), or "" if it can.
func shop_block_reason(shop: ShopData, entry: Dictionary) -> String:
	if not Progress.has_flag(entry["unlock"]):
		return "Not yet available"
	if not _in_season(entry):
		return "Out of season"
	if shop_stock_left(shop, entry) == 0:
		return "Sold out today"
	var reason := ShopDeals.blocked(entry)
	if reason.is_empty() and not can_afford(shop_buy_price(shop, entry)):
		return "Need %d coins" % shop_buy_price(shop, entry)
	return reason


## Buys one lot of ware `entry_id` from shop `shop_id`. Returns "" on success, else the
## reason it was refused; a refusal changes nothing. Records `bought` progress.
func shop_buy(shop_id: StringName, entry_id: StringName) -> String:
	var shop := Content.shop(shop_id)
	var entry := shop.ware(entry_id) if shop else {}
	if entry.is_empty():
		return "Not for sale"
	var reason := shop_block_reason(shop, entry)
	if not reason.is_empty():
		return reason
	var price := shop_buy_price(shop, entry)
	var bought := ShopDeals.bought_id(entry)
	reason = ShopDeals.deliver(entry)
	if not reason.is_empty():
		return reason
	spend(price)
	var key := _key(shop_id, entry_id)
	_sold_today[key] = int(_sold_today.get(key, 0)) + 1
	Progress.record(&"bought", bought, int(entry["amount"]))
	item_bought.emit(bought, int(entry["amount"]), price)
	return ""


## Sells `amount` of an item to shop `shop_id` at its price. Returns coins earned
## (0 = the keeper does not buy it or you lack that many). With `slot` >= 0 the items
## are taken from that Inventory slot (which must hold them) instead of the pack at large.
func shop_sell(shop_id: StringName, item_id: StringName, amount: int = 1, slot: int = -1) -> int:
	var shop := Content.shop(shop_id)
	var earned := shop_sell_quote(shop, item_id, amount) if shop else 0
	if amount <= 0 or earned <= 0:
		return 0
	if slot >= 0:
		if Inventory.slot_id(slot) != item_id or Inventory.slot_count(slot) < amount:
			return 0
		Inventory.remove_at(slot, amount)
	elif not Inventory.remove(item_id, amount):
		return 0
	_demand_today[item_id] = int(_demand_today.get(item_id, 0)) + amount
	add_coins(earned)
	Progress.record(&"sold", item_id, amount)
	item_sold.emit(item_id, amount, earned)
	return earned


func _key(shop_id: StringName, entry_id: StringName) -> String:
	return "%s/%s" % [shop_id, entry_id]


func _in_season(entry: Dictionary) -> bool:
	var season := Calendar.season()
	if not entry["seasons"].is_empty() and not season in entry["seasons"]:
		return false
	var crop := Content.crop_for_seed(entry["target"]) if entry["sowable"] else null
	return crop == null or not entry["sowable"] or crop.grows_in(season)


func _on_day_ending(_day: int) -> void:
	_sold_today.clear()
	_demand_today.clear()


func reset() -> void:
	var delta := Balance.START_COINS - coins
	coins = Balance.START_COINS
	_sold_today.clear()
	_demand_today.clear()
	coins_changed.emit(coins, delta)


func to_dict() -> Dictionary:
	return {"coins": coins, "sold_today": _sold_today.duplicate(),
		"demand_today": _demand_today.duplicate()}


func from_dict(data: Dictionary) -> void:
	var before := coins
	coins = maxi(int(data.get("coins", Balance.START_COINS)), 0)
	_sold_today.clear()
	var saved: Dictionary = data.get("sold_today", {})
	for key: Variant in saved:
		_sold_today[str(key)] = int(saved[key])
	_demand_today.clear()
	var demand: Dictionary = data.get("demand_today", {})
	for key: Variant in demand:
		_demand_today[StringName(str(key))] = int(demand[key])
	coins_changed.emit(coins, coins - before)

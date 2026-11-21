extends Node
## Autoload `Economy`: the coin purse and shop prices. Prices come from the item row
## (ItemData.base_price) or the animal row (AnimalData.price); nothing else stores them.

signal coins_changed(coins: int, delta: int)
signal item_sold(id: StringName, amount: int, coins: int)
signal item_bought(id: StringName, amount: int, coins: int)

const Balance := preload("res://data/balance.gd")

## Current purse. Change it only through add_coins()/spend().
var coins: int = Balance.START_COINS


func _ready() -> void:
	SaveManager.register(&"economy", self)


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


## Sells `amount` of an item from the Inventory. Returns coins earned (0 = nothing sold).
func sell(id: StringName, amount: int = 1) -> int:
	if amount <= 0 or sell_price(id) <= 0 or not Inventory.remove(id, amount):
		return 0
	var earned := sell_price(id) * amount
	add_coins(earned)
	Progress.record(&"sold", id, amount)
	item_sold.emit(id, amount, earned)
	return earned


func reset() -> void:
	var delta := Balance.START_COINS - coins
	coins = Balance.START_COINS
	coins_changed.emit(coins, delta)


func to_dict() -> Dictionary:
	return {"coins": coins}


func from_dict(data: Dictionary) -> void:
	var before := coins
	coins = maxi(int(data.get("coins", Balance.START_COINS)), 0)
	coins_changed.emit(coins, coins - before)

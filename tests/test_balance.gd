extends TestCase
## Economy yardsticks from data/balance.gd, checked from the rows: processing pays, crops are
## not dominated, winter and Spring 1 cannot soft-lock. tools/year_sim.gd checks the totals.

const BYPRODUCTS: Array[StringName] = [&"barm", &"straw"]
const SEASON_DAYS := 28


func _is_raw(item: ItemData) -> bool:
	return item.category in G.RAW_CATEGORIES


## Raw-material cost of one unit of `id`: raw items cost their base price; crafted items
## cost their inputs (byproducts are free), shared across the recipe's main output.
func _raw_cost(id: StringName) -> float:
	var item := Content.item(id)
	if _is_raw(item):
		return float(item.base_price)
	var recipe: RecipeData = Content.recipes_producing(id)[0]
	var total := 0.0
	for input_id: StringName in recipe.inputs:
		if input_id not in BYPRODUCTS:
			total += _raw_cost(input_id) * int(recipe.inputs[input_id])
	return total / int(recipe.outputs[id])


## Coins one unit of `id` earns when carried as far down its chain as it goes.
func _chain_value(id: StringName) -> float:
	var best := float(Content.item(id).base_price)
	for recipe in Content.recipes_using(id):
		var units := 0
		for input_id: StringName in recipe.inputs:
			if input_id not in BYPRODUCTS:
				units += int(recipe.inputs[input_id])
		var value := 0.0
		for out_id: StringName in recipe.outputs:
			if out_id not in BYPRODUCTS:
				value += _chain_value(out_id) * int(recipe.outputs[out_id])
		best = maxf(best, value / maxi(units, 1))
	return best


func test_finished_goods_are_worth_two_and_a_half_to_four_times_their_raw_inputs() -> void:
	for id: StringName in [&"bread", &"butter", &"cheese", &"ale", &"linen"]:
		var ratio := Content.item(id).base_price / _raw_cost(id)
		check(ratio >= 2.5 and ratio <= 4.0, "%s is %.2fx its raw inputs" % [id, ratio])


func test_every_processing_step_adds_value() -> void:
	for item in Content.items():
		if _is_raw(item) or item.id in BYPRODUCTS or Content.recipes_producing(item.id).is_empty() \
				or item.base_price <= 0:
			continue
		check(item.base_price >= _raw_cost(item.id), "%s sells below its inputs" % item.id)


func test_cheese_is_the_main_dairy_earner_and_butter_the_premium_unit() -> void:
	var cheese_per_milk := Content.item(&"cheese").base_price / 3.0
	var butter_per_milk := Content.item(&"butter").base_price / 2.0
	check(cheese_per_milk >= butter_per_milk, "cheese earns at least as much per milk")
	check(Content.item(&"butter").base_price < Content.item(&"cheese").base_price, "butter is the smaller line")
	check(Content.item(&"linen").base_price > Content.item(&"cheese").base_price, "cloth is the premium line")
	check(Content.item(&"ale").base_price > Content.item(&"bread").base_price, "ale out-earns bread")


## Coins a tile earns per day over one 28-day season: every harvest carried down its chain,
## minus the seed (bought once for a regrowing crop, once per harvest otherwise).
func _coins_per_tile_day(crop: CropData) -> float:
	var regrows := crop.regrow_days > 0
	var harvests := 1 + (SEASON_DAYS - crop.days_to_mature) / crop.regrow_days if regrows \
			else SEASON_DAYS / crop.days_to_mature
	var seeds := 1 if regrows else harvests
	var seed_cost := Content.item(crop.seed_item).base_price
	return (harvests * _chain_value(crop.yield_item) * crop.yield_amount - seeds * seed_cost) / SEASON_DAYS


func test_every_crop_ripens_twice_in_its_shortest_season_run() -> void:
	for crop in Content.crops():
		var needed := crop.days_to_mature + (crop.regrow_days if crop.regrow_days > 0 else crop.days_to_mature)
		check(needed <= SEASON_DAYS, "%s cannot ripen twice in a season" % crop.id)


func test_no_crop_is_dominated_by_more_than_two_to_one() -> void:
	var low := 1e9
	var high := 0.0
	var report := ""
	for crop in Content.crops():
		var value := _coins_per_tile_day(crop)
		report += " %s=%.2f" % [crop.id, value]
		low = minf(low, value)
		high = maxf(high, value)
		check(value > 0.0, "%s loses money" % crop.id)
	check(high / low <= 2.0, "best crop earns %.2f per tile-day, worst %.2f:%s" % [high, low, report])


func test_garden_crops_reward_the_daily_watering() -> void:
	var field := 0.0
	var garden := 0.0
	for crop in Content.crops():
		var value := _coins_per_tile_day(crop)
		if crop.kind == G.CropKind.GARDEN:
			garden = maxf(garden, value)
		else:
			field = maxf(field, value)
	check(garden >= field * 0.75, "garden best %.2f vs field best %.2f" % [garden, field])


func test_spring_one_seeds_are_always_affordable() -> void:
	var seeds := 0
	for entry: Array in Balance.START_LOADOUT:
		if Content.item(entry[0]).is_seed():
			seeds += Content.item(entry[0]).base_price * int(entry[1])
	check(Content.item(&"trout").base_price * 5 >= seeds, "five trout re-buy the starting seed")
	var herd_day := 0
	for id: StringName in Balance.STARTER_HERD:
		var animal := Content.animal(id)
		herd_day += Content.item(animal.product_item).base_price * int(Balance.STARTER_HERD[id])
	check(herd_day > 0, "the starter herd earns even with an empty field")


func test_winter_has_earners_and_feed_is_for_sale() -> void:
	for animal in Content.animals():
		check(G.Season.WINTER in animal.feed_seasons, "%s needs winter feed" % animal.id)
		var sold := false
		for ware: Dictionary in Content.shop(&"shepherd").wares:
			sold = sold or ware["target"] == animal.feed_item
		check(sold, "%s feed can always be bought" % animal.id)
	for crop in Content.crops():
		check(not crop.grows_in(G.Season.WINTER), "%s grows in winter (winter is for animals)" % crop.id)

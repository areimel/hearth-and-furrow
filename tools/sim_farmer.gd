class_name SimFarmer extends RefCounted
## The scripted farmer behind tools/year_sim.gd: one diligent player's daily chores, done
## through the public APIs only (shops included, so shop rules apply to the sim too).
## Counters are read by the sim to print season lines and check the economy.

const SEED_RESERVE := 30  ## Coins kept back when buying seed.
const PLOT_COUNT := 18
const NO_CELL := Vector2i(-9999, -9999)
const GATHER_PER_DAY := 5
const SEED_SHOP := &"chandler"
const SMITH := &"blacksmith"
const SHEPHERD := &"shepherd"
const COIN_RESERVE := 150  ## Coins kept back when investing in tools and animals.
const SMALL_HERD := 7  ## The farmer stops buying animals at this herd size.
const FIRST_ANIMAL_DAY := 28  ## The farmer saves for a first animal from summer on.
const KEEP_RECIPE_INPUT := 8  ## Stock of anything a recipe uses that is not sold.

## The running level; the sim sets it again after every reload.
var level: Level
var plots: Array[Vector2i] = []
var reaped := 0
var products := 0
var sold_coins := 0
var quests := 0
var upgrades := 0
var animals_bought := 0
var first_upgrade_day := -1
var first_animal_day := -1
var sold_by_item: Dictionary = {}
var season_sales: Dictionary = {}


func find_plots() -> void:
	if not plots.is_empty():
		return  # keep the same plots after a reload (they are occupied by then)
	var farm := level.farm_grid
	for y in range(-12, -3):
		for x in range(5, 22):
			var cell := Vector2i(x, y)
			if plots.size() < PLOT_COUNT and farm.is_tool_valid(G.ToolKind.HOE, cell) \
					and not farm.is_occupied(cell):
				plots.append(cell)


func play_day() -> void:
	_reap_and_sow()
	_build_stations()
	run_stations()
	_tend_animals()
	_social_and_quests()
	_forage_and_chop()
	_sell_surplus()
	_invest()
	for crop in level.farm_grid.crop_field.crops():
		level.farm_grid.water(crop.cell)


## Collect and restart every station; the richest stations get scarce inputs first.
func run_stations() -> void:
	var works := level.get_node_or_null("Workstations") as Workstations
	if works == null:
		return
	var ordered := works.stations()
	ordered.sort_custom(func(a: Station, b: Station) -> bool:
		return _best_output(a.station_id) > _best_output(b.station_id))
	var reserved: Dictionary = {}  # inputs held back for a richer recipe that is short of them
	for station in ordered:
		station.collect()
		for recipe in Content.recipes_for_station(station.station_id):
			while station.can_start(recipe.id) and _free_of_reserve(recipe, reserved):
				station.start_job(recipe.id)
			for id: StringName in recipe.inputs:
				if not Inventory.has(id, int(recipe.inputs[id])) and Inventory.has(id, 1):
					reserved[id] = maxi(int(reserved.get(id, 0)), Inventory.count(id))


func _reap_and_sow() -> void:
	var field := level.farm_grid.crop_field
	for crop in field.ripe_crops():
		reaped += field.reap(crop.cell)
	var season := Calendar.season()
	var options: Array[CropData] = []
	for crop_row in Content.crops():
		if crop_row.grows_in(season):
			options.append(crop_row)
	if options.is_empty():
		return
	var pick := 0
	for cell in plots:
		if field.crop_at(cell) != null:
			continue
		for attempt in options.size():
			var row := options[(pick + attempt) % options.size()]
			if not Inventory.has(row.seed_item, 1) and Economy.coins > SEED_RESERVE:
				Economy.shop_buy(SEED_SHOP, StringName("item:%s" % row.seed_item))
			if Inventory.has(row.seed_item, 1):
				if not level.farm_grid.is_tilled(cell):
					level.farm_grid.till(cell)
				if field.sow(cell, row.id) != null:
					Inventory.remove(row.seed_item, 1)
					pick += 1
				break


func _free_of_reserve(recipe: RecipeData, reserved: Dictionary) -> bool:
	for id: StringName in recipe.inputs:
		if Inventory.count(id) - int(reserved.get(id, 0)) < int(recipe.inputs[id]):
			return false
	return true


## Highest base price among what a station can make (richest stations get inputs first).
func _best_output(station_id: StringName) -> int:
	var best := 0
	for recipe in Content.recipes_for_station(station_id):
		for id: StringName in recipe.outputs:
			best = maxi(best, Content.item(id).base_price)
	return best


func _tend_animals() -> void:
	var herd := level.get_node_or_null("Livestock") as Livestock
	if herd == null:
		return
	for animal in herd.animals():
		if animal.product_ready and animal.collect():
			products += 1
		if not Inventory.has(animal.data.feed_item, 1):
			Economy.shop_buy(SHEPHERD, StringName("item:%s" % animal.data.feed_item))
		animal.feed()
		animal.pet()


func _social_and_quests() -> void:
	for npc in Content.npcs():
		Relationships.talk(npc.id)
	for quest in Content.quests():
		if QuestManager.can_start(quest.id):
			QuestManager.start(quest.id)
		if QuestManager.is_active(quest.id) and QuestManager.is_ready(quest.id) \
				and QuestManager.complete(quest.id):
			quests += 1


## Gathers a few ripe nodes and fells one tree a day, as a diligent player would.
func _forage_and_chop() -> void:
	var foraging := level.get_node_or_null("Foraging") as Foraging
	var picked := 0
	if foraging != null:
		for node in foraging.nodes():
			if picked < GATHER_PER_DAY and node.is_ripe() and node.gather():
				picked += 1
	for grove in level.find_children("*", "TreeGrove", true, false):
		for tree in (grove as TreeGrove).trees():
			if not tree.felled:
				tree.fell()
				return


## Builds each missing station as soon as its materials are in the pack, on free ground
## near the starter yard (a diligent player extends the yard).
func _build_stations() -> void:
	var works := level.get_node_or_null("Workstations") as Workstations
	if works == null:
		return
	var present: Dictionary = {}
	for station in works.stations():
		present[station.station_id] = true
	for row in Content.stations():
		if present.has(row.id) or not works.can_afford_build(row.id):
			continue
		var cell := _free_cell(works)
		if cell != NO_CELL and works.build(row.id, cell) != null:
			return  # one build a day


func _free_cell(works: Workstations) -> Vector2i:
	var best := NO_CELL
	var best_dist := 1 << 30
	var grid := level.farm_grid
	for cell in grid.ground_layer.get_used_cells():
		if (cell.x + cell.y) % 3 != 0 or cell in plots or not grid.is_buildable(cell):
			continue
		var dist := (cell - works.anchor_cell).length_squared()
		if dist < best_dist and works.station_at(cell) == null:
			best = cell
			best_dist = dist
	return best


## At most one purchase a day: a tool upgrade first, from summer an animal (cheapest first).
func _invest() -> void:
	var wares: Array[Dictionary] = []
	wares.append_array(Content.shop(SMITH).wares)
	var herd := level.get_node_or_null("Livestock") as Livestock
	if GameClock.day_index >= FIRST_ANIMAL_DAY and herd != null and herd.animals().size() < SMALL_HERD:
		var animal_wares := Content.shop(SHEPHERD).wares.filter(
				func(w: Dictionary) -> bool: return w["kind"] == &"animal")
		animal_wares.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return Economy.shop_buy_price(null, a) < Economy.shop_buy_price(null, b))
		wares.append_array(animal_wares)
	for ware in wares:
		var shop_id := SMITH if ware["kind"] == &"tool_upgrade" else SHEPHERD
		var shop := Content.shop(shop_id)
		if Economy.coins < Economy.shop_buy_price(shop, ware) + COIN_RESERVE:
			continue
		if Economy.shop_buy(shop_id, ware["id"]).is_empty():
			var today := GameClock.day_index + 1
			if ware["kind"] == &"tool_upgrade":
				upgrades += 1
				first_upgrade_day = first_upgrade_day if first_upgrade_day >= 0 else today
			else:
				animals_bought += 1
				first_animal_day = first_animal_day if first_animal_day >= 0 else today
			return


## Sell everything that is neither seed, tool, animal feed nor a stock of recipe input or
## building material.
func _sell_surplus() -> void:
	var feed: Array[StringName] = []
	for animal_row in Content.animals():
		feed.append(animal_row.feed_item)
	var materials := _build_materials()
	for i in Inventory.size():
		var id := Inventory.slot_id(i)
		if id == &"" or id in feed:
			continue
		var item := Content.item(id)
		if item == null or item.is_tool() or item.is_seed() or not item.is_sellable():
			continue
		var keep := KEEP_RECIPE_INPUT if not Content.recipes_using(id).is_empty() else 0
		var surplus := Inventory.count(id) - maxi(keep, materials.get(id, 0))
		var keeper := _best_keeper(item)
		if surplus > 0 and keeper != &"":
			var earned := Economy.shop_sell(keeper, id, surplus)
			sold_coins += earned
			sold_by_item[id] = int(sold_by_item.get(id, 0)) + earned
			season_sales[id] = int(season_sales.get(id, 0)) + earned


## Items (and amounts) that upgrades and stations consume; the farmer keeps a stock of them.
func _build_materials() -> Dictionary:
	var out: Dictionary = {}
	for tier in Content.tool_tiers():
		for id: StringName in tier.upgrade_items:
			out[id] = maxi(int(out.get(id, 0)), int(tier.upgrade_items[id]) * 2)
	for row in Content.stations():
		for id: StringName in row.build_cost:
			out[id] = maxi(int(out.get(id, 0)), int(row.build_cost[id]) * 2)
	return out


## The shop that pays most for `item` (the farmer walks to the right stall).
func _best_keeper(item: ItemData) -> StringName:
	var best: StringName = &""
	var best_price := 0
	for shop in Content.shops():
		var price := Economy.shop_sell_price(shop, item.id)
		if price > best_price:
			best_price = price
			best = shop.id
	return best

extends RefCounted
## Shop rows. Const-only; Content builds ShopData from them.
## Row keys: name, keeper (NPC id), sells (wares), buys (rules).
## Ware keys (one of item / animal / tool_upgrade / station names the thing sold):
##   item = item id, animal = animal id, tool_upgrade = G.ToolKind, station = station id
##   (a kit: its build materials), plus optional id (needed when two wares share a target),
##   label, price (coins; the fee for a conversion), stock (per day), seasons,
##   sowable (seed: only while its crop can be sown), unlock (Progress flag),
##   requires ({item: n} consumed per purchase), amount (units per purchase).
## Prices left out come from the item / animal / tool tier row, never from here.
## Buy rules: cats (G.ItemCategory), tags, ids, factor (x base price, default 1.0).

const C := G.ItemCategory
const K := G.ToolKind
const PREMIUM := 1.2

const ROWS: Dictionary = {
	&"chandler": {name = "Chandler's Stall", keeper = &"chandler",
		sells = [
			{item = &"wheat_seed", stock = 30, sowable = true},
			{item = &"barley_seed", stock = 30, sowable = true},
			{item = &"pea_seed", stock = 20, sowable = true},
			{item = &"bean_seed", stock = 20, sowable = true},
			{item = &"flax_seed", stock = 15, sowable = true},
			{item = &"cabbage_seed", stock = 15, sowable = true},
		],
		buys = [{cats = [C.CROP, C.ANIMAL_PRODUCT, C.FORAGE, C.FISH, C.INGREDIENT, C.GOOD]}]},
	&"blacksmith": {name = "Smithy", keeper = &"blacksmith",
		sells = [
			{tool_upgrade = K.AXE}, {tool_upgrade = K.HOE}, {tool_upgrade = K.WATERING_CAN},
			{tool_upgrade = K.SICKLE}, {tool_upgrade = K.FISHING_ROD},
		]},
	&"alewife": {name = "Alehouse", keeper = &"alewife",
		sells = [{item = &"barm", stock = 10}, {item = &"ale", stock = 6}],
		buys = [{ids = [&"ale", &"barley", &"malt"], factor = PREMIUM}]},
	&"miller": {name = "The Mill", keeper = &"miller",
		sells = [
			{item = &"flour", price = 26, stock = 12},
			{id = &"mill_grain", item = &"flour", label = "Mill my grain", price = 2,
				requires = {&"grain": 1}},
		],
		buys = [{ids = [&"grain", &"wheat_sheaf", &"bread"]}]},
	&"shepherd": {name = "Shepherd's Fold", keeper = &"shepherd",
		sells = [{animal = &"cow", stock = 1}, {animal = &"sheep", stock = 2},
			{animal = &"chicken", stock = 3}],
		buys = [{ids = [&"fleece", &"milk", &"cheese", &"butter"], factor = PREMIUM}]},
}

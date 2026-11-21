extends RefCounted
## Non-tool item rows: harvest, animal products, gathered materials, forage, fish,
## intermediates and finished goods. Same row keys as items_tools.gd.

const P := preload("res://data/paths.gd")
const C := G.ItemCategory

const ROWS: Dictionary = {
	# --- Crop yields ---
	&"wheat_sheaf": {name = "Wheat Sheaf", desc = "Thresh it for grain and straw.", cat = C.CROP,
		price = 4, icon = P.ICONS + "wheat.png", tags = [&"grain"]},
	&"barley": {name = "Barley", desc = "Malt it for brewing.", cat = C.CROP, price = 4,
		icon = P.PLACEHOLDER + "barley.png", tags = [&"grain"]},
	&"peas": {name = "Peas", desc = "Pottage fare.", cat = C.CROP, price = 8,
		icon = P.PLACEHOLDER + "peas.png", tags = [&"pulse"]},
	&"beans": {name = "Beans", desc = "Hearty field beans.", cat = C.CROP, price = 9,
		icon = P.PLACEHOLDER + "beans.png", tags = [&"pulse"]},
	&"flax": {name = "Flax", desc = "Ret it to free the fibre.", cat = C.CROP, price = 4,
		icon = P.PLACEHOLDER + "flax.png"},
	&"cabbage": {name = "Cabbage", desc = "A fine garden cabbage.", cat = C.CROP, price = 20,
		icon = P.PLACEHOLDER + "cabbage.png", tags = [&"vegetable"]},
	# --- Animal products ---
	&"milk": {name = "Milk", desc = "Fresh from the cow.", cat = C.ANIMAL_PRODUCT, price = 3,
		icon = P.NA_ITEMS + "Potion/MilkPot.png"},
	&"fleece": {name = "Fleece", desc = "A whole shorn fleece.", cat = C.ANIMAL_PRODUCT,
		price = 14, icon = P.PLACEHOLDER + "fleece.png"},
	&"egg": {name = "Egg", desc = "Still warm.", cat = C.ANIMAL_PRODUCT, price = 2,
		icon = P.PLACEHOLDER + "egg.png"},
	# --- Gathered materials ---
	&"log": {name = "Log", desc = "Timber for building.", cat = C.MATERIAL, price = 3,
		icon = P.ICONS + "wood.png"},
	&"hazel_rod": {name = "Hazel Rod", desc = "Supple coppiced hazel.", cat = C.MATERIAL,
		price = 2, icon = P.NA_ITEMS + "Resource/Branch.png"},
	&"stone": {name = "Stone", desc = "Field stone.", cat = C.MATERIAL, price = 3,
		icon = P.NA_ITEMS + "Resource/Rock.png"},
	&"clay": {name = "Clay", desc = "Dug from the stream bank.", cat = C.MATERIAL, price = 3,
		icon = P.PLACEHOLDER + "clay.png"},
	&"reed": {name = "Reeds", desc = "For thatch and mats.", cat = C.MATERIAL, price = 1,
		icon = P.NA_ITEMS + "Resource/Grass.png"},
	# --- Forage and fish ---
	&"blackberry": {name = "Blackberries", desc = "From the hedgerow.", cat = C.FORAGE,
		price = 3, icon = P.PLACEHOLDER + "blackberry.png", tags = [&"fruit"]},
	&"hazelnut": {name = "Hazelnuts", desc = "From the coppice.", cat = C.FORAGE, price = 4,
		icon = P.NA_ITEMS + "Food/Nut.png"},
	&"apple": {name = "Apple", desc = "From the orchard.", cat = C.FORAGE, price = 4,
		icon = P.ICONS + "apple.png", tags = [&"fruit"]},
	&"trout": {name = "Trout", desc = "A brown trout from the stream.", cat = C.FISH,
		price = 14, icon = P.ICONS + "fish.png"},
	# --- Intermediates ---
	&"grain": {name = "Wheat Grain", desc = "Grind it to flour.", cat = C.INGREDIENT,
		price = 2, icon = P.NA_ITEMS + "Food/SeedLargeWhite.png", tags = [&"grain"]},
	&"straw": {name = "Straw", desc = "Fodder and bedding.", cat = C.INGREDIENT, price = 1,
		icon = P.ICONS + "straw.png", tags = [&"feed"]},
	&"flour": {name = "Flour", desc = "Bake it with barm.", cat = C.INGREDIENT, price = 6,
		icon = P.PLACEHOLDER + "flour.png"},
	&"malt": {name = "Malt", desc = "Sprouted, dried barley.", cat = C.INGREDIENT, price = 12,
		icon = P.PLACEHOLDER + "malt.png"},
	&"barm": {name = "Barm", desc = "Ale yeast; raises bread.", cat = C.INGREDIENT, price = 3,
		icon = P.PLACEHOLDER + "barm.png"},
	&"flax_fibre": {name = "Flax Fibre", desc = "Retted and scutched.", cat = C.INGREDIENT,
		price = 11, icon = P.PLACEHOLDER + "flax_fibre.png"},
	&"linen_thread": {name = "Linen Thread", desc = "Spun on the distaff.", cat = C.INGREDIENT,
		price = 7, icon = P.PLACEHOLDER + "linen_thread.png"},
	# --- Finished goods ---
	&"bread": {name = "Loaf", desc = "A good raised loaf.", cat = C.GOOD, price = 7,
		icon = P.PLACEHOLDER + "bread.png", tags = [&"food"]},
	&"butter": {name = "Butter", desc = "Churned and salted.", cat = C.GOOD, price = 18,
		icon = P.PLACEHOLDER + "butter.png", tags = [&"food"]},
	&"cheese": {name = "Cheese", desc = "Pressed overnight.", cat = C.GOOD, price = 30,
		icon = P.PLACEHOLDER + "cheese.png", tags = [&"food"]},
	&"ale": {name = "Ale", desc = "Unhopped English ale.", cat = C.GOOD, price = 12,
		icon = P.PLACEHOLDER + "ale.png", tags = [&"drink"]},
	&"linen": {name = "Linen Cloth", desc = "A bolt of fine linen.", cat = C.GOOD, price = 48,
		icon = P.PLACEHOLDER + "linen.png", tags = [&"cloth"]},
	# --- Upgrades ---
	&"linen_sack": {name = "Linen Sack", desc = "Use to carry 6 more items.", cat = C.UPGRADE,
		slots = 6, icon = P.NA_ITEMS + "Object/Bag.png"},
}

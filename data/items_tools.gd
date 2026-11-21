extends RefCounted
## Tool and seed item rows. Const-only; Content merges every items_*.gd ROWS table.
## Row keys: name, desc, cat (G.ItemCategory), price (0 = unsellable), icon,
## tool (G.ToolKind), tier (ToolTierData id), slots (backpack slots gained), tags.
## Tool ids are "<tool>_<tier>"; Content.tool_item(kind, tier) looks them up.

const P := preload("res://data/paths.gd")
const T := G.ItemCategory.TOOL
const S := G.ItemCategory.SEED

const ROWS: Dictionary = {
	# --- Tools: wooden tier ---
	&"axe_wooden": {name = "Wooden Axe", desc = "Fells trees and splits logs.", cat = T,
		tool = G.ToolKind.AXE, tier = &"wooden", icon = P.ICONS + "axe.png"},
	&"hoe_wooden": {name = "Wooden Hoe", desc = "Tills soil and pulls weeds.", cat = T,
		tool = G.ToolKind.HOE, tier = &"wooden", icon = P.ICONS + "hoe.png"},
	&"watering_can_wooden": {name = "Wooden Pail", desc = "Waters garden crops.", cat = T,
		tool = G.ToolKind.WATERING_CAN, tier = &"wooden", icon = P.ICONS + "water.png"},
	&"sickle_wooden": {name = "Flint Sickle", desc = "Reaps ripe crops.", cat = T,
		tool = G.ToolKind.SICKLE, tier = &"wooden", icon = P.ICONS + "sword.png"},
	&"fishing_rod_wooden": {name = "Hazel Rod", desc = "For fishing the stream.", cat = T,
		tool = G.ToolKind.FISHING_ROD, tier = &"wooden",
		icon = P.NA_ITEMS + "Weapons/Fishing Rod/Sprite.png"},
	# --- Tools: iron-shod tier ---
	&"axe_iron_shod": {name = "Iron-shod Axe", desc = "Bites deeper; fells in fewer blows.", cat = T,
		tool = G.ToolKind.AXE, tier = &"iron_shod", icon = P.NA_ITEMS + "Tool/Axe.png"},
	&"hoe_iron_shod": {name = "Iron-shod Hoe", desc = "Tills more ground per stroke.", cat = T,
		tool = G.ToolKind.HOE, tier = &"iron_shod", icon = P.NA_ITEMS + "Tool/Hoe.png"},
	&"watering_can_iron_shod": {name = "Iron-hooped Can", desc = "Waters more at once.", cat = T,
		tool = G.ToolKind.WATERING_CAN, tier = &"iron_shod",
		icon = P.NA_ITEMS + "Tool/WateringCan.png"},
	&"sickle_iron_shod": {name = "Iron Sickle", desc = "Reaps a wider sweep.", cat = T,
		tool = G.ToolKind.SICKLE, tier = &"iron_shod", icon = P.NA_ITEMS + "Tool/Sickle.png"},
	&"fishing_rod_iron_shod": {name = "Iron-hooked Rod", desc = "Fish bite sooner.", cat = T,
		tool = G.ToolKind.FISHING_ROD, tier = &"iron_shod",
		icon = P.PLACEHOLDER + "fishing_rod_iron_shod.png"},
	# --- Seeds (crop link lives on the crop row: CropData.seed_item) ---
	&"wheat_seed": {name = "Seed Wheat", desc = "Field crop. Rain-fed.", cat = S, price = 3,
		icon = P.NA_ITEMS + "Food/Seed1.png", tags = [&"field"]},
	&"barley_seed": {name = "Seed Barley", desc = "Field crop. Rain-fed.", cat = S, price = 3,
		icon = P.NA_ITEMS + "Food/Seed2.png", tags = [&"field"]},
	&"pea_seed": {name = "Seed Peas", desc = "Field crop. Rain-fed; crops again.", cat = S,
		price = 4, icon = P.NA_ITEMS + "Food/Seed3.png", tags = [&"field"]},
	&"bean_seed": {name = "Seed Beans", desc = "Field crop. Rain-fed; crops again.", cat = S,
		price = 4, icon = P.NA_ITEMS + "Food/SeedBig1.png", tags = [&"field"]},
	&"flax_seed": {name = "Linseed", desc = "Garden crop. Water daily.", cat = S, price = 6,
		icon = P.NA_ITEMS + "Food/SeedBig2.png", tags = [&"garden"]},
	&"cabbage_seed": {name = "Cabbage Seed", desc = "Garden crop. Water daily.", cat = S,
		price = 6, icon = P.NA_ITEMS + "Food/SeedBig3.png", tags = [&"garden"]},
}

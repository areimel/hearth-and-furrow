extends RefCounted
## Crop rows. Keys: name, kind (G.CropKind), seasons, seed, harvest (item), amount, days,
## regrow (0 = removed when reaped), storm, blight, sprite, frames.

const P := preload("res://data/paths.gd")
const SP := G.Season.SPRING
const SU := G.Season.SUMMER
const AU := G.Season.AUTUMN

const ROWS: Dictionary = {
	&"wheat": {name = "Wheat", kind = G.CropKind.FIELD, seasons = [SP, SU, AU],
		seed = &"wheat_seed", harvest = &"wheat_sheaf", amount = 2, days = 8,
		storm = true, blight = true, sprite = "res://graphics/plants/wheat.png"},
	&"barley": {name = "Barley", kind = G.CropKind.FIELD, seasons = [SP, SU],
		seed = &"barley_seed", harvest = &"barley", amount = 2, days = 7,
		storm = true, blight = true, sprite = P.PLACEHOLDER + "crop_barley.png"},
	&"peas": {name = "Peas", kind = G.CropKind.FIELD, seasons = [SP, SU],
		seed = &"pea_seed", harvest = &"peas", amount = 1, days = 6, regrow = 3,
		sprite = P.PLACEHOLDER + "crop_peas.png"},
	&"beans": {name = "Beans", kind = G.CropKind.FIELD, seasons = [SP, SU, AU],
		seed = &"bean_seed", harvest = &"beans", amount = 1, days = 7, regrow = 4,
		sprite = P.PLACEHOLDER + "crop_beans.png"},
	&"flax": {name = "Flax", kind = G.CropKind.GARDEN, seasons = [SP, SU],
		seed = &"flax_seed", harvest = &"flax", amount = 2, days = 7,
		sprite = P.PLACEHOLDER + "crop_flax.png"},
	&"cabbage": {name = "Cabbage", kind = G.CropKind.GARDEN, seasons = [SP, AU],
		seed = &"cabbage_seed", harvest = &"cabbage", amount = 1, days = 6,
		sprite = P.PLACEHOLDER + "crop_cabbage.png"},
}

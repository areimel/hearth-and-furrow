extends RefCounted
## Gathering node rows (world nodes that give raw materials by hand). Keys: name, verb
## (prompt), yields [{item, min, max, seasons?, from_day?}], regrow (days), tool
## (G.ToolKind, default none), blocks (movement), place (any_grass | near_water),
## count (scattered on a new game), full / empty (sprite paths).

const P := preload("res://data/paths.gd")
const S := G.Season

const ROWS: Dictionary = {
	&"hazel": {name = "Hazel Coppice", verb = "Cut hazel", regrow = 5, blocks = true,
		yields = [{item = &"hazel_rod", min = 2, max = 3},
			{item = &"hazelnut", min = 1, max = 3, seasons = [S.AUTUMN]}],
		place = &"any_grass", count = 5,
		full = P.PLACEHOLDER + "gather_hazel.png", empty = P.PLACEHOLDER + "gather_hazel_empty.png"},
	&"bramble": {name = "Bramble", verb = "Pick berries", regrow = 3, blocks = false,
		yields = [{item = &"blackberry", min = 2, max = 4, seasons = [S.SUMMER], from_day = 15},
			{item = &"blackberry", min = 2, max = 4, seasons = [S.AUTUMN]}],
		place = &"any_grass", count = 6,
		full = P.PLACEHOLDER + "gather_bramble.png", empty = P.PLACEHOLDER + "gather_bramble_empty.png"},
	&"stone": {name = "Stone Outcrop", verb = "Gather stone", regrow = 7, blocks = true,
		yields = [{item = &"stone", min = 1, max = 3}],
		place = &"any_grass", count = 5,
		full = P.PLACEHOLDER + "gather_stone.png", empty = P.PLACEHOLDER + "gather_stone_empty.png"},
	&"clay": {name = "Clay Pit", verb = "Dig clay", regrow = 7, blocks = false,
		yields = [{item = &"clay", min = 1, max = 3}],
		place = &"near_water", count = 3,
		full = P.PLACEHOLDER + "gather_clay.png", empty = P.PLACEHOLDER + "gather_clay_empty.png"},
	&"reeds": {name = "Reed Bed", verb = "Cut reeds", regrow = 4, blocks = false,
		yields = [{item = &"reed", min = 2, max = 4}],
		place = &"near_water", count = 4,
		full = P.PLACEHOLDER + "gather_reed.png", empty = P.PLACEHOLDER + "gather_reed_empty.png"},
}

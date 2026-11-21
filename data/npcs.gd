extends RefCounted
## Villager rows (minimal; the NPC/friendship agents flesh these out).
## Keys: name, role, loved, liked, disliked (item ids), stock (item/animal ids sold),
## buys (buys sellable items), sprite, faceset, schedule: [{at, loc, days, seasons, rain}].

const P := preload("res://data/paths.gd")
const SAT := G.Weekday.SATURDAY

const ROWS: Dictionary = {
	&"reeve": {name = "Thomas Ashby", role = "Reeve",
		loved = [&"cheese"], liked = [&"bread", &"ale"], disliked = [&"reed"],
		sprite = P.NA_CHARS + "Noble/SpriteSheet.png", faceset = P.NA_CHARS + "Noble/Faceset.png",
		schedule = [{at = 6, loc = &"manor"}, {at = 9, loc = &"village_green"},
			{at = 18, loc = &"manor"}]},
	&"chandler": {name = "Joan Webbe", role = "Chandler", buys = true,
		stock = [&"wheat_seed", &"barley_seed", &"pea_seed", &"bean_seed", &"flax_seed",
			&"cabbage_seed"],
		loved = [&"linen"], liked = [&"egg", &"butter"], disliked = [&"stone"],
		sprite = P.NA_CHARS + "Villager/SpriteSheet.png",
		faceset = P.NA_CHARS + "Villager/Faceset.png",
		schedule = [{at = 6, loc = &"chandlery"}, {at = 8, loc = &"market_cross", days = [SAT]}]},
	&"blacksmith": {name = "Hal Smyth", role = "Blacksmith",
		loved = [&"ale"], liked = [&"bread", &"cheese"], disliked = [&"blackberry"],
		sprite = P.NA_CHARS + "Hunter/SpriteSheet.png", faceset = P.NA_CHARS + "Hunter/Faceset.png",
		schedule = [{at = 6, loc = &"smithy"}, {at = 19, loc = &"alehouse"}]},
	&"alewife": {name = "Margery Brewster", role = "Alewife", buys = true,
		stock = [&"ale", &"barm"],
		loved = [&"malt"], liked = [&"barley", &"apple"], disliked = [&"clay"],
		sprite = P.NA_CHARS + "Woman/SpriteSheet.png", faceset = P.NA_CHARS + "Woman/Faceset.png",
		schedule = [{at = 6, loc = &"alehouse"}]},
	&"miller": {name = "Ned Miller", role = "Miller", buys = true,
		stock = [&"flour"],
		loved = [&"bread"], liked = [&"wheat_sheaf", &"grain"], disliked = [&"fleece"],
		sprite = P.NA_CHARS + "Villager2/SpriteSheet.png",
		faceset = P.NA_CHARS + "Villager2/Faceset.png",
		schedule = [{at = 6, loc = &"mill"}, {at = 20, loc = &"alehouse"}]},
	&"shepherd": {name = "Old Wat", role = "Shepherd",
		stock = [&"chicken", &"sheep", &"cow"],
		loved = [&"butter"], liked = [&"hazelnut", &"apple"], disliked = [&"ale"],
		sprite = P.NA_CHARS + "OldMan2/SpriteSheet.png",
		faceset = P.NA_CHARS + "OldMan2/Faceset.png",
		schedule = [{at = 6, loc = &"pasture"}, {at = 6, loc = &"shepherd_hut", rain = true}]},
}

extends RefCounted
## Villager rows. Keys: name, role, loved, liked, disliked (item ids), stock (item/animal
## ids sold), buys (buys sellable items), sprite, faceset, schedule: [{at, loc, days,
## seasons, rain}]. Dialogue lives in data/dialogue*.gd under the same npc id.
##
## Schedule rules (see NPCData.location_at): the matching entry with the latest `at` <= now
## wins, and `rain` entries are looked at first on wet days. Weekday entries therefore list
## their days explicitly (WEEK, SAT, SUN) so the three day types never mix.

const P := preload("res://data/paths.gd")
const WEEK: Array[int] = [G.Weekday.MONDAY, G.Weekday.TUESDAY, G.Weekday.WEDNESDAY,
	G.Weekday.THURSDAY, G.Weekday.FRIDAY]
const SAT: Array[int] = [G.Weekday.SATURDAY]
const SUN: Array[int] = [G.Weekday.SUNDAY]

const ROWS: Dictionary = {
	&"reeve": {name = "Thomas Ashby", role = "Reeve",
		loved = [&"butter", &"cheese"], liked = [&"bread", &"peas"], disliked = [&"reed"],
		sprite = P.NA_CHARS + "Noble/SpriteSheet.png", faceset = P.NA_CHARS + "Noble/Faceset.png",
		schedule = [
			{at = 6, loc = &"manor", days = WEEK}, {at = 8, loc = &"village_green", days = WEEK},
			{at = 13, loc = &"manor", days = WEEK}, {at = 17, loc = &"alehouse", days = WEEK},
			{at = 20, loc = &"manor", days = WEEK},
			{at = 6, loc = &"manor", days = SAT}, {at = 8, loc = &"market_cross", days = SAT},
			{at = 16, loc = &"alehouse", days = SAT}, {at = 20, loc = &"manor", days = SAT},
			{at = 6, loc = &"manor", days = SUN}, {at = 10, loc = &"village_green", days = SUN},
			{at = 17, loc = &"manor", days = SUN},
			{at = 6, loc = &"manor", rain = true}]},
	&"chandler": {name = "Joan Webbe", role = "Chandler", buys = true,
		stock = [&"wheat_seed", &"barley_seed", &"pea_seed", &"bean_seed", &"flax_seed",
			&"cabbage_seed"],
		loved = [&"linen"], liked = [&"flax_fibre", &"linen_thread", &"egg"],
		disliked = [&"stone"],
		sprite = P.NA_CHARS + "Woman/SpriteSheet.png", faceset = P.NA_CHARS + "Woman/Faceset.png",
		schedule = [
			{at = 6, loc = &"chandlery", days = WEEK}, {at = 12, loc = &"village_green", days = WEEK},
			{at = 13, loc = &"chandlery", days = WEEK}, {at = 18, loc = &"alehouse", days = WEEK},
			{at = 20, loc = &"chandlery", days = WEEK},
			{at = 6, loc = &"chandlery", days = SAT}, {at = 8, loc = &"market_cross", days = SAT},
			{at = 16, loc = &"chandlery", days = SAT}, {at = 19, loc = &"alehouse", days = SAT},
			{at = 21, loc = &"chandlery", days = SAT},
			{at = 6, loc = &"chandlery", days = SUN}, {at = 10, loc = &"village_green", days = SUN},
			{at = 15, loc = &"chandlery", days = SUN},
			{at = 6, loc = &"chandlery", rain = true}]},
	&"blacksmith": {name = "Hal Smyth", role = "Blacksmith",
		loved = [&"trout", &"cheese"], liked = [&"ale", &"bread"], disliked = [&"blackberry"],
		sprite = P.NA_CHARS + "Villager4/SpriteSheet.png",
		faceset = P.NA_CHARS + "Villager4/Faceset.png",
		schedule = [
			{at = 6, loc = &"smithy", days = WEEK}, {at = 12, loc = &"village_green", days = WEEK},
			{at = 13, loc = &"smithy", days = WEEK}, {at = 18, loc = &"alehouse", days = WEEK},
			{at = 21, loc = &"smithy", days = WEEK},
			{at = 6, loc = &"smithy", days = SAT}, {at = 9, loc = &"market_cross", days = SAT},
			{at = 14, loc = &"smithy", days = SAT}, {at = 18, loc = &"alehouse", days = SAT},
			{at = 21, loc = &"smithy", days = SAT},
			{at = 6, loc = &"smithy", days = SUN}, {at = 11, loc = &"village_green", days = SUN},
			{at = 17, loc = &"alehouse", days = SUN}, {at = 21, loc = &"smithy", days = SUN},
			{at = 6, loc = &"smithy", rain = true}]},
	&"alewife": {name = "Margery Brewster", role = "Alewife", buys = true,
		stock = [&"ale", &"barm"],
		loved = [&"ale", &"barley"], liked = [&"malt", &"apple", &"hazelnut"],
		disliked = [&"clay"],
		sprite = P.NA_CHARS + "Villager3/SpriteSheet.png",
		faceset = P.NA_CHARS + "Villager3/Faceset.png",
		schedule = [
			{at = 6, loc = &"alehouse", days = WEEK}, {at = 10, loc = &"village_green", days = WEEK},
			{at = 12, loc = &"alehouse", days = WEEK}, {at = 15, loc = &"chandlery", days = WEEK},
			{at = 17, loc = &"alehouse", days = WEEK},
			{at = 6, loc = &"alehouse", days = SAT}, {at = 8, loc = &"market_cross", days = SAT},
			{at = 15, loc = &"alehouse", days = SAT},
			{at = 6, loc = &"alehouse", days = SUN}, {at = 11, loc = &"village_green", days = SUN},
			{at = 14, loc = &"alehouse", days = SUN},
			{at = 6, loc = &"alehouse", rain = true}]},
	&"miller": {name = "Ned Miller", role = "Miller", buys = true,
		stock = [&"flour"],
		loved = [&"bread", &"grain"], liked = [&"wheat_sheaf", &"barley", &"ale"],
		disliked = [&"fleece"],
		sprite = P.NA_CHARS + "Master/SpriteSheet.png", faceset = P.NA_CHARS + "Master/Faceset.png",
		schedule = [
			{at = 6, loc = &"mill", days = WEEK}, {at = 12, loc = &"village_green", days = WEEK},
			{at = 13, loc = &"mill", days = WEEK}, {at = 19, loc = &"alehouse", days = WEEK},
			{at = 21, loc = &"mill", days = WEEK},
			{at = 6, loc = &"mill", days = SAT}, {at = 8, loc = &"market_cross", days = SAT},
			{at = 14, loc = &"mill", days = SAT}, {at = 19, loc = &"alehouse", days = SAT},
			{at = 21, loc = &"mill", days = SAT},
			{at = 6, loc = &"mill", days = SUN}, {at = 10, loc = &"village_green", days = SUN},
			{at = 16, loc = &"mill", days = SUN}, {at = 19, loc = &"alehouse", days = SUN},
			{at = 21, loc = &"mill", days = SUN},
			{at = 6, loc = &"mill", rain = true}]},
	&"shepherd": {name = "Old Wat", role = "Shepherd",
		stock = [&"chicken", &"sheep", &"cow"],
		loved = [&"cheese", &"fleece"], liked = [&"butter", &"hazelnut", &"apple"],
		disliked = [&"ale"],
		sprite = P.NA_CHARS + "OldMan/SpriteSheet.png", faceset = P.NA_CHARS + "OldMan/Faceset.png",
		schedule = [
			{at = 6, loc = &"pasture", days = WEEK}, {at = 12, loc = &"shepherd_hut", days = WEEK},
			{at = 13, loc = &"pasture", days = WEEK}, {at = 17, loc = &"alehouse", days = WEEK},
			{at = 19, loc = &"shepherd_hut", days = WEEK},
			{at = 6, loc = &"pasture", days = SAT}, {at = 9, loc = &"market_cross", days = SAT},
			{at = 13, loc = &"pasture", days = SAT}, {at = 17, loc = &"alehouse", days = SAT},
			{at = 19, loc = &"shepherd_hut", days = SAT},
			{at = 6, loc = &"shepherd_hut", days = SUN}, {at = 10, loc = &"village_green", days = SUN},
			{at = 14, loc = &"pasture", days = SUN}, {at = 18, loc = &"shepherd_hut", days = SUN},
			{at = 6, loc = &"shepherd_hut", rain = true}]},
}

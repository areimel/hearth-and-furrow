extends RefCounted
## Feast rows (minimal; the festival agent fleshes these out).
## Keys: name, desc, season (G.Season), day (1..28), loc, start, end, shops_closed.

const ROWS: Dictionary = {
	&"may_day": {name = "May Day", season = G.Season.SPRING, day = 20, loc = &"village_green",
		desc = "Maypole, garlands and dancing on the green."},
	&"harvest_home": {name = "Harvest Home", season = G.Season.AUTUMN, day = 7,
		loc = &"village_green", desc = "The last sheaf is in; a goose feast for all."},
}

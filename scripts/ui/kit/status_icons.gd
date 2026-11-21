class_name StatusIcons extends RefCounted
## Small drawn icons shared by the HUD and menus: seasons, weather, ticks and coins.
## Each is a PixelIcon bitmap tinted from UIPalette, so no art files are required.

const COIN := preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Items/Treasure/GoldCoin.png")

const _SPRING: PackedStringArray = [
	".........", ".gg...gg.", "gggg.gggg", ".ggg.ggg.", "..gggggg.", "....g....", "....g....", "..bbbbb..",
]
const _SUMMER: PackedStringArray = [
	"....y....", "..y.y.y..", "..yyyyy..", "...yyy...", "..y.y.y..", "..yyyyy..", "...yyy...", "....y....",
]
const _AUTUMN: PackedStringArray = [
	".......rr", ".....rrrr", "...rrrrrr", "..rroorr.", ".rrroorr.", ".rrrrrr..", "rrrrrr...", "r.rr.....",
]
const _WINTER: PackedStringArray = [
	"....f....", ".f..f..f.", "..f.f.f..", "...fff...", "fffffffff", "...fff...", "..f.f.f..", ".f..f..f.",
]
const _SUN: PackedStringArray = [
	".....y.....", ".y...y...y.", "..y.....y..", "....yyy....", "...yyyyy...", "y.yyyyyyy.y",
	"...yyyyy...", "....yyy....", "..y.....y..", ".y...y...y.", ".....y.....",
]
const _RAIN: PackedStringArray = [
	"...ccc.....", "..ccccc.cc.", ".ccccccccc.", "ccccccccccc", ".ccccccccc.",
	"..d..d..d..", ".d..d..d...", "..d..d..d..",
]
const _STORM: PackedStringArray = [
	"...sss.....", "..sssss.ss.", ".sssssssss.", "sssssssssss", ".sssssssss.",
	"....yyy....", ".....yy....", "......y....",
]
const _CHECK: PackedStringArray = [
	"......k", ".....kk", "k...kk.", ".k.kk..", "..kkk..", "...k...",
]
const _BOX: PackedStringArray = [
	"kkkkk", "k...k", "k...k", "k...k", "kkkkk",
]


## Icon for a G.Season value.
static func season(season_value: int) -> Texture2D:
	var legend := {"g": UIPalette.MOSS, "b": UIPalette.WOOD, "y": UIPalette.GOLD,
		"r": UIPalette.RUST, "o": UIPalette.GOLD, "f": UIPalette.SKY}
	var rows: Array[PackedStringArray] = [_SPRING, _SUMMER, _AUTUMN, _WINTER]
	return PixelIcon.make("season%d" % season_value, rows[season_value], legend)


## Icon for a G.WeatherKind value.
static func weather(kind: int) -> Texture2D:
	var legend := {"y": UIPalette.GOLD, "c": UIPalette.SLATE, "d": UIPalette.SKY,
		"s": UIPalette.INK}
	match kind:
		G.WeatherKind.RAIN:
			return PixelIcon.make("rain", _RAIN, legend)
		G.WeatherKind.STORM:
			return PixelIcon.make("storm", _STORM, legend)
	return PixelIcon.make("sun", _SUN, legend)


## A tick (done) or an empty box (not done).
static func tick(done: bool) -> Texture2D:
	if done:
		return PixelIcon.make("tick_on", _CHECK, {"k": UIPalette.MOSS})
	return PixelIcon.make("tick_off", _BOX, {"k": UIPalette.INK_DISABLED})


## The coin icon used for purses and prices.
static func coin() -> Texture2D:
	return COIN

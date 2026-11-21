extends RefCounted
## Global tuning numbers. Const-only. Per-item / per-crop numbers live on their own rows,
## not here. Access as `Balance.X` after `const Balance := preload("res://data/balance.gd")`.

# --- World ---
const TILE_SIZE: int = 16
## Player walk speed in pixels per second.
const PLAYER_SPEED: float = 70.0
## Swings of an axe before an apple tree is felled.
const APPLE_TREE_HEALTH: int = 4

# --- Inventory ---
const HOTBAR_SLOTS: int = 10
const BACKPACK_SLOTS: int = 24
const BACKPACK_MAX_SLOTS: int = 36
const STACK_SIZE: int = 99
const TOOL_STACK_SIZE: int = 1

# --- Time ---
const DAY_START_HOUR: int = 6
## Hours past midnight count on: 24 = midnight, 26 = 2:00, when the player passes out.
const PASS_OUT_HOUR: int = 26
const TICK_MINUTES: int = 10
const REAL_SECONDS_PER_TICK: float = 7.0

# --- Calendar ---
const DAYS_PER_SEASON: int = 28
const SEASONS_PER_YEAR: int = 4
const DAYS_PER_WEEK: int = 7
const MARKET_WEEKDAY: int = G.Weekday.SATURDAY

# --- Weather: relative weights for tomorrow's weather, per season ---
const WEATHER_WEIGHTS: Dictionary = {
	G.Season.SPRING: {G.WeatherKind.CLEAR: 55, G.WeatherKind.RAIN: 38, G.WeatherKind.STORM: 7},
	G.Season.SUMMER: {G.WeatherKind.CLEAR: 65, G.WeatherKind.RAIN: 25, G.WeatherKind.STORM: 10},
	G.Season.AUTUMN: {G.WeatherKind.CLEAR: 50, G.WeatherKind.RAIN: 40, G.WeatherKind.STORM: 10},
	G.Season.WINTER: {G.WeatherKind.CLEAR: 60, G.WeatherKind.RAIN: 35, G.WeatherKind.STORM: 5},
}

# --- Crop risks ---
## Each weed on a crop tile removes this fraction of yield (yield never below 1).
const WEED_YIELD_PENALTY: float = 0.25
## A crop never carries more weeds than this.
const MAX_WEEDS: int = 3
## Chance per evening that an unripe crop gains a weed.
const WEED_DAILY_CHANCE: float = 0.15
## Item a storm-flattened crop gives when salvaged (1 unit).
const FLATTENED_SALVAGE_ITEM: StringName = &"straw"
## Upper bound on the share of storm-sensitive ripe crops a storm may flatten.
const STORM_MAX_LOSS: float = 0.4
## Blighted crops still yield this fraction (rounded up).
const BLIGHT_YIELD_FACTOR: float = 0.5

# --- Economy ---
const START_COINS: int = 100
## Sell prices are multiplied by this on market day (see Calendar.is_market_day()).
const MARKET_DAY_SELL_BONUS: float = 1.25

# --- Relationships ---
const MAX_HEARTS: int = 10
const POINTS_PER_HEART: int = 100
const TALK_POINTS: int = 20
const GIFT_POINTS: Dictionary = {
	G.GiftReaction.LOVED: 80,
	G.GiftReaction.LIKED: 45,
	G.GiftReaction.NEUTRAL: 20,
	G.GiftReaction.DISLIKED: -20,
}

# --- New game ---
## Hotbar loadout in slot order, then extra items. [item_id, count].
const START_LOADOUT: Array = [
	[&"hoe_wooden", 1],
	[&"watering_can_wooden", 1],
	[&"sickle_wooden", 1],
	[&"axe_wooden", 1],
	[&"fishing_rod_wooden", 1],
	[&"wheat_seed", 10],
	[&"cabbage_seed", 5],
]

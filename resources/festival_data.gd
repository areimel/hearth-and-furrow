class_name FestivalData extends Resource
## A one-day feast on a fixed calendar date, with a contribution table: `asks` say what
## the village hopes for, `tiers` what contributing earns. Dialogue for it lives in
## data/dialogue_feasts.gd under the same id.

## Unique festival id, e.g. &"may_day".
@export var id: StringName
@export var display_name: String
@export var description: String
## G.Season value.
@export var season: int = G.Season.SPRING
## Day of season, 1..Balance.DAYS_PER_SEASON.
@export var day: int = 1
## Place id where the feast is held (the feast table stands at its marker).
@export var location: StringName
## Hours (inclusive start, exclusive end) the feast runs.
@export var start_hour: int = 9
@export var end_hour: int = 18
## Shops are shut for the day.
@export var shops_closed: bool = true
## Almanack note: one or two plain sentences of history behind the feast.
@export var note: String
## Place whose child markers villagers gather on (falls back to `location`).
@export var gather_place: StringName
## Name prefix of those child markers, e.g. "spot_".
@export var spot_prefix: String = "spot_"
## Morning announcement on the day, e.g. "Today is May Day. ...".
@export var announce: String
## Reminder the day before.
@export var reminder: String
## What the feast table asks for: DELIVER_ITEM conditions whose `targets` are the
## accepted items and `amount` how many are wanted.
@export var asks: Array[QuestCondition] = []
## Reward tiers by items contributed, lowest first.
@export var tiers: Array[RewardTier] = []


## True while the feast runs at `hour`.
func is_running_at(hour: int) -> bool:
	return hour >= start_hour and hour < end_hour


## Sum of every ask's amount.
func total_asked() -> int:
	var total := 0
	for ask in asks:
		total += ask.amount
	return total


## Index of the highest tier reached with `count` items contributed, or -1.
func tier_index(count: int) -> int:
	var best := -1
	for i in tiers.size():
		if count >= tiers[i].min_count:
			best = i
	return best

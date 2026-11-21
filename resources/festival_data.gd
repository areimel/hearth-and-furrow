class_name FestivalData extends Resource
## A one-day feast on a fixed calendar date.

## Unique festival id, e.g. &"may_day".
@export var id: StringName
@export var display_name: String
@export var description: String
## G.Season value.
@export var season: int = G.Season.SPRING
## Day of season, 1..Balance.DAYS_PER_SEASON.
@export var day: int = 1
## Place id where the feast is held.
@export var location: StringName
## Hours (inclusive start, exclusive end) the feast runs.
@export var start_hour: int = 9
@export var end_hour: int = 18
## Shops are shut for the day.
@export var shops_closed: bool = true

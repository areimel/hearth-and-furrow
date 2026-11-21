class_name NPCScheduleEntry extends Resource
## "From start_hour, be at location" for the days the filters allow. Of the entries
## matching today, the one with the latest start_hour <= now wins; on rainy days
## rain_only entries are considered first.

## Hour (6..26) this entry takes effect.
@export var start_hour: int = 6
## Place id (a marker name in the world), e.g. &"smithy".
@export var location: StringName
## G.Weekday values this applies to; empty = every day.
@export var weekdays: Array[int] = []
## G.Season values this applies to; empty = every season.
@export var seasons: Array[int] = []
## Applies only when it is raining.
@export var rain_only: bool = false


func matches(weekday: int, season: int, raining: bool) -> bool:
	if rain_only and not raining:
		return false
	if not weekdays.is_empty() and not weekday in weekdays:
		return false
	return seasons.is_empty() or season in seasons

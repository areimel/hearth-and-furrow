extends Node
## Autoload `Calendar`: pure date arithmetic over GameClock.day_index (it stores no
## state, so it has no save section). Day index 0 = Lady Day: spring day 1, year 1,
## a Monday. Every query takes an optional day index; -1 means today.

## The new day is in a different season than the previous one.
signal season_changed(season: int)
## The new day is spring 1 of a new year.
signal year_changed(year: int)
## The new day is a feast day.
signal festival_day(festival: FestivalData)

const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const WEEKDAY_NAMES: Array[String] = [
	"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
]
const DAYS_PER_YEAR: int = Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR


func today() -> int:
	return GameClock.day_index


## G.Season of a day.
func season(day: int = -1) -> int:
	return floori(posmod(_d(day), DAYS_PER_YEAR) / float(Balance.DAYS_PER_SEASON))


## 1..DAYS_PER_SEASON.
func day_of_season(day: int = -1) -> int:
	return posmod(_d(day), Balance.DAYS_PER_SEASON) + 1


## 1-based year.
func year(day: int = -1) -> int:
	return floori(_d(day) / float(DAYS_PER_YEAR)) + 1


## G.Weekday of a day.
func weekday(day: int = -1) -> int:
	return posmod(_d(day), Balance.DAYS_PER_WEEK)


func is_market_day(day: int = -1) -> bool:
	return weekday(day) == Balance.MARKET_WEEKDAY


## Feast on that day, or null.
func festival_today(day: int = -1) -> FestivalData:
	return Content.festival_on(season(day), day_of_season(day))


## Day index for a date; season is G.Season, day_of_season 1-based, year 1-based.
func day_index_for(year_number: int, season_value: int, day_in_season: int) -> int:
	return (year_number - 1) * DAYS_PER_YEAR + season_value * Balance.DAYS_PER_SEASON \
		+ day_in_season - 1


func season_name(season_value: int) -> String:
	return SEASON_NAMES[season_value]


func weekday_name(weekday_value: int) -> String:
	return WEEKDAY_NAMES[weekday_value]


## e.g. "Monday, 1 Spring, Year 1".
func date_string(day: int = -1) -> String:
	return "%s, %d %s, Year %d" % [weekday_name(weekday(day)), day_of_season(day),
		season_name(season(day)), year(day)]


## Called by GameClock.advance_day() only. Emits the calendar signals for the new day.
func begin_day(day: int) -> void:
	if day > 0 and season(day) != season(day - 1):
		season_changed.emit(season(day))
		if season(day) == G.Season.SPRING:
			year_changed.emit(year(day))
	var feast := festival_today(day)
	if feast != null:
		festival_day.emit(feast)


func _d(day: int) -> int:
	return GameClock.day_index if day < 0 else day

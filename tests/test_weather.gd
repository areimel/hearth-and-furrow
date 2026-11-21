extends TestCase
## Weather rules: determinism, storm limits, honest forecast, wet spells, outlook, saving.

const YEARS := 4


func before_each() -> void:
	SaveManager.new_game()
	_seed(4242)


func _seed(world_seed: int) -> void:
	Weather.world_seed = world_seed
	Weather.set_today(Weather.roll_for_day(GameClock.day_index))
	Weather.set_forecast(Weather.roll_for_day(GameClock.day_index + 1))


func _days_in_years(years: int) -> int:
	return years * Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR


func test_rolls_are_deterministic_per_seed_and_day() -> void:
	var first: Array[int] = []
	for day in 200:
		first.append(Weather.roll_for_day(day))
	for day in 200:
		eq(Weather.roll_for_day(day), first[day], "same seed and day, day %d" % day)
	Weather.world_seed = 9
	var differs := false
	for day in 200:
		differs = differs or Weather.roll_for_day(day) != first[day]
	check(differs, "another seed gives another year")


func test_no_early_or_consecutive_storms_over_four_years() -> void:
	var storms := 0
	var previous := G.WeatherKind.CLEAR
	for day in _days_in_years(YEARS):
		var kind := Weather.roll_for_day(day)
		if kind == G.WeatherKind.STORM:
			storms += 1
			check(day >= Balance.STORM_FREE_DAYS, "no storm on day %d" % day)
			check(previous != G.WeatherKind.STORM, "no storm after a storm on day %d" % day)
		previous = kind
	check(storms > 0, "storms do happen")


func test_forecast_is_always_tomorrows_weather() -> void:
	GameClock.day_index = 0
	for i in _days_in_years(YEARS):
		var promised := Weather.forecast
		GameClock.advance_day()
		eq(Weather.today, promised, "day %d weather as forecast" % GameClock.day_index)
		eq(Weather.forecast, Weather.roll_for_day(GameClock.day_index + 1), "new forecast is the true roll")


func test_wet_spell_needs_three_wet_days_of_the_last_four() -> void:
	GameClock.day_index = 20
	Weather.from_dict({"today": G.WeatherKind.CLEAR, "forecast": G.WeatherKind.CLEAR, "world_seed": 1})
	check(not Weather.is_wet_spell(), "dry start")
	for kind: int in [G.WeatherKind.RAIN, G.WeatherKind.CLEAR, G.WeatherKind.RAIN]:
		Weather.set_forecast(kind)
		GameClock.advance_day()
	check(not Weather.is_wet_spell(), "two wet days of four")
	Weather.set_forecast(G.WeatherKind.STORM)
	GameClock.advance_day()
	check(Weather.is_wet_spell(), "rain, clear, rain, storm is a wet spell")
	for i in 2:
		Weather.set_forecast(G.WeatherKind.CLEAR)
		GameClock.advance_day()
	check(not Weather.is_wet_spell(), "dry days end it")


func test_outlook_matches_the_coming_days() -> void:
	var look := Weather.outlook()
	eq(look.size(), Balance.OUTLOOK_DAYS, "default length")
	eq(look[0], Weather.forecast, "tomorrow first")
	GameClock.advance_day()
	var tomorrow: int = look[1]
	eq(Weather.forecast, tomorrow, "day after tomorrow came true")
	eq(Weather.outlook(5).size(), 5, "custom length")
	Weather.set_forecast(G.WeatherKind.STORM)
	check(Weather.outlook_text().contains("storm"), "folk wording names a storm")
	Weather.set_forecast(G.WeatherKind.CLEAR)
	check(Weather.outlook_text() != "", "always some wording")


func test_storm_warning_the_morning_before() -> void:
	var warned: Array[int] = []
	Weather.storm_warning.connect(func(day: int) -> void: warned.append(day))
	var day := 0
	while Weather.roll_for_day(day + 2) != G.WeatherKind.STORM:
		day += 1
	GameClock.day_index = day
	_seed(4242)
	GameClock.advance_day()  # now day + 1; tomorrow (day + 2) is a storm
	eq(warned, [day + 2], "warned for the storm day")
	GameClock.advance_day()
	check(Weather.is_stormy(), "storm arrived as warned")


func test_save_round_trip_keeps_history() -> void:
	GameClock.day_index = 20
	for kind: int in [G.WeatherKind.RAIN, G.WeatherKind.RAIN, G.WeatherKind.STORM]:
		Weather.set_forecast(kind)
		GameClock.advance_day()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Weather.to_dict()))
	var wet := Weather.is_wet_spell()
	Weather.reset()
	Weather.from_dict(saved)
	eq(Weather.is_wet_spell(), wet, "wet spell survives")
	eq(Weather.today, G.WeatherKind.STORM, "today")
	Weather.from_dict({})
	check(not Weather.is_wet_spell(), "empty save is fine")

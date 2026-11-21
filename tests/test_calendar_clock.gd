extends TestCase
## Calendar arithmetic, GameClock ticking/day roll, Weather forecast hand-over.

var _seasons: Array[int] = []


func before_each() -> void:
	SaveManager.new_game()


func test_calendar_arithmetic() -> void:
	eq(Calendar.season(0), G.Season.SPRING, "day 0 spring")
	eq(Calendar.day_of_season(0), 1, "day 0 is spring 1")
	eq(Calendar.weekday(0), G.Weekday.MONDAY, "Lady Day is a Monday")
	eq(Calendar.day_of_season(27), 28, "day 27 is spring 28")
	eq(Calendar.season(28), G.Season.SUMMER, "day 28 next season")
	eq(Calendar.day_of_season(28), 1, "summer 1")
	eq(Calendar.season(111), G.Season.WINTER, "last day of year 1")
	eq(Calendar.year(111), 1, "still year 1")
	eq(Calendar.year(112), 2, "year rolls over")
	eq(Calendar.season(112), G.Season.SPRING, "back to spring")
	eq(Calendar.weekday(13), G.Weekday.SUNDAY, "weekday wraps")
	check(Calendar.is_market_day(5) and not Calendar.is_market_day(6), "market Saturday")
	eq(Calendar.day_index_for(2, G.Season.AUTUMN, 7), 112 + 56 + 6, "day_index_for")
	eq(Calendar.date_string(0), "Monday, 1 Spring, Year 1", "date string")
	eq(Calendar.festival_today(Calendar.day_index_for(1, G.Season.AUTUMN, 7)).id,
		&"harvest_home", "harvest home date")


func test_clock_is_inert_until_started() -> void:
	check(not GameClock.running, "not running at boot")
	GameClock._process(100.0)
	eq(GameClock.total_minutes(), 6 * 60, "no time passes while stopped")


func test_clock_ticks_and_passes_out() -> void:
	var hours: Array[int] = []
	GameClock.hour_passed.connect(func(h: int) -> void: hours.append(h))
	GameClock.start()
	GameClock._process(7.0 * 6)  # six ticks of 10 minutes
	eq(GameClock.time_string(), "7:00", "one hour later")
	eq(hours, [7] as Array[int], "hour_passed fired")
	GameClock.advance_minutes(24 * 60)
	eq(GameClock.hour, 26, "clamped at pass-out hour")
	eq(GameClock.time_string(), "2:00", "displayed wrapped")
	check(not GameClock.running, "stopped on pass out")


func test_advance_day_rolls_everything_over() -> void:
	var order: Array[String] = []
	GameClock.day_ending.connect(func(d: int) -> void: order.append("ending %d" % d))
	GameClock.day_passed.connect(func(d: int) -> void: order.append("passed %d" % d))
	Calendar.season_changed.connect(func(s: int) -> void: _seasons.append(s))
	Weather.set_forecast(G.WeatherKind.RAIN)
	Relationships.talk(&"reeve")
	GameClock.day_index = 27
	GameClock.advance_minutes(300)
	GameClock.advance_day()
	eq(order, ["ending 27", "passed 28"] as Array[String], "signal order")
	eq(GameClock.total_minutes(), 6 * 60, "morning again")
	eq(_seasons, [G.Season.SUMMER] as Array[int], "season_changed fired once")
	eq(Weather.today, G.WeatherKind.RAIN, "yesterday's forecast came true")
	check(Weather.is_raining(), "raining")
	check(not Relationships.talked_today(&"reeve"), "daily talk reset")


func test_weather_rolls_are_deterministic() -> void:
	var a := Weather.roll_for_day(40)
	check(a == Weather.roll_for_day(40), "same seed and day -> same weather")
	check(a in [G.WeatherKind.CLEAR, G.WeatherKind.RAIN, G.WeatherKind.STORM], "valid kind")

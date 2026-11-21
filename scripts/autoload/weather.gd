extends Node
## Autoload `Weather`: today's weather and tomorrow's forecast (G.WeatherKind).
## Forecasts are always right: tomorrow's `today` is today's `forecast`.
## Rolls are deterministic per (world_seed, day) using Balance.WEATHER_WEIGHTS.

## Fired when today or the forecast changes (new day, roll_next_day, set_*).
signal weather_changed(today: int, forecast: int)
## Fired when tomorrow is a storm: on the morning before (begin_day) or via set_forecast.
## `day` is the day index of the storm.
signal storm_warning(day: int)

const Balance := preload("res://data/balance.gd")

var today: int = G.WeatherKind.CLEAR
var forecast: int = G.WeatherKind.CLEAR
## Saved; fixes every future roll for this playthrough.
var world_seed: int = 0
## Kinds of the (up to WET_SPELL_WINDOW - 1) days before today, oldest first. Saved.
var _past: Array[int] = []


func _ready() -> void:
	SaveManager.register(&"weather", self)
	reset()


## Rain or storm: field crops and garden soil count as watered.
func is_raining() -> bool:
	return today == G.WeatherKind.RAIN or today == G.WeatherKind.STORM


## Today is a storm.
func is_stormy() -> bool:
	return today == G.WeatherKind.STORM


## True when rain or storm fell on at least Balance.WET_SPELL_DAYS of the last
## Balance.WET_SPELL_WINDOW days (today included): the damp weeks that breed blight.
func is_wet_spell() -> bool:
	var wet := 1 if is_raining() else 0
	for kind: int in _past:
		if kind != G.WeatherKind.CLEAR:
			wet += 1
	return wet >= Balance.WET_SPELL_DAYS


## The true weather of the next `days` days, tomorrow first (the forecast is always
## right, so this is the "three-day feeling" the almanack and the TV show).
func outlook(days: int = Balance.OUTLOOK_DAYS) -> Array[int]:
	var result: Array[int] = []
	for i in days:
		result.append(forecast if i == 0 else roll_for_day(GameClock.day_index + 1 + i))
	return result


## Folk-wisdom sentence for the outlook, e.g. "The shepherd's knee aches: a storm tomorrow."
func outlook_text(days: int = Balance.OUTLOOK_DAYS) -> String:
	var kinds := outlook(days)
	var rainy := 0
	for i in kinds.size():
		if kinds[i] == G.WeatherKind.STORM:
			var when := "tomorrow" if i == 0 else ("in %d days" % (i + 1))
			return "The shepherd's knee aches: a storm %s." % when
		if kinds[i] == G.WeatherKind.RAIN:
			rainy += 1
	if rainy >= 2:
		return "The air hangs damp; more wet days than dry ahead."
	if rainy == 1:
		return "A shower rides the wind; the rest looks fair."
	return "Swallows fly high: fair skies hold."


## Re-rolls tomorrow's forecast from the seed and returns it.
func roll_next_day() -> int:
	forecast = roll_for_day(GameClock.day_index + 1)
	weather_changed.emit(today, forecast)
	return forecast


## The weather a given day index will have (pure; no state change).
## Storms never fall in the first Balance.STORM_FREE_DAYS days or the day after a stormy roll.
func roll_for_day(day: int) -> int:
	var kind := _raw_roll(day)
	if kind == G.WeatherKind.STORM and (day < Balance.STORM_FREE_DAYS or _raw_roll(day - 1) == G.WeatherKind.STORM):
		return G.WeatherKind.RAIN
	return kind


func _raw_roll(day: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day])
	var weights: Dictionary = Balance.WEATHER_WEIGHTS[Calendar.season(day)]
	var total := 0
	for kind: int in weights:
		total += weights[kind]
	var pick := rng.randi_range(1, total)
	for kind: int in weights:
		pick -= weights[kind]
		if pick <= 0:
			return kind
	return G.WeatherKind.CLEAR


## Overrides today's weather (debug, festivals, scripted events).
func set_today(kind: int) -> void:
	today = kind
	weather_changed.emit(today, forecast)


## Overrides tomorrow's forecast.
func set_forecast(kind: int) -> void:
	forecast = kind
	weather_changed.emit(today, forecast)
	if kind == G.WeatherKind.STORM:
		storm_warning.emit(GameClock.day_index + 1)


## Called by GameClock.advance_day() only.
func begin_day(day: int) -> void:
	_past.append(today)
	while _past.size() > Balance.WET_SPELL_WINDOW - 1:
		_past.pop_front()
	today = forecast
	forecast = roll_for_day(day + 1)
	weather_changed.emit(today, forecast)
	if forecast == G.WeatherKind.STORM:
		storm_warning.emit(day + 1)


## New game: fresh seed, clear first day.
func reset() -> void:
	world_seed = randi()
	_past.clear()
	today = G.WeatherKind.CLEAR
	forecast = roll_for_day(GameClock.day_index + 1)
	weather_changed.emit(today, forecast)


func to_dict() -> Dictionary:
	return {"today": today, "forecast": forecast, "world_seed": world_seed, "past": _past.duplicate()}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", 0))
	today = int(data.get("today", G.WeatherKind.CLEAR))
	forecast = int(data.get("forecast", G.WeatherKind.CLEAR))
	_past.clear()
	for kind: Variant in data.get("past", []):
		_past.append(int(kind))
	weather_changed.emit(today, forecast)

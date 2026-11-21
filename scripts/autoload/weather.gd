extends Node
## Autoload `Weather`: today's weather and tomorrow's forecast (G.WeatherKind).
## Forecasts are always right: tomorrow's `today` is today's `forecast`.
## Rolls are deterministic per (world_seed, day) using Balance.WEATHER_WEIGHTS.

## Fired when today or the forecast changes (new day, roll_next_day, set_*).
signal weather_changed(today: int, forecast: int)

const Balance := preload("res://data/balance.gd")

var today: int = G.WeatherKind.CLEAR
var forecast: int = G.WeatherKind.CLEAR
## Saved; fixes every future roll for this playthrough.
var world_seed: int = 0


func _ready() -> void:
	SaveManager.register(&"weather", self)
	reset()


## Rain or storm: field crops and garden soil count as watered.
func is_raining() -> bool:
	return today == G.WeatherKind.RAIN or today == G.WeatherKind.STORM


func is_stormy() -> bool:
	return today == G.WeatherKind.STORM


## Re-rolls tomorrow's forecast from the seed and returns it.
func roll_next_day() -> int:
	forecast = roll_for_day(GameClock.day_index + 1)
	weather_changed.emit(today, forecast)
	return forecast


## The weather a given day index will have (pure; no state change).
func roll_for_day(day: int) -> int:
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


## Called by GameClock.advance_day() only.
func begin_day(day: int) -> void:
	today = forecast
	forecast = roll_for_day(day + 1)
	weather_changed.emit(today, forecast)


## New game: fresh seed, clear first day.
func reset() -> void:
	world_seed = randi()
	today = G.WeatherKind.CLEAR
	forecast = roll_for_day(GameClock.day_index + 1)
	weather_changed.emit(today, forecast)


func to_dict() -> Dictionary:
	return {"today": today, "forecast": forecast, "world_seed": world_seed}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", 0))
	today = int(data.get("today", G.WeatherKind.CLEAR))
	forecast = int(data.get("forecast", G.WeatherKind.CLEAR))
	weather_changed.emit(today, forecast)

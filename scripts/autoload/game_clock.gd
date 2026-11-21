extends Node
## Autoload `GameClock`: in-game time of day and the absolute day counter.
## Inert until start(): it never ticks or emits on its own at boot.
## Time runs from 6:00 to 26:00 (= 2:00 next morning); hours past 23 keep counting.
## advance_day() is the ONLY way a day ends; see docs/contracts.md "Day-end order".

## Every tick (Balance.TICK_MINUTES game minutes), after the time has changed.
signal minute_passed(hour: int, minute: int)
## When a new hour is reached (hour may be 24, 25, 26).
signal hour_passed(hour: int)
## Start of advance_day(), for the day that is finishing. Resolve overnight work here.
signal day_ending(day_index: int)
## End of advance_day(), after Calendar/Weather/Relationships rolled over.
signal day_passed(day_index: int)
## Clock reached Balance.PASS_OUT_HOUR and stopped. The day-end flow must respond by
## calling advance_day() (after any fade/teleport home).
signal passed_out
signal running_changed(running: bool)

const Balance := preload("res://data/balance.gd")

## Days since the game began; 0 = Lady Day (spring 1, year 1).
var day_index: int = 0
var hour: int = Balance.DAY_START_HOUR
var minute: int = 0
## Multiplier on real time (2.0 = twice as fast). 0 freezes like pause.
var time_scale: float = 1.0
## Ticking is enabled (start/stop). Read-only outside; use start()/stop().
var running: bool = false
## Temporarily frozen (menus, dialogue). Read-only outside; use set_paused().
var paused: bool = false
var _accum: float = 0.0


func _ready() -> void:
	SaveManager.register(&"clock", self)


func start() -> void:
	if not running:
		running = true
		running_changed.emit(true)


func stop() -> void:
	if running:
		running = false
		running_changed.emit(false)


func set_paused(value: bool) -> void:
	paused = value


func is_ticking() -> bool:
	return running and not paused and time_scale > 0.0


func _process(delta: float) -> void:
	if not is_ticking():
		return
	_accum += delta * time_scale
	while _accum >= Balance.REAL_SECONDS_PER_TICK and running:
		_accum -= Balance.REAL_SECONDS_PER_TICK
		advance_minutes(Balance.TICK_MINUTES)


## Moves time forward (works while stopped too; used by ticking, tests and sleeping
## jobs). Emits hour_passed per hour crossed, then minute_passed once. Stops at
## PASS_OUT_HOUR and emits passed_out.
func advance_minutes(amount: int) -> void:
	if amount <= 0:
		return
	var limit := Balance.PASS_OUT_HOUR * 60
	var before := total_minutes()
	var after := mini(before + amount, limit)
	hour = floori(after / 60.0)
	minute = after % 60
	for h in range(floori(before / 60.0) + 1, hour + 1):
		hour_passed.emit(h)
	minute_passed.emit(hour, minute)
	if after >= limit:
		stop()
		passed_out.emit()


## Ends the current day and starts the next at 6:00. Order is part of the contract:
## day_ending -> counters roll -> Calendar -> Weather -> Relationships -> day_passed
## -> SaveManager.autosave().
func advance_day() -> void:
	day_ending.emit(day_index)
	day_index += 1
	hour = Balance.DAY_START_HOUR
	minute = 0
	_accum = 0.0
	Calendar.begin_day(day_index)
	Weather.begin_day(day_index)
	Relationships.begin_day(day_index)
	day_passed.emit(day_index)
	SaveManager.autosave()


## Minutes since midnight of the current day (can exceed 1440 after midnight).
func total_minutes() -> int:
	return hour * 60 + minute


## 0.0 at 6:00 rising to 1.0 at 24:00 (clamped); handy for lighting and music.
func day_progress() -> float:
	var span := float((24 - Balance.DAY_START_HOUR) * 60)
	return clampf((total_minutes() - Balance.DAY_START_HOUR * 60) / span, 0.0, 1.0)


## "6:00", "13:40", "1:30" (hours past midnight wrap for display).
func time_string() -> String:
	return "%d:%02d" % [hour % 24, minute]


func reset() -> void:
	stop()
	day_index = 0
	hour = Balance.DAY_START_HOUR
	minute = 0
	_accum = 0.0


func to_dict() -> Dictionary:
	return {"day_index": day_index, "hour": hour, "minute": minute}


## Restores time but leaves the clock stopped; the game scene calls start().
func from_dict(data: Dictionary) -> void:
	reset()
	day_index = int(data.get("day_index", 0))
	hour = int(data.get("hour", Balance.DAY_START_HOUR))
	minute = int(data.get("minute", 0))

class_name HudClockCard extends PanelContainer
## Top-right card: time of day with today's weather icon, weekday + date + season name, and a
## marker on market days and feast days (a plain label, it opens nothing). Refreshes on signals only (clock tick, day
## rollover, weather change, load); there is no per-frame work.

var _time: Label
var _date: Label
var _weather: TextureRect
var _marker: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameClock.minute_passed.connect(func(_h: int, _m: int) -> void: refresh_time())
	GameClock.day_passed.connect(func(_d: int) -> void: refresh())
	Weather.weather_changed.connect(func(_t: int, _f: int) -> void: refresh())
	SaveManager.loaded.connect(func(_p: String) -> void: refresh())
	SaveManager.new_game_started.connect(refresh)
	refresh()


## Re-read every field from the autoloads.
func refresh() -> void:
	refresh_time()
	_date.text = "%s %d %s" % [Calendar.weekday_name(Calendar.weekday()).substr(0, 3),
			Calendar.day_of_season(), Calendar.season_name(Calendar.season())]
	_weather.texture = StatusIcons.weather(Weather.today)
	var feast := Calendar.festival_today()
	if feast:
		_marker.text = "Feast: " + feast.display_name
	elif Calendar.is_market_day():
		_marker.text = "Market day"
	else:
		_marker.text = ""
	_marker.visible = _marker.text != ""


## Update only the clock text (the 10-minute tick).
func refresh_time() -> void:
	_time.text = GameClock.time_string()


## The clock text, e.g. "13:40".
func time_text() -> String:
	return _time.text


## The date text, e.g. "Sat 13 Spring".
func date_text() -> String:
	return _date.text


## The weather icon currently shown.
func weather_texture() -> Texture2D:
	return _weather.texture


## Text of the marker line, empty when today is an ordinary day.
func marker_text() -> String:
	return _marker.text


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	_time = Label.new()
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weather = _icon()
	top.add_child(_time)
	top.add_child(_weather)
	column.add_child(top)
	_date = Label.new()
	column.add_child(_date)
	_marker = UIText.label("", &"AccentLabel")
	column.add_child(_marker)


func _icon() -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(11, 11)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

extends Control
## Temporary plain-text status (time, date, weather, coins, selected item) so the game is
## playable before the real HUD exists. Delete with scenes/ui/debug_hud.tscn then.

@onready var _time: Label = $Lines/Time
@onready var _date: Label = $Lines/Date
@onready var _weather: Label = $Lines/Weather
@onready var _coins: Label = $Lines/Coins
@onready var _selected: Label = $Lines/Selected


func _process(_delta: float) -> void:
	_time.text = GameClock.time_string()
	_date.text = Calendar.date_string()
	_weather.text = "%s (tomorrow %s)" % [_weather_name(Weather.today), _weather_name(Weather.forecast)]
	_coins.text = "%d coins" % Economy.coins
	var item := Inventory.selected_item()
	if item == null:
		_selected.text = "[%d] empty" % (Inventory.selected_hotbar_index + 1)
	else:
		var count := Inventory.slot_count(Inventory.selected_hotbar_index)
		_selected.text = "[%d] %s%s" % [Inventory.selected_hotbar_index + 1, item.display_name,
				"" if item.is_tool() else " x%d" % count]


func _weather_name(kind: int) -> String:
	return String(G.WeatherKind.keys()[kind]).capitalize()

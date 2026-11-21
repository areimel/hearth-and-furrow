class_name AlmanackPage extends FocusScroll
## The almanack proper: today's date and weather, tomorrow's forecast in folk wording,
## the season's calendar grid, the next feast and what can be sown now. A single scroll
## page (arrow keys scroll it when the text outgrows the window).

## Forecast wording per G.WeatherKind, as a country saying.
const SAYINGS: Dictionary = {
	G.WeatherKind.CLEAR: "Red sky at night: fair weather on the morrow.",
	G.WeatherKind.RAIN: "Cows lie down in the field: rain on the morrow.",
	G.WeatherKind.STORM: "Ring round the moon: a storm on the morrow.",
}
const WEATHER_NAMES: Dictionary = {
	G.WeatherKind.CLEAR: "Fair", G.WeatherKind.RAIN: "Rain", G.WeatherKind.STORM: "Storm",
}

var _date: Label
var _today: IconLabel
var _forecast: Label
var _feast: Label
var _grid: CalendarGrid
var _sow: HFlowContainer
var _sow_title: Label


func _init() -> void:
	super()
	scroll_keys = true


func _ready() -> void:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 3)
	add_child(page)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	page.add_child(top)
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 2)
	top.add_child(facts)
	_date = _text(facts, &"HeaderLabel")
	_today = IconLabel.new()
	facts.add_child(_today)
	_forecast = _text(facts)
	_feast = _text(facts)
	var calendar := VBoxContainer.new()
	calendar.add_theme_constant_override("separation", 1)
	top.add_child(calendar)
	_grid = CalendarGrid.new()
	calendar.add_child(_grid)
	_sow_title = _text(page, &"HeaderLabel")
	_sow_title.text = "To sow now"
	_sow = HFlowContainer.new()
	_sow.add_theme_constant_override("h_separation", 8)
	_sow.add_theme_constant_override("v_separation", 0)
	page.add_child(_sow)


## Re-read the calendar, weather and crops.
func refresh() -> void:
	_date.text = Calendar.date_string()
	_today.set_content(StatusIcons.weather(Weather.today), "Today: %s" % WEATHER_NAMES[Weather.today])
	_forecast.text = SAYINGS[Weather.forecast]
	var feast := next_feast()
	if feast.is_empty():
		_feast.text = "No feast is kept in this reckoning."
	else:
		var days: int = feast["days"]
		_feast.text = "Next feast: %s, %s." % [feast["festival"].display_name,
			"today" if days == 0 else "in %d day%s" % [days, "" if days == 1 else "s"]]
	_grid.show_season(Calendar.season(), Calendar.day_of_season())
	_fill_sow()


## The nearest feast on or after today as {festival: FestivalData, days: int}; empty if
## the content has none. A feast already past this year is counted into next year.
static func next_feast() -> Dictionary:
	var best: Dictionary = {}
	var today := Calendar.today()
	for festival in Content.festivals():
		var when := Calendar.day_index_for(Calendar.year(), festival.season, festival.day)
		if when < today:
			when = Calendar.day_index_for(Calendar.year() + 1, festival.season, festival.day)
		if best.is_empty() or when - today < best["days"]:
			best = {"festival": festival, "days": when - today}
	return best


## Crops that grow in the current season, in Content order.
static func sowable_crops() -> Array[CropData]:
	var out: Array[CropData] = []
	for crop in Content.crops():
		if crop.grows_in(Calendar.season()):
			out.append(crop)
	return out


func _fill_sow() -> void:
	for child in _sow.get_children():
		_sow.remove_child(child)
		child.queue_free()
	var crops := sowable_crops()
	if crops.is_empty():
		_chip("Nothing grows now; the ground rests.")
		return
	for crop in crops:
		var plot := "field" if crop.kind == G.CropKind.FIELD else "garden"
		_chip("%s (%s)" % [crop.display_name, plot])


func _chip(text: String) -> void:
	var label := Label.new()
	label.text = text
	_sow.add_child(label)


func _text(parent: Control, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label

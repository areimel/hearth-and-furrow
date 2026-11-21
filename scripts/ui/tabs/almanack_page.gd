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
var _advice: Label
var _feast: Label
var _asks: Label
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
	_advice = _text(facts, &"HintLabel")
	_feast = _text(facts)
	_asks = _text(facts, &"HintLabel")
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
	_forecast.text = "%s %s" % [SAYINGS[Weather.forecast], Weather.outlook_text()]
	_advice.text = _reeve_advice()
	_advice.visible = not _advice.text.is_empty()
	var feast := next_feast()
	_asks.text = ""
	if feast.is_empty():
		_feast.text = "No feast is kept in this reckoning."
	else:
		var days: int = feast["days"]
		var festival: FestivalData = feast["festival"]
		_feast.text = "Next feast: %s, %s." % [festival.display_name,
			"today" if days == 0 else "in %d day%s" % [days, "" if days == 1 else "s"]]
		_asks.text = festival.reminder if days == 1 else feast_asks(festival)
	_asks.visible = not _asks.text.is_empty()
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


## What a feast table hopes for, e.g. "Asked: Green boughs 6, Rushes to strew 6" ("" if nothing).
static func feast_asks(festival: FestivalData) -> String:
	var parts: Array[String] = []
	for ask in festival.asks:
		parts.append("%s %d" % [ask.text, ask.amount])
	return "Asked: " + ", ".join(parts) if not parts.is_empty() else ""


## Crops that grow in the current season, in Content order.
static func sowable_crops() -> Array[CropData]:
	var out: Array[CropData] = []
	for crop in Content.crops():
		if crop.grows_in(Calendar.season()):
			out.append(crop)
	return out


# The reeve's hint from the level's RiskSystem, "" when there is none (menu outside a level).
func _reeve_advice() -> String:
	var found := get_tree().root.find_children("*", "RiskSystem", true, false)
	return (found[0] as RiskSystem).advice() if not found.is_empty() else ""


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
	var label := UIText.label("", variation, 60)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

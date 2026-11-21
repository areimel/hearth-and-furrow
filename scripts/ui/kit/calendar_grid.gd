class_name CalendarGrid extends Control
## The 28 days of one season as a 7-column week grid (every season starts on a Monday).
## Today is boxed in gold, market days carry a green dot and feast days a red one, with
## a two-word legend underneath. Sizes follow the theme font so Large text still fits.

const WEEKDAY_ROWS := 4

var _season: int = 0
var _today: int = -1


## Show `season_value` (a G.Season); `today_day` is the day of season to box, or -1.
func show_season(season_value: int, today_day: int = -1) -> void:
	_season = season_value
	_today = today_day
	update_minimum_size()
	queue_redraw()


## Day-of-season numbers (1..28) that hold a feast in the shown season.
func feast_days() -> Array[int]:
	var out: Array[int] = []
	for day in Balance.DAYS_PER_SEASON:
		if Calendar.festival_today(_index(day + 1)) != null:
			out.append(day + 1)
	return out


func _get_minimum_size() -> Vector2:
	var cell := _cell()
	return Vector2(cell.x * Balance.DAYS_PER_WEEK, cell.y * (WEEKDAY_ROWS + 2) + 2)


func _draw() -> void:
	var font := get_theme_font(&"font", &"Label")
	var size_px := _font_size()
	var cell := _cell()
	for col in Balance.DAYS_PER_WEEK:
		var short := Calendar.weekday_name(col).substr(0, 2)
		_text(font, size_px, Vector2(col * cell.x, 0), cell, short, UIPalette.RUST)
	for day in Balance.DAYS_PER_SEASON:
		var origin := Vector2((day % Balance.DAYS_PER_WEEK) * cell.x, (1 + day / Balance.DAYS_PER_WEEK) * cell.y)
		_draw_day(font, size_px, origin, cell, day + 1)
	var legend_y := (WEEKDAY_ROWS + 1) * cell.y + 2
	_draw_legend(font, size_px, legend_y, cell)


func _draw_day(font: Font, size_px: int, origin: Vector2, cell: Vector2, day: int) -> void:
	var box := Rect2(origin + Vector2.ONE, cell - Vector2(2, 2))
	if day == _today:
		draw_rect(box, UIPalette.PARCHMENT_LIGHT)
		draw_rect(box, UIPalette.GOLD, false, 1.0)
	_text(font, size_px, origin, cell, str(day), UIPalette.INK)
	var index := _index(day)
	if Calendar.is_market_day(index):
		draw_rect(Rect2(origin + Vector2(3, cell.y - 3), Vector2(2, 2)), UIPalette.MOSS)
	if Calendar.festival_today(index) != null:
		draw_rect(Rect2(origin + Vector2(cell.x - 5, 2), Vector2(2, 2)), UIPalette.CRIMSON)


func _draw_legend(font: Font, size_px: int, y: float, cell: Vector2) -> void:
	draw_rect(Rect2(Vector2(2, y + cell.y * 0.5 - 1), Vector2(2, 2)), UIPalette.MOSS)
	_text(font, size_px, Vector2(6, y), Vector2(cell.x * 2.5, cell.y), "Market", UIPalette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var x := cell.x * 3.5
	draw_rect(Rect2(Vector2(x, y + cell.y * 0.5 - 1), Vector2(2, 2)), UIPalette.CRIMSON)
	_text(font, size_px, Vector2(x + 4, y), Vector2(cell.x * 2.5, cell.y), "Feast", UIPalette.INK, HORIZONTAL_ALIGNMENT_LEFT)


func _text(font: Font, size_px: int, origin: Vector2, cell: Vector2, text: String, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var baseline := origin.y + (cell.y + font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	draw_string(font, Vector2(origin.x, baseline), text, align, cell.x, size_px, color)


func _index(day: int) -> int:
	return Calendar.day_index_for(Calendar.year(), _season, day)


func _font_size() -> int:
	return get_theme_font_size(&"font_size", &"Label")


func _cell() -> Vector2:
	var size_px := _font_size()
	return Vector2(roundf(size_px * 1.6 + 3.0), size_px + 3)

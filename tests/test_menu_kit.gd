extends TestCase
## Kit pieces added for the HUD and menu: hearts, tab strip, option and slider rows,
## status icons.


func test_hearts_row_fills_the_requested_hearts() -> void:
	var row := HeartsRow.new()
	tree.root.add_child(row)
	row.set_hearts(3, 10)
	eq(row.get_child_count(), 10, "ten hearts")
	var full := (row.get_child(0) as TextureRect).texture
	check((row.get_child(2) as TextureRect).texture == full, "third is full")
	check((row.get_child(3) as TextureRect).texture != full, "fourth is empty")
	row.set_hearts(1, 5)
	eq(row.get_child_count(), 5, "shrunk to five")
	row.free()


func test_tab_strip_wraps_and_selects() -> void:
	var strip := TabStrip.new()
	tree.root.add_child(strip)
	strip.set_tabs(["A", "B", "C"])
	eq(strip.selected_index(), 0, "first selected")
	eq(strip.wrapped(0, -1), 2, "back wraps")
	eq(strip.wrapped(2, 1), 0, "forward wraps")
	strip.select(2)
	eq(strip.selected_index(), 2, "select")
	strip.free()


func test_option_row_cycles_and_reports() -> void:
	var row := OptionRow.new()
	tree.root.add_child(row)
	row.setup("Fullscreen", ["Off", "On"])
	var got: Array[int] = []
	row.option_changed.connect(func(i: int) -> void: got.append(i))
	row.button().pressed.emit()
	eq(row.selected(), 1, "advanced")
	row.button().pressed.emit()
	eq(row.selected(), 0, "wrapped")
	eq(got, [1, 0], "signals")
	row.select(1)
	eq(got.size(), 2, "select() is silent")
	row.free()


func test_slider_row_reports_value() -> void:
	var row := SliderRow.new()
	tree.root.add_child(row)
	row.setup("Music", 1.0)
	var got: Array[float] = []
	row.value_changed.connect(func(v: float) -> void: got.append(v))
	row.slider().value = 0.5
	eq(got, [0.5], "value reported")
	row.free()


func test_status_icons_are_distinct_per_state() -> void:
	check(StatusIcons.weather(G.WeatherKind.CLEAR) != StatusIcons.weather(G.WeatherKind.RAIN), "weather")
	check(StatusIcons.season(G.Season.SPRING) != StatusIcons.season(G.Season.WINTER), "season")
	check(StatusIcons.tick(true) != StatusIcons.tick(false), "tick")
	eq(StatusIcons.season(G.Season.AUTUMN), StatusIcons.season(G.Season.AUTUMN), "cached")

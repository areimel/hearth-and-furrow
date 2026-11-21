extends TestCase
## Day-end pipeline on a real level: one day per end_day(), pass-out path, rain wets soil.

var level: Level


func before_each() -> void:
	SaveManager.new_game()


func test_level_starts_clock() -> void:
	level = await spawn_level()
	check(GameClock.running, "clock running after level ready")
	await despawn_level()
	check(not GameClock.running, "clock stops when level leaves")


func test_end_day_advances_exactly_one_day() -> void:
	level = await spawn_level()
	var finished := [0]
	level.day_cycle.transition_finished.connect(func() -> void: finished[0] += 1)
	level.day_cycle.end_day()
	await tree.process_frame
	eq(GameClock.day_index, 1, "one day")
	eq(GameClock.hour, 6, "6:00")
	eq(finished[0], 1, "finished once")
	check(not level.day_cycle.busy, "not busy")
	check(GameClock.running, "clock restarted")
	await despawn_level()


func test_end_day_is_guarded_against_reentry() -> void:
	level = await spawn_level()
	level.day_cycle.fade_time = 0.05
	level.day_cycle.end_day()
	level.day_cycle.end_day()
	check(level.day_cycle.busy, "busy mid transition")
	check(DayCycle.is_transitioning(tree), "static helper agrees")
	await tree.create_timer(0.3).timeout
	eq(GameClock.day_index, 1, "second call ignored")
	await despawn_level()


func test_pass_out_moves_player_to_wake_point() -> void:
	level = await spawn_level()
	level.player.global_position = Vector2(0, 0)
	GameClock.advance_minutes(30 * 60)
	await tree.process_frame
	eq(GameClock.day_index, 1, "passed out into the next day")
	check(level.player.global_position.distance_to(level.day_cycle.wake_point.global_position) < 8.0, "woke at bed")
	check(GameClock.running, "clock running again")
	check(not level.player.input_locked, "input unlocked")
	await despawn_level()


func test_rain_wets_tilled_soil_on_new_morning() -> void:
	level = await spawn_level()
	var cell := Vector2i(40, 40)
	level.farm_grid.till(cell)
	Weather.set_forecast(G.WeatherKind.RAIN)
	level.day_cycle.end_day()
	await tree.process_frame
	check(Weather.is_raining(), "rain today")
	check(level.farm_grid.is_wet(cell), "soil wet in the morning")
	check(level.sky.is_raining(), "sky shows rain")
	Weather.set_forecast(G.WeatherKind.CLEAR)
	level.day_cycle.end_day()
	await tree.process_frame
	check(not level.farm_grid.is_wet(cell), "dry the next clear day")
	check(not level.sky.is_raining(), "sky clear")
	await despawn_level()


func test_pause_setting_governs_menus_but_not_the_transition() -> void:
	level = await spawn_level()
	var settings := GameSettings.instance(tree)
	var saved_autosave := settings.autosave
	settings.autosave = false
	var screen := UIScreen.new()
	level.add_child(screen)
	screen.open()
	settings.set_value(&"pause_in_menus", true)
	level._process(0.0)
	check(GameClock.paused, "open screen pauses time by default")
	settings.set_value(&"pause_in_menus", false)
	level._process(0.0)
	check(not GameClock.paused, "setting off: time keeps running behind a screen")
	level.day_cycle.busy = true
	level._process(0.0)
	check(GameClock.paused, "the day transition always pauses")
	level.day_cycle.busy = false
	settings.set_value(&"pause_in_menus", true)
	settings.autosave = saved_autosave
	screen.close()
	await despawn_level()


func test_debug_day_key_is_ignored_while_a_screen_is_open() -> void:
	level = await spawn_level()
	var screen := UIScreen.new()
	level.add_child(screen)
	screen.open()
	var key := InputEventAction.new()
	key.action = &"day_change"
	key.pressed = true
	level.day_cycle._unhandled_input(key)
	check(not level.day_cycle.busy, "no day change behind an open screen")
	screen.close()
	await despawn_level()

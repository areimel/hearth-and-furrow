extends TestCase
## Day-end pipeline on a real level: one day per end_day(), pass-out path, rain wets soil.

var level: Level


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)
	await tree.process_frame
	level.day_cycle.fade_time = 0.0
	level.day_cycle.hold_time = 0.0


func _despawn() -> void:
	level.free()
	await tree.process_frame


func test_level_starts_clock() -> void:
	await _spawn()
	check(GameClock.running, "clock running after level ready")
	await _despawn()
	check(not GameClock.running, "clock stops when level leaves")


func test_end_day_advances_exactly_one_day() -> void:
	await _spawn()
	var finished := [0]
	level.day_cycle.transition_finished.connect(func() -> void: finished[0] += 1)
	level.day_cycle.end_day()
	await tree.process_frame
	eq(GameClock.day_index, 1, "one day")
	eq(GameClock.hour, 6, "6:00")
	eq(finished[0], 1, "finished once")
	check(not level.day_cycle.busy, "not busy")
	check(GameClock.running, "clock restarted")
	await _despawn()


func test_end_day_is_guarded_against_reentry() -> void:
	await _spawn()
	level.day_cycle.fade_time = 0.05
	level.day_cycle.end_day()
	level.day_cycle.end_day()
	check(level.day_cycle.busy, "busy mid transition")
	check(DayCycle.is_transitioning(tree), "static helper agrees")
	await tree.create_timer(0.3).timeout
	eq(GameClock.day_index, 1, "second call ignored")
	await _despawn()


func test_pass_out_moves_player_to_wake_point() -> void:
	await _spawn()
	level.player.global_position = Vector2(0, 0)
	GameClock.advance_minutes(30 * 60)
	await tree.process_frame
	eq(GameClock.day_index, 1, "passed out into the next day")
	check(level.player.global_position.distance_to(level.day_cycle.wake_point.global_position) < 8.0, "woke at bed")
	check(GameClock.running, "clock running again")
	check(not level.player.input_locked, "input unlocked")
	await _despawn()


func test_rain_wets_tilled_soil_on_new_morning() -> void:
	await _spawn()
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
	await _despawn()

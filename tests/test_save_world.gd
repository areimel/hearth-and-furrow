extends TestCase
## Save/load through a real Level: every registered section survives a save, a reset and
## a load (into a live level and into a level that appears afterwards), the starter herd
## and yard never duplicate, and a late-registering provider still gets its section.

const TEMP_PATH := "user://test_save_world.json"
const PEN_CELL := Vector2i(12, -9)

var level: Level
var _saved_autosave: bool = false


class LateProvider extends RefCounted:
	var value: int = 0

	func to_dict() -> Dictionary:
		return {"value": value}

	func from_dict(data: Dictionary) -> void:
		value = int(data.get("value", 0))

	func reset() -> void:
		value = 0


func before_each() -> void:
	_saved_autosave = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	SaveManager.save_path = TEMP_PATH
	SaveManager.delete_save()
	SaveManager.new_game()


func _cleanup() -> void:
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.DEFAULT_PATH
	SaveManager.autosave_enabled = _saved_autosave
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)  # the root is busy while the runner starts
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	GameClock.stop()


func _despawn() -> void:
	level.free()
	level = null
	await tree.process_frame


func _herd() -> Livestock:
	return level.get_node("Livestock")


func _works() -> Workstations:
	return level.get_node("Workstations")


## Sow, brew, feed, befriend, quest and spend, with a few days passing.
func _play_some() -> void:
	var farm := level.farm_grid
	farm.till(PEN_CELL)
	farm.water(PEN_CELL)
	farm.crop_field.sow(PEN_CELL, &"wheat")
	Inventory.add(&"grain", 4)
	var quern: Station = null
	for station in _works().stations():
		if station.station_id == &"quern":
			quern = station
	check(quern != null and quern.start_job(&"grind_flour"), "quern job started")
	var cow: Animal = _herd().animals().filter(
			func(a: Animal) -> bool: return a.animal_id == &"cow")[0]
	Inventory.add(cow.data.feed_item, 1)
	check(cow.feed(), "cow fed")
	_herd().add_animal(&"chicken")
	Relationships.talk(&"miller")
	QuestManager.start(&"prologue")
	check(Economy.spend(35), "coins spent")
	Progress.set_flag(&"test_flag")
	GameClock.advance_day()
	GameClock.advance_day()
	GameClock.stop()


func test_round_trip_every_section_into_live_and_late_levels() -> void:
	await _spawn()
	_play_some()
	var before := SaveSnapshot.capture()
	var summary := SaveSnapshot.summary(level)
	eq(SaveManager.save_game(), OK, "save")
	check(before.has(&"farm") and before.has(&"livestock") and before.has(&"stations"),
			"scene-owned sections registered")
	# Into the same live level.
	SaveManager.new_game()
	eq(SaveManager.load_game(), OK, "load live")
	eq(SaveSnapshot.diff(before, SaveSnapshot.capture()), "", "live round trip")
	eq(SaveSnapshot.summary(level), summary, "observable state live")
	# Into a level that only exists after the load (the continue-from-title order).
	await _despawn()
	SaveManager.new_game()
	eq(SaveManager.load_game(), OK, "load before level")
	check(SaveManager.pending_keys().has(&"farm"), "farm section waits for its provider")
	await _spawn()
	eq(SaveManager.pending_keys().size(), 0, "every section delivered")
	eq(SaveSnapshot.diff(before, SaveSnapshot.capture()), "", "late level round trip")
	eq(SaveSnapshot.summary(level), summary, "observable state late")
	eq(level.farm_grid.crop_field.crops().size(), 1, "the sown crop is back")
	await _despawn()
	_cleanup()


func test_continue_does_not_duplicate_starters_and_new_game_does_not_load() -> void:
	await _spawn()
	var herd_size := _herd().animals().size()
	var yard_size := _works().stations().size()
	check(herd_size > 0 and yard_size > 0, "new game has a starter herd and yard")
	_herd().add_animal(&"chicken")
	SaveManager.save_game()
	await _despawn()
	SaveManager.new_game()
	eq(SaveManager.load_game(), OK, "load")
	await _spawn()
	eq(_herd().animals().size(), herd_size + 1, "saved herd only, no extra starters")
	eq(_works().stations().size(), yard_size, "saved yard only, no second yard")
	await _despawn()
	SaveManager.new_game()  # a new game while a save exists on disk
	await _spawn()
	eq(_herd().animals().size(), herd_size, "new game has the plain starter herd")
	eq(_works().stations().size(), yard_size, "new game has one yard")
	await _despawn()
	_cleanup()


func test_late_registering_provider_receives_its_section() -> void:
	var provider := LateProvider.new()
	SaveManager.register(&"late_test", provider)
	provider.value = 42
	SaveManager.save_game()
	SaveManager.unregister(&"late_test")
	eq(SaveManager.load_game(), OK, "load")
	check(SaveManager.pending_keys().has(&"late_test"), "kept while unclaimed")
	var late := LateProvider.new()
	SaveManager.register(&"late_test", late)
	eq(late.value, 42, "delivered on register")
	check(not SaveManager.pending_keys().has(&"late_test"), "delivered once")
	SaveManager.unregister(&"late_test")
	_cleanup()


func test_player_state_saves_the_highlighter() -> void:
	await _spawn()
	level.player.highlighter_on = true
	SaveManager.save_game()
	level.player.highlighter_on = false
	SaveManager.load_game()
	check(level.player.highlighter_on, "highlighter restored")
	SaveManager.new_game()
	check(not level.player.highlighter_on, "reset clears it")
	await _despawn()
	_cleanup()


func test_continue_restores_player_position_and_facing() -> void:
	await _spawn()
	var spawn := level.player.position
	level.player.position = spawn + Vector2(0, 24)
	level.player.animation_direction = Vector2.LEFT
	eq(SaveManager.save_game(), OK, "save")
	await _despawn()
	eq(SaveManager.load_game(), OK, "load")
	await _spawn()
	check(level.player.position.distance_to(spawn + Vector2(0, 24)) < 2.0, "position restored")
	eq(level.player.animation_direction, Vector2.LEFT, "facing restored")
	await _despawn()
	SaveManager.new_game()
	await _spawn()
	check(level.player.position.distance_to(spawn) < 2.0, "a new game keeps the spawn point")
	await _despawn()
	_cleanup()

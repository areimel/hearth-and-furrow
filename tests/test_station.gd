extends TestCase
## Station job lifecycle: start, tick, ready, collect, overnight, slots, locks, save.

var _made: Array[Station] = []


func before_each() -> void:
	SaveManager.new_game()


func _station(id: StringName) -> Station:
	var station := Station.create(id)
	tree.root.add_child.call_deferred(station)  # the root is busy while the runner starts
	await tree.process_frame
	_made.append(station)
	return station


func _done() -> void:
	for station in _made:
		station.free()
	_made.clear()


func test_prompt_says_open_then_collect() -> void:
	var quern := await _station(&"quern")
	var pad: Interactable = quern.get_node("Interactable")
	eq(pad.prompt_text, "Open " + quern.display_name(), "open prompt")
	quern.output = {&"flour": 1}
	quern.changed.emit()
	quern._update_visuals()
	eq(pad.prompt_text, "Collect", "collect prompt with output waiting")
	check(quern.collect(), "collected")
	eq(pad.prompt_text, "Open " + quern.display_name(), "back to open")
	_done()


func test_timed_job_consumes_ticks_and_collects() -> void:
	var quern := await _station(&"quern")
	Inventory.add(&"grain", 4)
	check(quern.start_job(&"grind_flour"), "starts with inputs")
	eq(Inventory.count(&"grain"), 2, "inputs consumed")
	check(quern.is_working() and not quern.has_output(), "working, no output yet")
	GameClock.advance_minutes(20)
	check(not quern.has_output(), "not ready after 20 of 30 min")
	var left: int = quern.jobs()[0]["minutes_left"]
	eq(left, 10, "minutes left")
	GameClock.advance_minutes(10)
	check(quern.has_output() and not quern.is_working(), "ready after 30 min")
	var flour := Inventory.count(&"flour")
	check(quern.collect(), "collect all")
	eq(Inventory.count(&"flour"), flour + 1, "flour collected")
	eq(Progress.count(&"crafted.flour"), 1, "crafted recorded")
	check(not quern.has_output(), "output cleared")
	_done()


func test_overnight_job_ignores_ticks_and_finishes_at_day_end() -> void:
	var vat := await _station(&"brewing_vat")
	Inventory.add(&"malt", 1)
	check(vat.start_job(&"brew_ale"), "starts")
	GameClock.advance_minutes(600)
	check(not vat.has_output(), "still brewing after ticks")
	GameClock.advance_day()
	check(vat.has_output(), "ready after day end")
	check(vat.collect(), "collect")
	eq(Inventory.count(&"ale"), 2, "ale")
	eq(Inventory.count(&"barm"), 1, "barm")
	_done()


func test_slot_limit_and_missing_inputs_refused() -> void:
	var quern := await _station(&"quern")
	Inventory.add(&"grain", 6)
	check(quern.start_job(&"grind_flour"), "first job")
	check(not quern.start_job(&"grind_flour"), "second refused: one slot")
	eq(Inventory.count(&"grain"), 4, "refused start consumes nothing")
	var other := await _station(&"quern")
	Inventory.remove(&"grain", 4)
	check(not other.start_job(&"grind_flour"), "no inputs refused")
	_done()


func test_wrong_station_refused() -> void:
	var churn := await _station(&"churn")
	Inventory.add(&"grain", 2)
	check(not churn.start_job(&"grind_flour"), "recipe belongs to another station")
	eq(Inventory.count(&"grain"), 2, "nothing consumed")
	_done()


func test_collect_leaves_leftovers_when_pack_full() -> void:
	var oven := await _station(&"bread_oven")
	oven.output = {&"bread": 5}
	for i in Inventory.size():
		Inventory.remove_at(i, Inventory.slot_count(i))
	for i in Inventory.size():
		Inventory.add(&"log", Content.item(&"log").stack_size)
	check(not oven.collect(), "nothing fits")
	eq(oven.output[&"bread"], 5, "output retained")
	_done()


func test_save_round_trip_mid_job() -> void:
	var churn := await _station(&"churn")
	Inventory.add(&"milk", 2)
	churn.start_job(&"churn_butter")
	GameClock.advance_minutes(20)
	var saved := churn.to_dict()
	var copy := await _station(&"churn")
	copy.from_dict(saved)
	var left: int = copy.jobs()[0]["minutes_left"]
	eq(left, 40, "remaining time restored")
	GameClock.advance_minutes(40)
	check(copy.has_output(), "restored job completes")
	_done()

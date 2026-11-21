extends TestCase
## Workstations on a real level: starter yard, build cost, removal and the save section.

var level: Level
var works: Workstations


func before_each() -> void:
	SaveManager.new_game()


func _spawn() -> void:
	level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(level)  # the root is busy while the runner starts
	await tree.process_frame
	works = level.get_node("Workstations")
	await tree.process_frame
	await tree.process_frame


func _despawn() -> void:
	level.free()
	await tree.process_frame


func test_starter_yard_places_the_starter_stations_on_dry_untilled_ground() -> void:
	await _spawn()
	eq(works.stations().size(), Balance.STARTER_STATIONS.size(), "one of each starter station")
	var seen: Dictionary = {}
	for station in works.stations():
		seen[station.station_id] = true
		check(not level.farm_grid.is_water(station.coord), "%s on water" % station.station_id)
		check(not level.farm_grid.is_tilled(station.coord), "%s on soil" % station.station_id)
		check(level.farm_grid.occupant(station.coord) == station, "%s claims its cell" % station.station_id)
		eq(station.get_parent(), level.stations(), "spawned into level.stations()")
	eq(seen.size(), Balance.STARTER_STATIONS.size(), "all ids distinct")
	await _despawn()


func test_build_pays_cost_and_remove_frees_cell() -> void:
	await _spawn()
	var cell := Vector2i(-3, -3)
	for c in 12:
		if level.farm_grid.is_free_for_placement(cell + Vector2i(c, 0)):
			cell += Vector2i(c, 0)
			break
	check(works.can_afford_build(&"churn") == Inventory.has(&"log", 4), "afford matches inventory")
	Inventory.add(&"log", 4)
	var logs := Inventory.count(&"log")
	var built := works.build(&"churn", cell)
	check(built != null, "built")
	eq(Inventory.count(&"log"), logs - 4, "cost paid")
	check(works.station_at(cell) == built, "station_at")
	check(works.remove(cell), "removed")
	await tree.process_frame
	check(works.station_at(cell) == null, "gone")
	check(not level.farm_grid.is_occupied(cell), "cell released")
	await _despawn()


func test_save_round_trip_restores_cells_and_jobs() -> void:
	await _spawn()
	var quern: Station
	for station in works.stations():
		if station.station_id == &"quern":
			quern = station
	Inventory.add(&"grain", 2)
	quern.start_job(&"grind_flour")
	var cell := quern.coord
	var saved := works.to_dict()
	works.from_dict(saved)
	eq(works.stations().size(), Balance.STARTER_STATIONS.size(), "same count")
	var again := works.station_at(cell)
	check(again != null and again.station_id == &"quern", "quern restored on its cell")
	check(again.is_working(), "job restored")
	works.reset()
	eq(works.stations().size(), Balance.STARTER_STATIONS.size(), "reset lays out a fresh yard")
	check(not works.station_at(cell).is_working(), "fresh yard is idle")
	await _despawn()

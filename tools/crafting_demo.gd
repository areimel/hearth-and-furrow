extends Node
## Throwaway demo for screenshots: the level with the starter yard and a crafting
## screen. Use with the harness, e.g.
##   godot --path . res://tools/screenshot.tscn -- --scene res://tools/crafting_demo.tscn \
##       --setup quern --size 1280x720 --name quern
## Setup steps: yard (world view of the stations), quern, vat (brewing vat mid-job).

var _level: Level
var _works: Workstations
var _screen: CraftingScreen


func _ready() -> void:
	SaveManager.new_game()
	_level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(_level)
	_works = load("res://scenes/world/workstations.tscn").instantiate()
	_level.add_child(_works)
	_screen = load("res://scenes/ui/crafting_screen.tscn").instantiate()
	_level.get_node("Overlay/CanvasLayer/Menus").add_child(_screen)
	var toasts: Node = load("res://scenes/ui/kit/toasts.tscn").instantiate()
	_level.get_node("Overlay/CanvasLayer/Menus").add_child(toasts)


## Move the player next to the yard so the camera shows the stations.
func yard() -> void:
	var cells: Array[Vector2i] = []
	for station in _works.stations():
		cells.append(station.coord)
	var middle := cells[cells.size() / 2]
	_level.player.position = Vector2(middle * 16) + Vector2(8, 40)
	for station in _works.stations().slice(0, 3):
		station.output = {&"bread": 2}
		station.call("_update_visuals")


## Crafting screen on the quern with a few ingredients in the pack.
func quern() -> void:
	Inventory.add(&"grain", 4)
	_open(&"quern")


## Crafting screen on the brewing vat while a brew is running.
func vat() -> void:
	Inventory.add(&"malt", 2)
	var station := _find(&"brewing_vat")
	station.start_job(&"brew_ale")
	_open(&"brewing_vat")


func _find(id: StringName) -> Station:
	for station in _works.stations():
		if station.station_id == id:
			return station
	return null


func _open(id: StringName) -> void:
	_screen.open_for(_find(id))



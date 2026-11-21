extends Node
## Screenshot demo: the level with workstations, the starter herd and scattered gathering
## nodes, camera zoomed out. Use with
##   tools/screenshot.tscn --scene res://tools/foraging_demo.tscn --frames 120
## Set the FORAGE_CENTER env var to "x,y" (cells) to look at another part of the map and
## FORAGE_ZOOM to change the zoom (default 0.55).


func _ready() -> void:
	var level: Level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(level)
	level.add_child(load("res://scenes/world/workstations.tscn").instantiate())
	level.add_child(load("res://scenes/world/livestock.tscn").instantiate())
	level.add_child(load("res://scenes/world/foraging.tscn").instantiate())
	var camera := level.player.get_node("Camera2D") as Camera2D
	var zoom := OS.get_environment("FORAGE_ZOOM")
	camera.zoom = Vector2.ONE * (float(zoom) if zoom != "" else 0.55)
	for side in ["left", "top", "right", "bottom"]:
		camera.set("limit_" + side, 100000 if side in ["right", "bottom"] else -100000)
	var center := OS.get_environment("FORAGE_CENTER")
	if center != "":
		var parts := center.split(",")
		level.player.position = Vector2(int(parts[0]), int(parts[1])) * 16

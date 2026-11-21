extends Node
## Screenshot demo: the level with the starter herd, player standing beside the pen.
## Use with tools/screenshot.tscn --scene res://tools/livestock_demo.tscn --frames 120

func _ready() -> void:
	var level: Level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(level)
	var live: Livestock = level.get_node("Livestock")
	await get_tree().create_timer(0.3).timeout
	level.player.position = live.pen_center() + Vector2(-60, 10)

extends Node
## Throwaway demo for screenshots: the level with build mode and tool-tier highlights.
##   godot --path . res://tools/screenshot.tscn -- --scene res://tools/build_demo.tscn \
##       --setup build_menu --size 1280x720 --name build_menu
## Setup steps: build_menu (build menu open), valid / invalid (placing a churn on a good / tilled
## target cell), remove (removal mode facing a station), iron_hoe (highlight on, iron hoe).

var _level: Level


func _ready() -> void:
	SaveManager.new_game()
	_level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(_level)
	var toasts: Node = load("res://scenes/ui/kit/toasts.tscn").instantiate()
	_level.get_node("Overlay/CanvasLayer/Menus").add_child(toasts)
	Inventory.add(&"log", 9)
	Inventory.add(&"stone", 9)
	Inventory.add(&"hazel_rod", 3)


## Build menu open, with materials for some stations.
func build_menu() -> void:
	_stand_before_free_run(&"hoe_wooden")
	_level.get_node("Overlay/CanvasLayer/Menus/BuildMenu").open_menu()


## Placing a churn on a valid cell.
func valid() -> void:
	_stand_before_free_run(&"hoe_wooden")
	_level.build_mode.start_placing(&"churn")


## Placing a churn where it cannot go (tilled soil).
func invalid() -> void:
	_stand_before_free_run(&"hoe_wooden")
	_level.farm_grid.till(_level.target_cell())
	_level.build_mode.start_placing(&"churn")


## Removal mode with the target on a station.
func remove() -> void:
	var station: Station = _level.get_node("Workstations").stations()[0]
	_level.player.position = Vector2((station.coord - Vector2i(1, 0)) * 16) + Vector2(8, 8)
	_level.player.animation_direction = Vector2.RIGHT
	_level.build_mode.start_removing()


## Iron-shod hoe with the highlighter on: two cells lit.
func iron_hoe() -> void:
	Inventory.add(&"hoe_iron_shod", 1)
	_stand_before_free_run(&"hoe_iron_shod")
	_level.player.highlighter_on = true


func _stand_before_free_run(hoe_id: StringName) -> void:
	var grid := _level.farm_grid
	for cell in grid.ground_layer.get_used_cells():
		if grid.is_tool_valid(G.ToolKind.HOE, cell + Vector2i(1, 0)) and grid.is_tool_valid(G.ToolKind.HOE, cell + Vector2i(2, 0)) \
				and grid.is_buildable(cell + Vector2i(1, 0)) and not grid.is_tilled(cell + Vector2i(3, 0)):
			_level.player.position = Vector2(cell * 16) + Vector2(8, 8)
			_level.player.animation_direction = Vector2.RIGHT
			break
	for i in Inventory.size():
		if Inventory.slot_id(i) == hoe_id:
			if i != 0:
				Inventory.swap(i, 0)
			Inventory.select_hotbar(0)
			return

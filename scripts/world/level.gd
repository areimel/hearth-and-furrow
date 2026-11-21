class_name Level extends Node2D
## World root and mediator. The player only emits signals; Level translates them
## into FarmGrid calls, owns the day transition and rain, and exposes the
## containers other systems spawn into. Find it with
## get_tree().get_first_node_in_group("Level").

signal update_hint_ui_keys

var _build_cell: Vector2i

const PLANT_SCENE := preload("res://scenes/objects/plant.tscn")
const PLANT_INFO_SCENE := preload("res://scenes/ui/plant_info.tscn")

@onready var farm_grid: FarmGrid = $FarmGrid
@onready var player: CharacterBody2D = $Objects/Player
@onready var day_cycle: DayCycle = $DayCycle
@onready var sky: WorldSky = $Sky
@onready var _preview: Sprite2D = $Overlay/PreviewMachineSprite2D
@onready var _plant_info_control: Control = $Overlay/CanvasLayer/PlantInfoControl


func _ready() -> void:
	add_to_group("Level")
	GameClock.day_passed.connect(_on_day_passed)
	GameClock.start()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if Input.get_connected_joypads().size() > 0:
		Data.ControllerConnected = true


func _exit_tree() -> void:
	GameClock.stop()


func _process(_delta: float) -> void:
	GameClock.set_paused(UIScreen.any_open(get_tree()) or day_cycle.busy)

	if Data.TARGET_HIGHLIGHTER:
		farm_grid.update_highlight(player.position, player.animation_direction, player.current_tool)
	else:
		farm_grid.clear_highlight()

	_preview.visible = player.current_state == Enum.State.BUILDING
	if player.animation_direction != Vector2.ZERO:
		_build_cell = farm_grid.get_target_grid(player.position, player.animation_direction)
		_preview.position = (Vector2i(_build_cell * Data.TILE_SIZE)
				+ Data.MACHINE_PREVIEW_TEXTURES[player.current_machine]["offset"])


# ---------------------------------------------------------------- accessors

func crops() -> Node2D:
	return $Objects/Crops


func animals() -> Node2D:
	return $Objects/Animals


func stations() -> Node2D:
	return $Objects/Stations


func npcs() -> Node2D:
	return $Objects/NPCs


func gatherables() -> Node2D:
	return $Objects/Gatherables


# ---------------------------------------------------------------- day cycle

func _on_day_passed(_day: int) -> void:
	for tree: Node in get_tree().get_nodes_in_group("Tree"):
		if [false, true].pick_random():
			continue
		tree.create_apple()  # 50% that the apple count stays the same


# ---------------------------------------------------------------- player actions

## Fire the tool animation only if the tool is valid on the targeted cell.
func _on_player_do_action(anim_tree: AnimationTree, property: StringName, tool: int, pos: Vector2, dir: Vector2) -> void:
	if farm_grid.is_tool_valid(tool, farm_grid.get_target_grid(pos, dir)):
		anim_tree.set(property, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_player_tool_use(tool: Enum.Tool, pos: Vector2, dir: Vector2) -> void:
	var cell := farm_grid.get_target_grid(pos, dir)
	if farm_grid.occupant(cell) is Placeable:
		return
	match tool:
		Enum.Tool.HOE:
			farm_grid.till(cell)
			if Weather.is_raining():
				farm_grid.water(cell)
		Enum.Tool.WATER:
			farm_grid.water(cell)
		Enum.Tool.FISH:
			player.start_fishing()
		Enum.Tool.SEED:
			_sow(cell)
		Enum.Tool.AXE:
			_swing(tool, pos, dir, 22.0)


func _sow(cell: Vector2i) -> void:
	var item: Enum.Item = Data.SEED_TO_ITEM[player.current_seed]
	if Data.ITEMS_AMOUNT[item] <= 0:
		return
	Data.ITEMS_AMOUNT[item] -= 1
	var plant_res := PlantResource.new()
	plant_res.setup(player.current_seed)
	var plant_info: PanelContainer = PLANT_INFO_SCENE.instantiate()
	plant_info.setup(plant_res)
	_plant_info_control.add(plant_info)
	var plant: StaticBody2D = PLANT_SCENE.instantiate()
	plant.setup(cell, crops(), plant_res, plant_info, _on_plant_gone, _on_plant_gone)
	farm_grid.occupy(cell, plant)


## Call hit(tool, dir) on every Axe_able object within reach in front of the player.
func _swing(tool: Enum.Tool, pos: Vector2, dir: Vector2, reach: float) -> void:
	for object: Node2D in get_tree().get_nodes_in_group("Axe_able"):
		var to_object := object.position - pos
		# dot > 0 means in front, closer to 1 means more aligned
		if to_object.length() < reach and dir.dot(to_object.normalized()) > 0.65:
			object.hit(tool, dir)


func _on_plant_gone(cell: Vector2i) -> void:
	farm_grid.release(cell)


func _on_player_diagnose() -> void:
	_plant_info_control.visible = not _plant_info_control.visible


# ---------------------------------------------------------------- build mode

func _on_player_build(curr_machine: int) -> void:
	if curr_machine == Enum.Machine.DELETE:
		var placed := farm_grid.occupant(_build_cell) as Placeable
		if placed:
			placed.remove()
		return
	if not farm_grid.is_free_for_placement(_build_cell):
		return
	var placeable: Placeable = Data.MACHINE_SCENE[curr_machine]["scene"].instantiate()
	placeable.setup(_build_cell, self, stations())


func _on_player_change_machine(curr_machine: int) -> void:
	_preview.texture = Data.MACHINE_PREVIEW_TEXTURES[curr_machine]["texture"]


func _on_joy_connection_changed(_device_id: int, connected: bool) -> void:
	update_hint_ui_keys.emit()
	Data.ControllerConnected = connected

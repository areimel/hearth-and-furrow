class_name Level extends Node2D
## World root and mediator. The player only emits signals; Level translates them
## into FarmGrid calls, owns the build-placement entry points, and exposes the
## containers other systems spawn into. Find it with
## get_tree().get_first_node_in_group("Level").

const Balance := preload("res://data/balance.gd")
const REACH: float = 22.0  ## How far an axe swing reaches, in pixels.
const PREVIEW_TINT := Color(1, 1, 1, 0.59)

@onready var farm_grid: FarmGrid = $FarmGrid
@onready var player: Player = $Objects/Player
@onready var day_cycle: DayCycle = $DayCycle
@onready var sky: WorldSky = $Sky
@onready var _preview: Sprite2D = $Overlay/PreviewMachineSprite2D
@onready var _prompt: Prompt = $Overlay/CanvasLayer/HUD/Prompt
@onready var _target_info: Label = $Overlay/CanvasLayer/HUD/TargetInfo


func _ready() -> void:
	add_to_group("Level")
	GameClock.start()
	player.interact_focus_changed.connect(_on_interact_focus_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	InputGlyphs.controller_connected = Input.get_connected_joypads().size() > 0


func _on_joy_connection_changed(_device_id: int, connected: bool) -> void:
	InputGlyphs.controller_connected = connected


func _exit_tree() -> void:
	GameClock.stop()


func _process(_delta: float) -> void:
	GameClock.set_paused(UIScreen.any_open(get_tree()) or day_cycle.busy)
	_update_target_readout()
	if _preview.visible:  # bottom-left aligned, like a placed Station's sprite
		_preview.position = Vector2(target_cell() * Balance.TILE_SIZE) \
				+ Vector2(0, Balance.TILE_SIZE - _preview.texture.get_size().y)


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


## True while the player is in build mode (always false until BuildMode exists).
func is_building() -> bool:
	return false


## The grid cell in front of the player.
func target_cell() -> Vector2i:
	return farm_grid.get_target_grid(player.position, player.animation_direction)


# ---------------------------------------------------------------- player actions

## Fire the tool animation only if the action is valid on at least one targeted cell.
func _on_player_do_action(anim_tree: AnimationTree, property: StringName, action: int, pos: Vector2, dir: Vector2) -> void:
	if action == PlayerActions.SOW and player.action_item == null:
		return
	for cell in _swing_cells(action, pos, dir):
		if farm_grid.is_tool_valid(action, cell):
			anim_tree.set(property, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			return


## Apply the swing to every cell its tool tier covers; cells where it is invalid are skipped.
func _on_player_tool_use(action: int, pos: Vector2, dir: Vector2) -> void:
	var tier := PlayerActions.tier_of(player.action_item)
	if action == G.ToolKind.AXE:
		_swing(action, pos, dir, REACH, tier)
		return
	for cell in _swing_cells(action, pos, dir):
		if not farm_grid.is_tool_valid(action, cell):
			continue
		match action:
			G.ToolKind.HOE:
				_hoe(cell)
			G.ToolKind.WATERING_CAN:
				farm_grid.water(cell)
			G.ToolKind.FISHING_ROD:
				player.start_fishing(tier.fishing_ease if tier else 1.0)
			G.ToolKind.SICKLE:
				farm_grid.crop_field.reap(cell)
			PlayerActions.SOW:
				_sow(cell)


## Cells the swing covers: the target cell plus, for area tools, the ones beyond it.
func _swing_cells(action: int, pos: Vector2, dir: Vector2) -> Array[Vector2i]:
	var cell := farm_grid.get_target_grid(pos, dir)
	return ToolArea.cells(action, PlayerActions.tier_of(player.action_item), cell, cell - farm_grid.cell_of(pos))


func _hoe(cell: Vector2i) -> void:
	var crop := farm_grid.crop_field.crop_at(cell)
	if crop:
		crop.clear_weeds()
		return
	farm_grid.till(cell)
	if Weather.is_raining():
		farm_grid.water(cell)


## Sow the crop of the seed the swing started with; consumes one seed.
func _sow(cell: Vector2i) -> void:
	var seed_item: ItemData = player.action_item
	var crop_data := Content.crop_for_seed(seed_item.id) if seed_item else null
	if crop_data == null or not farm_grid.is_tool_valid(PlayerActions.SOW, cell):
		return
	if Inventory.remove(seed_item.id, 1):
		farm_grid.crop_field.sow(cell, crop_data.id)


## Call hit(tool, dir, tier) on every Axe_able object within reach in front of the player.
func _swing(action: int, pos: Vector2, dir: Vector2, reach: float, tier: ToolTierData) -> void:
	for object: Node2D in get_tree().get_nodes_in_group("Axe_able"):
		var to_object := object.position - pos
		# dot > 0 means in front, closer to 1 means more aligned
		if to_object.length() < reach and dir.dot(to_object.normalized()) > 0.65:
			object.hit(action, dir, tier)


# ---------------------------------------------------------------- HUD feedback

func _on_interact_focus_changed(target: Interactable) -> void:
	if is_building():
		return  # BuildMode owns the prompt
	if target == null:
		_prompt.hide_prompt()
		return
	var text: Variant = target.get_meta(&"prompt_text", target.get_parent().get_meta(&"prompt_text", "Use"))
	_prompt.show_prompt(&"action", str(text))


## With the highlighter on: tint the target cell and describe the crop standing on it.
func _update_target_readout() -> void:
	var crop: Crop = null
	if player.highlighter_on and not is_building():
		var item := Inventory.selected_item()
		farm_grid.update_highlight(player.position, player.animation_direction,
				PlayerActions.for_item(item), PlayerActions.tier_of(item))
		crop = farm_grid.crop_field.crop_at(target_cell())
	elif not is_building():
		farm_grid.clear_highlight()
	_target_info.visible = crop != null
	if crop:
		_target_info.text = crop.info_text()


# ---------------------------------------------------------------- build placement
# Entry points for the build/placement system (stations, coops, ...): it picks a scene
# from the inventory, shows a preview, and places at the cell in front of the player.

## Whether a Placeable may be built on the cell in front of the player.
func can_place_at_target() -> bool:
	return farm_grid.is_buildable(target_cell())


## Instantiate `scene` (root must be a Placeable) on the target cell under stations().
## Returns the new Placeable, or null when the cell is not free.
func place_at_target(scene: PackedScene) -> Placeable:
	if not can_place_at_target():
		return null
	var placeable: Placeable = scene.instantiate()
	placeable.setup(target_cell(), self, stations())
	return placeable


## Show a `tint`ed (default half-transparent) `texture` on the target cell until
## hide_placement_preview(). Call again to change the tint, e.g. green/red for validity.
func show_placement_preview(texture: Texture2D, tint: Color = PREVIEW_TINT) -> void:
	_preview.texture = texture
	_preview.modulate = tint
	_preview.visible = true


func hide_placement_preview() -> void:
	_preview.visible = false

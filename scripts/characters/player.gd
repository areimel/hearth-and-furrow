class_name Player extends CharacterBody2D
## The farmer. Walks, animates and turns the selected hotbar item into an action
## (see PlayerActions). It never touches the world: it emits `do_action` (ask Level
## whether the action is valid and fire the animation) and `tool_use` (the animation's
## method track calls tool_use_emit() when the swing lands) and Level applies the effect.

enum State { DEFAULT, FISHING, HOUSE }

## The swing landed: apply `action` (G.ToolKind or PlayerActions.SOW) at the target cell.
signal tool_use(action: int, pos: Vector2, dir: Vector2)
## Action pressed: Level validates the target and fires the one-shot on `anim_tree`.
signal do_action(anim_tree: AnimationTree, property: StringName, action: int, pos: Vector2, dir: Vector2)
## The nearest Interactable in range changed (null = none).
signal interact_focus_changed(target: Interactable)

const Balance := preload("res://data/balance.gd")
const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_10",
]

var direction: Vector2
var can_move: bool = true
## Freezes all gameplay input (day transition, cutscenes). Menus are detected separately.
var input_locked: bool = false
var current_state: State = State.DEFAULT
## Facing, rounded to the 8 directions; the target cell is the player's cell plus this.
var animation_direction: Vector2 = Vector2(0, 1)
## Whether the green/red target highlight is shown.
var highlighter_on: bool = false
## The item whose action is in flight (a seed to sow, the tool swung); null when idle.
var action_item: ItemData

var _action: int = G.ToolKind.NONE
var _interactables: Array[Interactable] = []
var _focused: Interactable

@onready var _move_state_machine: AnimationNodeStateMachinePlayback = \
		$Animation/AnimationTree.get("parameters/StateMachine/playback")
@onready var _tool_state_machine: AnimationNodeStateMachinePlayback = \
		$Animation/AnimationTree.get("parameters/ToolStateMachine/playback")


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # No sliding/pushing
	_add_light()


func _physics_process(_delta: float) -> void:
	_update_interact_focus()
	if input_locked or UIScreen.any_open(get_tree()):
		velocity = Vector2.ZERO
		$Sounds/Step.stop()
		return
	match current_state:
		State.DEFAULT:
			if can_move:
				_hotbar_input()
				_default_input()
				_move()
				_animate()
		State.FISHING:
			if Input.is_action_just_pressed("action"):
				$FishingGame.apply_bar_boost()
		State.HOUSE:
			_hotbar_input()
			if Input.is_action_just_pressed("action"):
				_interact_with_nearest()
			_move()
			_animate()


## Called by the tool animation's method track when the swing lands.
func tool_use_emit() -> void:
	tool_use.emit(_action, position, animation_direction)
	var sound := get_node_or_null("Sounds/%s" % PlayerActions.SOUNDS.get(_action, &"")) as AudioStreamPlayer2D
	if sound:
		sound.play()


## Start the fishing minigame (Level calls this when a rod swing lands on water).
func start_fishing() -> void:
	$FishingGame.reveal()
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 1)
	current_state = State.FISHING


# ---------------------------------------------------------------- input

func _hotbar_input() -> void:
	if Input.is_action_just_pressed("tool_forward") or Input.is_action_just_pressed("tool_backward"):
		Inventory.cycle_hotbar(int(Input.get_axis("tool_backward", "tool_forward")))
	for i in HOTBAR_ACTIONS.size():
		if Input.is_action_just_pressed(HOTBAR_ACTIONS[i]):
			Inventory.select_hotbar(i)


func _default_input() -> void:
	if Input.is_action_just_pressed("action") and not _interact_with_nearest():
		_start_action(Inventory.selected_item())
	if Input.is_action_just_pressed("highlighter"):
		highlighter_on = not highlighter_on


func _start_action(item: ItemData) -> void:
	var action := PlayerActions.for_item(item)
	if action == G.ToolKind.NONE:
		return
	_action = action
	action_item = item
	_tool_state_machine.travel(PlayerActions.ANIMATIONS[action])
	do_action.emit($Animation/AnimationTree, "parameters/OneShot/request", action, position, animation_direction)


func _move() -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	velocity = direction * Balance.PLAYER_SPEED
	if direction:
		if not $Sounds/StepTimer.time_left:
			$Sounds/StepTimer.start()
	else:
		$Sounds/Step.stop()
	move_and_slide()


func _animate() -> void:
	var tree: AnimationTree = $Animation/AnimationTree
	if direction:
		_move_state_machine.travel("walk")
		animation_direction = Vector2(round(direction.x), round(direction.y))
		tree.set("parameters/StateMachine/idle/blend_position", animation_direction)
		tree.set("parameters/StateMachine/walk/blend_position", animation_direction)
		tree.set("parameters/FishIdleBlendSpace2D/blend_position", animation_direction)
		for animation: StringName in PlayerActions.ANIMATIONS.values():
			tree.set("parameters/ToolStateMachine/%s/blend_position" % animation, animation_direction)
	else:
		_move_state_machine.travel("idle")


# ---------------------------------------------------------------- animation and fishing signals

func _on_animation_tree_animation_started(_anim_name: StringName) -> void:
	can_move = false


func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
	can_move = true
	action_item = null


func _on_fishing_game_fish_game_finish(is_success: bool) -> void:
	if is_success:
		Loot.give(get_tree(), &"trout", 1, &"caught")
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 0)
	current_state = State.DEFAULT


func _on_step_timer_timeout() -> void:
	$Sounds/Step.play()


# ---------------------------------------------------------------- interaction

# Every Interactable in range is tracked; only the nearest is focused/used.
func _on_interact_range_area_entered(area: Area2D) -> void:
	if area is Interactable and area not in _interactables:
		_interactables.append(area)


func _on_interact_range_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_interactables.erase(area)
		area.focused = false


func _nearest_interactable() -> Interactable:
	var nearest: Interactable = null
	var best := INF
	for candidate in _interactables:
		if not is_instance_valid(candidate) or not candidate.enabled:
			continue
		var dist := global_position.distance_squared_to(candidate.global_position)
		if dist < best:
			best = dist
			nearest = candidate
	return nearest


func _update_interact_focus() -> void:
	_interactables.assign(_interactables.filter(is_instance_valid))
	var nearest := _nearest_interactable()
	for candidate in _interactables:
		candidate.focused = candidate == nearest
	if nearest != _focused:
		_focused = nearest
		interact_focus_changed.emit(nearest)


## Trigger the nearest interactable in range. Returns false if there is none.
func _interact_with_nearest() -> bool:
	var nearest := _nearest_interactable()
	if nearest == null:
		return false
	nearest.interact(self)
	return true


## Soft light around the player so the night is not pitch black.
func _add_light() -> void:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	for x in size:
		for y in size:
			var fade := 1.0 - Vector2(x - center, y - center).length() / center
			if fade > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 0.9, fade * fade))
	var light := PointLight2D.new()
	light.texture = ImageTexture.create_from_image(image)
	light.energy = 0.25
	light.texture_scale = 0.5
	add_child(light)

# TODO: Move while using tools 
extends CharacterBody2D

const SPEED: float = Data.PLAYER_SPEED
var direction: Vector2
var can_move: bool = true
## Set by DayCycle (and others) to freeze all gameplay input.
var input_locked: bool = false
@onready var move_state_machine = $Animation/AnimationTree.get("parameters/StateMachine/playback")

@onready var tool_state_machine = $Animation/AnimationTree.get("parameters/ToolStateMachine/playback")
var current_tool: Enum.Tool = Enum.Tool.AXE
var tools_count: int = Enum.Tool.size()

var current_seed: Enum.Seed = Enum.Seed.TOMATO
var seeds_count: int = Enum.Seed.size()

var current_state: Enum.State = Enum.State.DEFAULT

var current_machine: Enum.Machine = Enum.Machine.DELETE
var machine_count = Data.unlocked_machines.size()
var machine_index: int = 0
signal build(machine: Enum.Machine)
signal change_machine(machine: Enum.Machine)

var animation_direction: Vector2 = Vector2(0, 1)
signal tool_use(tool: Enum.Tool, pos: Vector2, dir: Vector2)
signal do_action(anim_tree: AnimationTree, property: StringName, tool: Enum.Tool, pos: Vector2, dir: Vector2)

signal diagnose

var _interactables: Array[Interactable] = []

signal update_control_ui(key_enum: Enum.KEYBOARD, currentItem: Enum)

var update_state: Enum.State = Enum.State.HOUSE;


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # No sliding/pushing
	var player_light: PointLight2D = PointLight2D.new()
	$".".add_child(player_light)
	
	# Create smooth faded circle texture
	var size = 256
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fill with transparent
	
	var center = size / 2.0
	var max_radius = size / 2.0
	
	for x in size:
		for y in size:
			var dx = x - center
			var dy = y - center
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance <= max_radius:
				# Calculate alpha: 1.0 at center, 0.0 at edge
				var alpha = 1.0 - (distance / max_radius)
				# Square it for smoother fade
				alpha = alpha * alpha
				
				# Set pixel color with alpha
				var color = Color(1.0, 1.0, 0.9, alpha)
				image.set_pixel(x, y, color)
	
	# Create texture and apply
	var texture = ImageTexture.create_from_image(image)
	player_light.texture = texture
	player_light.energy = 0.25
	player_light.texture_scale = 0.5


func _physics_process(_delta: float) -> void:
	_update_interact_focus()
	if update_state != current_state:
		if current_state == Enum.State.BUILDING:
			update_control_ui.emit(Enum.KEYBOARD.CHANGE_MODE, current_state, Enum.State.BUILDING)		
		else:
			update_control_ui.emit(Enum.KEYBOARD.CHANGE_MODE, current_state)		
			
		update_state = current_state
		
	if input_locked or UIScreen.any_open(get_tree()):
		velocity = Vector2.ZERO
		$Sounds/Step.stop()
		return
	match current_state:
		Enum.State.DEFAULT:
			if can_move:
				get_basic_input()
				move()
				animate()
		
		Enum.State.FISHING:
			get_fishing_input()
		
		Enum.State.BUILDING:
			get_fishing_input()
			get_building_input()
			move()
			animate()
			
		Enum.State.HOUSE:
			get_house_input()
			move()
			animate()
				
	
func move():
	direction = Input.get_vector("left", "right", "up", "down")
	velocity = direction * SPEED
	
	if direction:
		if not $Sounds/StepTimer.time_left:
			$Sounds/StepTimer.start()
	else:
		$Sounds/Step.stop()
		
	
	move_and_slide()
	
	
func get_basic_input():
	# Switch seeds
	if Input.is_action_just_pressed("seed_forward"):
		current_seed = posmod((current_seed + 1), seeds_count) as Enum.Seed
		$ToolUI.reveal(null, current_seed)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_SEED, current_seed)
		
	# Switch tools
	if Input.is_action_just_pressed("tool_forward") or Input.is_action_just_pressed("tool_backward"):
		var dir = Input.get_axis("tool_backward", "tool_forward") # -1, 1
		current_tool = posmod((current_tool + int(dir)), tools_count) as Enum.Tool
		$ToolUI.reveal(current_tool, null)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_TOOL, current_tool)

	if Input.is_action_just_pressed("action"):
		if not _interact_with_nearest():
			tool_state_machine.travel(Data.TOOL_STATE_ANIMATIONS[current_tool])
			do_action.emit($Animation/AnimationTree, "parameters/OneShot/request", current_tool, position, animation_direction)
			#$Animation/AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	if Input.is_action_just_pressed("highlighter"):
		Data.TARGET_HIGHLIGHTER = not Data.TARGET_HIGHLIGHTER 
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_HIGHLIGHT, 1 if Data.TARGET_HIGHLIGHTER else 0)

	if Input.is_action_just_pressed("diagnose"):
		diagnose.emit()
		
	if Input.is_action_just_pressed("build"):
		current_state = Enum.State.BUILDING
		change_machine.emit(current_machine)
		Data.TARGET_HIGHLIGHTER = false
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_HIGHLIGHT, 0)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_MACHINE, current_machine, Enum.State.BUILDING)
		
		

func get_fishing_input():
	if Input.is_action_just_pressed("action"):
		$FishingGame.apply_bar_boost()


func get_building_input():
	if Input.is_action_just_pressed("build"):
		current_state = Enum.State.DEFAULT
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_TOOL, current_tool)
		
	
	# Switch Machines
	if Input.is_action_just_pressed("tool_forward") or Input.is_action_just_pressed("tool_backward"):
		var dir = Input.get_axis("tool_backward", "tool_forward") # -1, 1
		machine_count = Data.unlocked_machines.size()
		machine_index = posmod((machine_index + int(dir)), machine_count) as Enum.Machine
		current_machine = Data.unlocked_machines[machine_index] as Enum.Machine 
		change_machine.emit(current_machine)
		update_control_ui.emit(Enum.KEYBOARD.CHANGE_MACHINE, current_machine, Enum.State.BUILDING)
		
			
	if Input.is_action_just_pressed("action"):
		build.emit(current_machine)


func get_house_input():
	if Input.is_action_just_pressed("diagnose"):
		diagnose.emit()
		
	if Input.is_action_just_pressed("action"):
		_interact_with_nearest()


func animate():
	if direction:
		move_state_machine.travel("walk")
		animation_direction = Vector2(round(direction.x), round(direction.y))
		$Animation/AnimationTree.set("parameters/StateMachine/idle/blend_position", animation_direction)	
		$Animation/AnimationTree.set("parameters/StateMachine/walk/blend_position", animation_direction)
		$Animation/AnimationTree.set("parameters/FishIdleBlendSpace2D/blend_position", animation_direction)	
		
		# Update tools animation
		for tool_animation in Data.TOOL_STATE_ANIMATIONS.values():
			$Animation/AnimationTree.set("parameters/ToolStateMachine/" + tool_animation + "/blend_position", animation_direction)		
	else:
		move_state_machine.travel("idle")
	
		
func tool_use_emit():
	tool_use.emit(current_tool, position, animation_direction)
	if current_tool == Enum.Tool.AXE or current_tool == Enum.Tool.SWORD:
		$Sounds/Axe.play()
	elif current_tool == Enum.Tool.FISH:
		$Sounds/Fish.play()
	elif current_tool == Enum.Tool.HOE:
		$Sounds/Hoe.play()	
	elif current_tool == Enum.Tool.WATER:
		$Sounds/Water.play()	


func _on_animation_tree_animation_started(_anim_name: StringName) -> void:
	can_move = false


func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
	can_move = true


# Fishing Part
func start_fishing():
	$FishingGame.reveal()
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 1)
	current_state = Enum.State.FISHING


func _on_fishing_game_fish_game_finish(is_success: bool) -> void:
	if is_success:
		Data.ITEMS_AMOUNT[Enum.Item.FISH] += 1
	$Animation/AnimationTree.set("parameters/FishBlend/blend_amount", 0)
	current_state = Enum.State.DEFAULT



# Interaction: every Interactable in range is tracked; only the nearest is focused/used.
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


## Trigger the nearest interactable in range. Returns false if there is none.
func _interact_with_nearest() -> bool:
	var nearest := _nearest_interactable()
	if nearest == null:
		return false
	nearest.interact(self)
	return true


func _on_step_timer_timeout() -> void:
	$Sounds/Step.play()

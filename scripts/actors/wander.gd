class_name Wander extends RefCounted
## Grazing behaviour for an Animal: idle a while, pick a random point within
## `home_radius` of `home`, walk there (stopping for obstacles, water and the player), animate the
## sprite sheet while walking. Animal calls tick() from its _physics_process.

const SPEED := 14.0
const PLAYER_STOP_DISTANCE := 20.0
const FRAME_TIME := 0.25

var _body: Animal
var _sprite: Sprite2D
var _wandering: bool = false
var _wait: float = 1.0
var _target: Vector2 = Vector2.ZERO
var _walk_time: float = 0.0


func _init(body: Animal, sprite: Sprite2D) -> void:
	_body = body
	_sprite = sprite


## Advance one physics frame.
func tick(delta: float) -> void:
	if _player_adjacent():
		_wandering = false
	elif _wandering:
		_walk()
	else:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
	if not _wandering:
		_body.velocity = Vector2.ZERO
	_animate(delta)


func _walk() -> void:
	var to_target := _target - _body.position
	if to_target.length() < 2.0:
		_wandering = false
		_wait = randf_range(1.5, 4.0)
		return
	_body.velocity = to_target.normalized() * SPEED
	_sprite.flip_h = _body.velocity.x < 0.0
	_body.move_and_slide()
	if _body.get_slide_collision_count() > 0:
		_wandering = false
		_wait = 1.0


func _pick_target() -> void:
	var candidate := _body.home + Vector2.from_angle(randf() * TAU) * randf() * _body.home_radius
	var grid := _grid()
	if grid and grid.is_water(grid.cell_of(candidate)):
		_wait = 1.0
		return
	_target = candidate
	_wandering = true


func _player_adjacent() -> bool:
	var player := _body.get_tree().get_first_node_in_group("Player") as Node2D
	return player != null and player.global_position.distance_to(_body.global_position) < PLAYER_STOP_DISTANCE


func _animate(delta: float) -> void:
	if _body.frames < 2 or not _wandering:
		_sprite.frame = 0
		return
	_walk_time += delta
	_sprite.frame = int(_walk_time / FRAME_TIME) % _body.frames


func _grid() -> FarmGrid:
	var level := _body.get_tree().get_first_node_in_group("Level") as Level
	return level.farm_grid if level else null

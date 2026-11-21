class_name DayCycle extends Node
## Owns ending a day: bed and pass-out both go through end_day(). Locks the player, fades
## out, runs GameClock.advance_day() (see docs/contracts.md "Day-end order"), moves the
## player home after a pass-out, fades back in and restarts the clock.

signal transition_started
signal transition_finished

const GROUP := &"DayCycle"
const FADE_PARAM := &"shader_parameter/progress"

## Seconds for each half of the fade. 0 = instant (tests).
@export var fade_time: float = 1.0
## Seconds the screen stays black while the day rolls over.
@export var hold_time: float = 0.5
## Fullscreen ColorRect whose material has a `progress` shader parameter (0 clear, 1 black).
@export var fade_rect: ColorRect
@export var player: Node2D
## Where the player wakes up after passing out.
@export var wake_point: Node2D

## True from end_day() until the fade-in completes.
var busy: bool = false


## True while any DayCycle in `tree` is mid-transition (gameplay input must be ignored).
static func is_transitioning(tree: SceneTree) -> bool:
	var cycle := tree.get_first_node_in_group(GROUP) as DayCycle
	return cycle != null and cycle.busy


func _ready() -> void:
	add_to_group(GROUP)
	GameClock.passed_out.connect(_on_passed_out)


func _unhandled_input(event: InputEvent) -> void:
	# Debug shortcut for testing; the real way to end a day is the bed.
	if OS.is_debug_build() and event.is_action_pressed(&"day_change"):
		end_day()


## Play the transition and roll the world to the next morning. Ignored while busy.
## `passed_out` moves the player to the wake point.
func end_day(passed_out: bool = false) -> void:
	if busy:
		return
	busy = true
	transition_started.emit()
	_lock_player(true)
	await _fade(1.0)
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time).timeout
	GameClock.advance_day()
	if passed_out and player and wake_point:
		player.global_position = wake_point.global_position
	GameClock.start()
	await _fade(0.0)
	_lock_player(false)
	busy = false
	transition_finished.emit()


func _on_passed_out() -> void:
	end_day(true)


func _lock_player(locked: bool) -> void:
	if player:
		player.set(&"input_locked", locked)


func _fade(target: float) -> void:
	if fade_rect == null:
		return
	var material := fade_rect.material
	if fade_time <= 0.0:
		material.set(FADE_PARAM, target)
		return
	var tween := create_tween()
	tween.tween_property(material, "shader_parameter/progress", target, fade_time)
	await tween.finished

class_name TestCase extends RefCounted
## Base class for unit tests. Add methods named test_*; use check()/eq() to assert.
## Run all tests with tools/check.sh or: godot --headless --path . res://tests/test_runner.tscn

var failures: Array[String] = []
var tree: SceneTree
var _level: Level


func check(condition: bool, message: String = "condition was false") -> void:
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected <%s> got <%s>" % [message, expected, actual])


func near(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s expected ~<%s> got <%s>" % [message, expected, actual])


## Called before each test method; override to reset autoload state.
func before_each() -> void:
	pass


## Called after each test method; frees a level the test forgot to despawn.
func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null


## Instantiates level.tscn under the root and waits `settle_frames` frames for _ready chains
## to finish; `fast_days` zeroes the day-cycle fade so end_day() completes in one frame.
func spawn_level(settle_frames: int = 2, fast_days: bool = true) -> Level:
	_level = load("res://scenes/levels/level.tscn").instantiate()
	tree.root.add_child.call_deferred(_level)  # the root is busy while the runner starts
	for i in settle_frames:
		await tree.process_frame
	if fast_days:
		_level.day_cycle.fade_time = 0.0
		_level.day_cycle.hold_time = 0.0
	return _level


func despawn_level() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	await tree.process_frame

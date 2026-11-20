class_name TestCase extends RefCounted
## Base class for unit tests. Add methods named test_*; use check()/eq() to assert.
## Run all tests with tools/check.sh or: godot --headless --path . res://tests/test_runner.tscn

var failures: Array[String] = []
var tree: SceneTree


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

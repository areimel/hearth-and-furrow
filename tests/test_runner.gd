extends Node
## Discovers res://tests/test_*.gd (each extending TestCase), runs every test_* method,
## prints PASS/FAIL lines and exits with the number of failed tests as the exit code.

const TEST_DIR := "res://tests"


func _ready() -> void:
	var failed := 0
	var total := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file in ["test_case.gd", "test_runner.gd"]:
			continue
		var script: GDScript = load(TEST_DIR.path_join(file))
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.tree = get_tree()
			case.before_each()
			await case.call(method_name)
			case.after_each()
			total += 1
			if case.failures.is_empty():
				print("PASS %s::%s" % [file, method_name])
			else:
				failed += 1
				for failure in case.failures:
					print("FAIL %s::%s — %s" % [file, method_name, failure])
	print("TESTS %d run, %d failed" % [total, failed])
	get_tree().quit(failed)

extends Node
## Loads every .gd file inside the running project (so autoloads resolve) and reports
## scripts that fail to compile. `godot --check-only --script` cannot do this because it
## skips autoloads. Run via tools/check.sh.

const SKIP_DIRS: Array[String] = ["res://.godot", "res://premade", "res://exports", "res://graphics", "res://audio"]


func _ready() -> void:
	var bad := 0
	var paths := _collect("res://")
	for path in paths:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if script == null or not script.can_instantiate():
			print("PARSEFAIL %s" % path)
			bad += 1
	print("PARSED %d scripts, %d failed" % [paths.size(), bad])
	get_tree().quit(bad)


func _collect(dir: String) -> Array[String]:
	var found: Array[String] = []
	if dir.trim_suffix("/") in SKIP_DIRS:
		return found
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			found.append_array(_collect(dir.path_join(sub)))
	return found

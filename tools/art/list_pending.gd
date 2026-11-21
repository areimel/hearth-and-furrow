extends Node
## Prints Content.pending_placeholders() and validate() problems. Run via list_pending.tscn.

func _ready() -> void:
	for p in Content.pending_placeholders():
		print("PENDING ", p)
	var problems := Content.validate()
	print("PROBLEMS ", problems.size())
	for p in problems:
		print("  ", p)
	get_tree().quit()

class_name TreeGrove extends Node2D
## Script of the level's Objects/Trees node. Registers the single `trees` save section:
## every AppleTree under it, keyed by node name.


func _ready() -> void:
	SaveManager.register(&"trees", self)


func _exit_tree() -> void:
	if SaveManager.is_registered(&"trees"):
		SaveManager.unregister(&"trees")


## Every tree, in scene order.
func trees() -> Array[AppleTree]:
	var out: Array[AppleTree] = []
	for child in get_children():
		if child is AppleTree:
			out.append(child)
	return out


## Save section: {"trees": {node name: tree state}}.
func to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for tree in trees():
		saved[String(tree.name)] = tree.to_dict()
	return {"trees": saved}


## Restore every tree; trees missing from `data` return to full health.
func from_dict(data: Dictionary) -> void:
	var saved: Dictionary = data.get("trees", {})
	for tree in trees():
		tree.from_dict(saved.get(String(tree.name), {}))


## New game: every tree whole again.
func reset() -> void:
	from_dict({})

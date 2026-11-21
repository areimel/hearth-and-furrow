class_name Places
extends RefCounted
## Static helpers for named places (Marker2D nodes in group "Place") and walking routes
## between them. Place ids come from docs/contracts.md (`manor`, `mill`, `farm_gate`, ...).

const GROUP := &"Place"
static var _warned: Dictionary = {}


## Every place marker by id -> global position.
static func all(tree: SceneTree) -> Dictionary:
	var out := {}
	for n in tree.get_nodes_in_group(GROUP):
		if n is Node2D:
			out[StringName(n.name)] = (n as Node2D).global_position
	return out


static func has(tree: SceneTree, id: StringName) -> bool:
	return _find(tree, id) != null


## Global position of a place; Vector2.ZERO (with one warning per id) when it does not exist.
static func position_of(tree: SceneTree, place_id: StringName) -> Vector2:
	var marker := _find(tree, place_id)
	if marker == null:
		if not _warned.has(place_id):
			_warned[place_id] = true
			push_warning("Places: no marker for place '%s'" % place_id)
		return Vector2.ZERO
	return marker.global_position


## Walkable polyline (global pixels) from one place to another. Uses the Village's baked grid;
## without a village in the tree it falls back to a straight two-point line.
static func path_between(tree: SceneTree, from_id: StringName, to_id: StringName) -> PackedVector2Array:
	var a := position_of(tree, from_id)
	var b := position_of(tree, to_id)
	var village := tree.get_first_node_in_group(&"Village") as Village
	if village == null:
		return PackedVector2Array([a, b])
	return village.path_between(a, b)


static func _find(tree: SceneTree, id: StringName) -> Node2D:
	for n in tree.get_nodes_in_group(GROUP):
		if n is Node2D and n.name == id:
			return n
	return null

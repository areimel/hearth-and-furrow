class_name Places
extends RefCounted
## The one place the game touches the village map: named places (Marker2D nodes in group
## "Place", named exactly like the place id from docs/contracts.md) and the walking routes
## between them. A missing marker means "stay where you are": marker() is null and route()
## is empty.

const GROUP := &"Place"
static var _warned: Dictionary = {}


## Every place marker by id -> global position.
static func all(tree: SceneTree) -> Dictionary:
	var out := {}
	for n in tree.get_nodes_in_group(GROUP):
		if n is Node2D:
			out[StringName(n.name)] = (n as Node2D).global_position
	return out


## True if the map has a marker for `id`.
static func has(tree: SceneTree, id: StringName) -> bool:
	return marker(tree, id) != null


## The marker node for a place id, or null.
static func marker(tree: SceneTree, id: StringName) -> Node2D:
	for n in tree.get_nodes_in_group(GROUP):
		if n is Node2D and StringName(n.name) == id:
			return n
	return null


## Global position of a place; Vector2.ZERO (with one warning per id) when it does not
## exist. Use has() / marker() first when a missing place is a normal case.
static func position_of(tree: SceneTree, place_id: StringName) -> Vector2:
	var node := marker(tree, place_id)
	if node == null:
		if not _warned.has(place_id):
			_warned[place_id] = true
			push_warning("Places: no marker for place '%s'" % place_id)
		return Vector2.ZERO
	return node.global_position


## Walkable polyline (global pixels) from one place to another. Uses the Village's baked grid;
## without a village in the tree it falls back to a straight two-point line.
static func path_between(tree: SceneTree, from_id: StringName, to_id: StringName) -> PackedVector2Array:
	var a := position_of(tree, from_id)
	var b := position_of(tree, to_id)
	var village := tree.get_first_node_in_group(&"Village") as Village
	if village == null:
		return PackedVector2Array([a, b])
	return village.path_between(a, b)


## Waypoints from `from_pos` to the place `to_id`; `from_id` (may be empty) is the place the
## walker last stood at and lets the village route around obstacles. Empty if `to_id` is unknown.
static func route(tree: SceneTree, from_pos: Vector2, from_id: StringName,
		to_id: StringName) -> PackedVector2Array:
	var target := marker(tree, to_id)
	if target == null:
		return PackedVector2Array()
	var points := PackedVector2Array()
	if from_id != &"" and from_id != to_id and has(tree, from_id):
		points = path_between(tree, from_id, to_id)
	if points.is_empty() or points[points.size() - 1].distance_to(target.global_position) > 1.0:
		points.append(target.global_position)
	return points


## Child markers of a place whose name starts with `prefix` (festival spots), name order.
static func spots(tree: SceneTree, place_id: StringName, prefix: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var parent := marker(tree, place_id)
	if parent == null:
		return out
	var found: Array[Node2D] = []
	for child in parent.get_children():
		if child is Node2D and String(child.name).begins_with(prefix):
			found.append(child)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool: return String(a.name) < String(b.name))
	for node in found:
		out.append(node.global_position)
	return out

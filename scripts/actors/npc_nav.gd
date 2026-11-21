class_name NPCNav extends RefCounted
## The one place NPCs touch the village map. Place markers are Node2Ds in group `Place`
## named exactly like the place id; if the map provides res://scripts/world/places.gd with
## `path_between(tree, from_id, to_id)` it is used, otherwise villagers walk in a straight
## line. A missing marker means "stay where you are": callers get null / an empty path.

const GROUP := &"Place"
const PLACES_SCRIPT := "res://scripts/world/places.gd"


## The marker node for a place id, or null.
static func marker(tree: SceneTree, place_id: StringName) -> Node2D:
	for node in tree.get_nodes_in_group(GROUP):
		if node is Node2D and StringName(node.name) == place_id:
			return node
	return null


## World position of a place, or null when the map has no such marker.
static func position_of(tree: SceneTree, place_id: StringName) -> Variant:
	var node := marker(tree, place_id)
	return node.global_position if node else null


## Waypoints from `from_pos` to the place `to_id`; `from_id` (may be empty) is the place the
## walker last stood at and lets the map route around obstacles. Empty if `to_id` is unknown.
static func route(tree: SceneTree, from_pos: Vector2, from_id: StringName,
		to_id: StringName) -> PackedVector2Array:
	var target: Variant = position_of(tree, to_id)
	if target == null:
		return PackedVector2Array()
	var points := PackedVector2Array()
	var places: Script = null
	if ResourceLoader.exists(PLACES_SCRIPT):
		places = load(PLACES_SCRIPT) as Script
	if places != null and from_id != &"" and from_id != to_id and places.has_method(&"path_between"):
		var mapped: Variant = places.call(&"path_between", tree, from_id, to_id)
		if mapped is PackedVector2Array:
			points = mapped
	if points.is_empty() or points[points.size() - 1].distance_to(target) > 1.0:
		points.append(target)
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

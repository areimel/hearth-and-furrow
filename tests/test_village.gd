extends TestCase
## Village district scene: loads, has every contract place marker, walkable routes between all
## places, and no marker inside collision.

const SCENE := "res://scenes/world/village.tscn"
const EXTRA_PLACES: Array[StringName] = [&"farm_gate", &"feast_ground"]

var _village: Village


func _load_village() -> Village:
	var packed := load(SCENE) as PackedScene
	check(packed != null, "village.tscn loads")
	if packed == null:
		return null
	var v := packed.instantiate() as Village
	tree.root.add_child(v)
	return v


func _unload() -> void:
	if _village != null:
		tree.root.remove_child(_village)
		_village.free()
		_village = null


## Place ids listed in the Places row of docs/contracts.md.
func _contract_places() -> Array[StringName]:
	var out: Array[StringName] = []
	var text := FileAccess.get_file_as_string("res://docs/contracts.md")
	for line in text.split("\n"):
		if line.begins_with("| Places"):
			var cells := line.split("|")
			var rx := RegEx.create_from_string("`([a-z_]+)`")
			for m in rx.search_all(cells[2]):
				out.append(StringName(m.get_string(1)))
	return out


func _all_ids() -> Array[StringName]:
	var ids := _contract_places()
	ids.append_array(EXTRA_PLACES)
	return ids


func test_scene_loads_and_has_bounds() -> void:
	_village = _load_village()
	check(_village != null, "instantiates as Village")
	if _village == null:
		return
	check(_village.bounds.size.x > 500.0 and _village.bounds.size.y > 400.0, "village is a real district")
	check(_village.get_node_or_null("Objects") != null, "has y-sorted Objects node")
	check(_village.get_node_or_null("Collision") != null, "has Collision body")
	_unload()


func test_every_contract_place_has_a_marker() -> void:
	_village = _load_village()
	var contract := _contract_places()
	check(contract.size() >= 9, "contracts.md lists the places (%d)" % contract.size())
	for id in _all_ids():
		check(Places.has(tree, id), "marker for %s" % id)
		check(Places.position_of(tree, id) != Vector2.ZERO, "%s has a position" % id)
	eq(Places.all(tree).size() >= _all_ids().size(), true, "Places.all lists them")
	var feast := _village.get_node("Places/feast_ground")
	for i in range(1, 9):
		check(feast.get_node_or_null("spot_%d" % i) != null, "feast spot_%d" % i)
	_unload()


func test_no_marker_inside_collision() -> void:
	_village = _load_village()
	var body := _village.get_node("Collision") as StaticBody2D
	var rects: Array[Rect2] = []
	for child in body.get_children():
		var cs := child as CollisionShape2D
		var size := (cs.shape as RectangleShape2D).size
		rects.append(Rect2(cs.global_position - size / 2.0, size))
	var points: Dictionary = Places.all(tree)
	for id: StringName in points:
		var p: Vector2 = points[id]
		check(_village.is_point_walkable(p), "%s on a walkable cell" % id)
		for r in rects:
			check(not r.has_point(p), "%s inside a collider" % id)
	for spot in _village.get_node("Places/feast_ground").get_children():
		check(_village.is_point_walkable((spot as Node2D).global_position), "%s walkable" % spot.name)
	_unload()


func test_paths_between_all_places_are_walkable() -> void:
	_village = _load_village()
	var ids := _all_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var path := Places.path_between(tree, ids[i], ids[j])
			check(path.size() >= 2, "path %s -> %s non-empty" % [ids[i], ids[j]])
			_check_polyline_walkable(path, "%s -> %s" % [ids[i], ids[j]])
			if path.size() >= 2:
				check(path[0].distance_to(Places.position_of(tree, ids[i])) < 24.0, "starts at %s" % ids[i])
				check(path[path.size() - 1].distance_to(Places.position_of(tree, ids[j])) < 24.0, "ends at %s" % ids[j])
	_unload()


func test_missing_place_warns_once_and_returns_zero() -> void:
	eq(Places.position_of(tree, &"no_such_place"), Vector2.ZERO, "missing place")
	check(not Places.has(tree, &"no_such_place"), "has() false")


func _check_polyline_walkable(path: PackedVector2Array, label: String) -> void:
	for k in path.size():
		check(_village.is_point_walkable(path[k]), "%s point %d walkable" % [label, k])
		if k > 0:
			for s in range(1, 8):
				var q := path[k - 1].lerp(path[k], s / 8.0)
				check(_village.is_point_walkable(q), "%s segment %d sample walkable" % [label, k])

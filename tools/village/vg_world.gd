extends RefCounted
## Creates the non-tilemap nodes of the village: y-sorted sprites, collision and place markers.
## Every node gets `owner = root` so PackedScene.pack() keeps it.

const VgData := preload("res://tools/village/vg_data.gd")
const VgLayout := preload("res://tools/village/vg_layout.gd")
const T := 16

var root: Node2D
var grid: RefCounted
var _textures: Dictionary = {}


func _init(p_root: Node2D, p_grid: RefCounted) -> void:
	root = p_root
	grid = p_grid


## World pixel position of a grid cell's top-left corner.
func cell_px(cell: Vector2i) -> Vector2:
	return Vector2(VgLayout.ORIGIN + cell) * T


func build_objects() -> void:
	var objects := _node(Node2D.new(), "Objects", root)
	objects.y_sort_enabled = true
	for letter: String in grid.buildings:
		var def: Dictionary = VgData.BUILDINGS[letter]
		var rect: Rect2i = grid.buildings[letter]
		var foot := cell_px(Vector2i(rect.position.x, rect.end.y)) + Vector2(rect.size.x * T / 2.0, 0.0)
		_sprite(objects, def["name"], def["tex"], def["rect"], foot)
	for p in grid.props:
		var def: Dictionary = VgData.PROPS[p["ch"]]
		var cell: Vector2i = p["cell"]
		var size: Vector2i = def["rect"].size
		var base := cell_px(Vector2i(cell.x, cell.y + 1))
		var foot := base + Vector2(size.x * T / 2.0 if def["anchor"] == "bl" else T / 2.0, 0.0)
		_sprite(objects, "%s_%d_%d" % [def["name"], cell.x, cell.y], def["tex"], def["rect"], foot)
		if def.has("over"):
			var over: Dictionary = def["over"]
			_sprite(objects, "%s_Top_%d_%d" % [def["name"], cell.x, cell.y], over["tex"], over["rect"],
				foot + Vector2(0.0, 0.5), float(over["dy"]) + 1.0)


func build_collision() -> void:
	var body := _node(StaticBody2D.new(), "Collision", root) as StaticBody2D
	body.collision_layer = 1
	body.collision_mask = 0
	for letter: String in grid.buildings:
		var rect: Rect2i = grid.buildings[letter]
		var solid_rows: int = VgData.BUILDINGS[letter]["solid"]
		var top := Vector2i(rect.position.x, rect.end.y - solid_rows)
		_shape(body, VgData.BUILDINGS[letter]["name"], Rect2(cell_px(top), Vector2(rect.size.x, solid_rows) * T))
	for p in grid.props:
		if p["ch"] == "t" or p["ch"] == "T":
			var cell: Vector2i = p["cell"]
			var centre_x: float = cell_px(cell).x + (T if p["ch"] == "t" else T / 2.0)
			var rect := Rect2(Vector2(centre_x - 5.0, cell_px(cell).y + 5.0), Vector2(10, 9))
			_shape(body, "Trunk_%d_%d" % [cell.x, cell.y], rect)
	_cell_runs(body)


func build_places(places: Node2D) -> void:
	for letter: String in grid.buildings:
		var place: StringName = VgData.BUILDINGS[letter]["place"]
		if place != &"":
			_marker(places, place, grid.door_front(letter))
	for id: StringName in VgLayout.PLACE_CELLS:
		_marker(places, id, VgLayout.PLACE_CELLS[id])
	var feast := places.get_node("feast_ground") as Node2D
	for i in VgLayout.FEAST_SPOTS.size():
		var spot := Marker2D.new()
		spot.name = "spot_%d" % (i + 1)
		feast.add_child(spot)
		spot.owner = root
		spot.position = Vector2(VgLayout.FEAST_SPOTS[i] * T)


func _marker(parent: Node2D, id: StringName, cell: Vector2i) -> void:
	var m := Marker2D.new()
	m.name = String(id)
	parent.add_child(m)
	m.owner = root
	m.add_to_group(&"Place", true)
	m.position = cell_px(cell) + Vector2(T, T) / 2.0


func _sprite(parent: Node2D, node_name: String, tex: StringName, region: Rect2i, foot: Vector2, lift: float = 0.0) -> void:
	if not _textures.has(tex):
		_textures[tex] = load(VgData.TEXTURES[tex])
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = _textures[tex]
	s.region_enabled = true
	s.region_rect = Rect2(Vector2(region.position * T), Vector2(region.size * T))
	s.centered = false
	s.offset = Vector2(-region.size.x * T / 2.0, -region.size.y * T + lift)
	parent.add_child(s)
	s.owner = root
	s.position = foot


## Merges horizontal runs of cell-sized colliders (fences, pond, coast ring) into rectangles.
func _cell_runs(body: StaticBody2D) -> void:
	for r in grid.rows:
		var c := 0
		while c < grid.cols:
			if not grid.coll_cells.has(Vector2i(c, r)):
				c += 1
				continue
			var start := c
			while c < grid.cols and grid.coll_cells.has(Vector2i(c, r)):
				c += 1
			_shape(body, "Cells_%d_%d" % [start, r], Rect2(cell_px(Vector2i(start, r)), Vector2((c - start) * T, T)))


func _shape(body: StaticBody2D, shape_name: String, rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = shape_name
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.add_child(cs)
	cs.owner = root
	cs.position = rect.position + rect.size / 2.0


func _node(n: Node, node_name: String, parent: Node) -> Node:
	n.name = node_name
	parent.add_child(n)
	n.owner = root
	return n

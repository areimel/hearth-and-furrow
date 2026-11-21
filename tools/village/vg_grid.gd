extends RefCounted
## Parsed village grid: building rectangles, prop anchors and the solid / walkable cell sets.
## All cells here are grid cells (col, row); add VgLayout.ORIGIN for world cells.

const VgData := preload("res://tools/village/vg_data.gd")
const VgLayout := preload("res://tools/village/vg_layout.gd")

var cols: int = 0
var rows: int = 0
var buildings: Dictionary = {}  # letter -> Rect2i (cells)
var props: Array[Dictionary] = []  # {ch, cell}
var solid: Dictionary = {}  # Vector2i -> true, everything that blocks walking
var coll_cells: Dictionary = {}  # Vector2i -> true, cells that get a generic cell-sized collider


func _init() -> void:
	rows = VgLayout.GRID.size()
	cols = VgLayout.GRID[0].length()
	for r in rows:
		assert(VgLayout.GRID[r].length() == cols, "grid row %d has a different width" % r)
	for r in rows:
		for c in cols:
			_parse_cell(Vector2i(c, r))
	for letter: String in buildings:
		_solidify_building(letter)
	for p in props:
		_solidify_prop(p)
	for c in cols:
		_block(Vector2i(c, 0), true)
		_block(Vector2i(c, rows - 1), true)
	for r in rows:
		_block(Vector2i(cols - 1, r), true)


## Character at a grid cell, "" outside the grid.
func ch(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return ""
	return VgLayout.GRID[cell.y][cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return ch(cell) != "" and not solid.has(cell)


## Front cell of a building door (the cell below the door tile).
func door_front(letter: String) -> Vector2i:
	var rect: Rect2i = buildings[letter]
	return Vector2i(rect.position.x + int(VgData.BUILDINGS[letter]["door"]), rect.end.y)


func _parse_cell(cell: Vector2i) -> void:
	var s := ch(cell)
	if VgData.BUILDINGS.has(s):
		var rect: Rect2i = buildings.get(s, Rect2i(cell, Vector2i.ZERO))
		buildings[s] = rect.expand(cell).expand(cell + Vector2i.ONE)
	elif VgData.PROPS.has(s):
		props.append({"ch": s, "cell": cell})
	elif s == "#" or s == "~" or s == "l":
		_block(cell, true)


func _solidify_building(letter: String) -> void:
	var rect: Rect2i = buildings[letter]
	var rows_solid: int = VgData.BUILDINGS[letter]["solid"]
	for y in range(rect.end.y - rows_solid, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_block(Vector2i(x, y), false)


func _solidify_prop(p: Dictionary) -> void:
	var def: Dictionary = VgData.PROPS[p["ch"]]
	var foot: Vector2i = def["foot"]
	var cell: Vector2i = p["cell"]
	var start_x := cell.x - (foot.x / 2 if def["anchor"] == "bc" else 0)
	# Trees get a tight trunk collider instead of cell colliders.
	var is_tree: bool = p["ch"] == "t" or p["ch"] == "T"
	for y in range(cell.y - foot.y + 1, cell.y + 1):
		for x in range(start_x, start_x + foot.x):
			_block(Vector2i(x, y), not is_tree)


func _block(cell: Vector2i, with_collider: bool) -> void:
	solid[cell] = true
	if with_collider:
		coll_cells[cell] = true

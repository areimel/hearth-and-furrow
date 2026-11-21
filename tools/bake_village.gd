extends SceneTree
## Bakes the village district from the character grid in tools/village/ into
## scenes/world/village.tscn (+ resources/village_tileset.tres). Deterministic; re-run to regenerate.
##
##   ~/.local/share/godot/4.6/godot --path . --headless --script res://tools/bake_village.gd
##
## The generated scene is a normal scene: open it in the editor and tweak freely, but a re-bake
## overwrites hand edits, so change the grid / catalogue instead.

const VgData := preload("res://tools/village/vg_data.gd")
const VgLayout := preload("res://tools/village/vg_layout.gd")
const VgTiles := preload("res://tools/village/vg_tiles.gd")
const VgGrid := preload("res://tools/village/vg_grid.gd")
const VgWorld := preload("res://tools/village/vg_world.gd")

const OUT_SCENE := "res://scenes/world/village.tscn"
const OUT_TILESET := "res://resources/village_tileset.tres"
const T := 16
## Sea margin (cells) drawn around the land so the camera never sees the void.
const SEA_RECT := Rect2i(30, -30, 60, 67)

var _tiles := VgTiles.new()
var _grid := VgGrid.new()
var _root := Node2D.new()


func _init() -> void:
	_root.name = "Village"
	_root.set_script(load("res://scripts/world/village.gd"))
	_root.y_sort_enabled = true
	var ground := _layer("Ground", -2)
	var paths := _layer("Paths", -2)
	var decor := _layer("Decor", -1)
	var fences := _layer("Fences", -1)
	_add_sea()
	_paint_ground(ground)
	_paint_paths(paths)
	_paint_decor(decor)
	_paint_fences(fences)
	var world := VgWorld.new(_root, _grid)
	world.build_objects()
	world.build_collision()
	var places := Node2D.new()
	places.name = "Places"
	_root.add_child(places)
	places.owner = _root
	world.build_places(places)
	_export_data()
	_save()
	_root.free()
	quit()


func _layer(layer_name: String, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = _tiles.tile_set
	l.z_index = z
	_root.add_child(l)
	l.owner = _root
	return l


func _world_cell(cell: Vector2i) -> Vector2i:
	return cell + VgLayout.ORIGIN


## Flat colour rect matching the farm's sea (pale green-grey after the level's canvas modulate).
func _add_sea() -> void:
	var sea := ColorRect.new()
	sea.name = "Sea"
	sea.color = VgData.SEA_COLOR
	sea.z_index = -3
	sea.position = Vector2(SEA_RECT.position * T)
	sea.size = Vector2(SEA_RECT.size * T)
	_root.add_child(sea)
	_root.move_child(sea, 0)
	sea.owner = _root


## Land = every grid cell except the pond. The west edge continues into the farm island.
func _is_land(cell: Vector2i) -> bool:
	if cell.x < 0 and cell.y >= VgLayout.FARM_ROWS.x and cell.y <= VgLayout.FARM_ROWS.y:
		return true
	return _grid.ch(cell) != "" and _grid.ch(cell) != "~" and _grid.ch(cell) != "l"


func _paint_ground(layer: TileMapLayer) -> void:
	var coast: Dictionary = VgData.COAST_BLOB
	for r in _grid.rows:
		for c in _grid.cols:
			var cell := Vector2i(c, r)
			if not _is_land(cell):
				continue
			var n := _is_land(cell + Vector2i.UP)
			var e := _is_land(cell + Vector2i.RIGHT)
			var s := _is_land(cell + Vector2i.DOWN)
			var w := _is_land(cell + Vector2i.LEFT)
			if n and e and s and w:
				var variant := VgTiles.hash01(cell)
				var atlas := VgData.GRASS_TILE
				if variant < 0.12:
					atlas = VgData.GRASS_VARIANTS[int(variant * 100) % VgData.GRASS_VARIANTS.size()]
				_tiles.put(layer, _world_cell(cell), &"floor", atlas)
			else:
				_tiles.put(layer, _world_cell(cell), coast["tex"], VgTiles.blob_piece(coast["origin"], n, e, s, w))


func _is_dirt(cell: Vector2i) -> bool:
	if cell.x < 0:
		return _grid.ch(Vector2i(0, cell.y)) == ","
	return _grid.ch(cell) == "," or _grid.ch(cell) == "o"


func _paint_paths(layer: TileMapLayer) -> void:
	var dirt: Dictionary = VgData.DIRT_BLOB
	for r in _grid.rows:
		for c in _grid.cols:
			var cell := Vector2i(c, r)
			if not _is_dirt(cell):
				continue
			var piece := VgTiles.blob_piece(dirt["origin"], _is_dirt(cell + Vector2i.UP),
				_is_dirt(cell + Vector2i.RIGHT), _is_dirt(cell + Vector2i.DOWN), _is_dirt(cell + Vector2i.LEFT))
			_tiles.put(layer, _world_cell(cell), dirt["tex"], piece)


func _paint_decor(layer: TileMapLayer) -> void:
	for r in _grid.rows:
		for c in _grid.cols:
			var cell := Vector2i(c, r)
			if _grid.ch(cell) == "l":
				_tiles.put(layer, _world_cell(cell), &"water", VgData.LILY_TILE)
			elif _grid.ch(cell) == "f":
				var i := int(VgTiles.hash01(cell, 7) * VgData.FLOWER_TILES.size())
				_tiles.put(layer, _world_cell(cell), &"nature", VgData.FLOWER_TILES[i])


func _paint_fences(layer: TileMapLayer) -> void:
	for r in _grid.rows:
		for c in _grid.cols:
			var cell := Vector2i(c, r)
			if _grid.ch(cell) != "#":
				continue
			var horizontal := _grid.ch(cell + Vector2i.LEFT) == "#" or _grid.ch(cell + Vector2i.RIGHT) == "#"
			var vertical := _grid.ch(cell + Vector2i.UP) == "#" or _grid.ch(cell + Vector2i.DOWN) == "#"
			var atlas := VgData.FENCE_V if vertical and not horizontal else VgData.FENCE_H
			_tiles.put(layer, _world_cell(cell), &"house", atlas)


## Stores the walkability grid and gate info on the root script's exported properties.
func _export_data() -> void:
	var data := PackedByteArray()
	data.resize(_grid.cols * _grid.rows)
	for r in _grid.rows:
		for c in _grid.cols:
			var cell := Vector2i(c, r)
			data[r * _grid.cols + c] = (2 if _is_dirt(cell) else 1) if _grid.is_walkable(cell) else 0
	_root.set("origin_cell", VgLayout.ORIGIN)
	_root.set("grid_size", Vector2i(_grid.cols, _grid.rows))
	_root.set("walkable", data)
	_root.set("farm_gap_cells", VgLayout.FARM_GAP)
	_root.set("bounds", Rect2(Vector2(VgLayout.ORIGIN * T), Vector2(_grid.cols * T, _grid.rows * T)))


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SCENE.get_base_dir()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_TILESET.get_base_dir()))
	_tiles.tile_set.resource_path = OUT_TILESET
	var err := ResourceSaver.save(_tiles.tile_set, OUT_TILESET)
	assert(err == OK, "tileset save failed: %d" % err)
	var packed := PackedScene.new()
	err = packed.pack(_root)
	assert(err == OK, "pack failed: %d" % err)
	err = ResourceSaver.save(packed, OUT_SCENE)
	assert(err == OK, "scene save failed: %d" % err)
	_normalise_ids()
	print("baked %s (%d walkable cells)" % [OUT_SCENE, _count_walkable()])


func _count_walkable() -> int:
	var data: PackedByteArray = _root.get("walkable")
	return data.size() - data.count(0)


## PackedScene.pack() invents random resource ids; rewrite them in order of appearance so that
## re-running the bake yields a byte-identical scene.
func _normalise_ids() -> void:
	var text := FileAccess.get_file_as_string(OUT_SCENE)
	var rx := RegEx.create_from_string("\\[(ext_resource|sub_resource) [^\\]]*?id=\"([^\"]+)\"")
	var map := {}
	for m in rx.search_all(text):
		var old: String = m.get_string(2)
		if not map.has(old):
			map[old] = "%s_%d" % [m.get_string(1).trim_suffix("_resource"), map.size() + 1]
	for old: String in map:
		text = text.replace("\"%s\"" % old, "\"%s\"" % map[old])
	var uid_rx := RegEx.create_from_string(" unique_id=\\d+")
	var out := ""
	var last := 0
	var count := 0
	for m in uid_rx.search_all(text):
		count += 1
		out += text.substr(last, m.get_start() - last) + " unique_id=%d" % (1000 + count)
		last = m.get_end()
	text = out + text.substr(last)
	var f := FileAccess.open(OUT_SCENE, FileAccess.WRITE)
	f.store_string(text)
	f.close()

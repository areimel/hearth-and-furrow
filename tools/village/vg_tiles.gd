extends RefCounted
## Builds the village TileSet lazily (only tiles that are actually used get created)
## and picks 9-piece "blob" autotile pieces from 4-neighbour masks.

const VgData := preload("res://tools/village/vg_data.gd")

var tile_set := TileSet.new()
var _sources: Dictionary = {}  # texture key -> atlas source id


func _init() -> void:
	tile_set.tile_size = Vector2i(16, 16)


## Source id for a texture key, creating the atlas source on first use.
func source_id(tex: StringName) -> int:
	if not _sources.has(tex):
		var src := TileSetAtlasSource.new()
		src.texture = load(VgData.TEXTURES[tex]) as Texture2D
		src.texture_region_size = Vector2i(16, 16)
		_sources[tex] = tile_set.add_source(src)
	return _sources[tex]


## Place one tile of `tex` at `atlas` into `layer` at `cell`, creating the tile if needed.
func put(layer: TileMapLayer, cell: Vector2i, tex: StringName, atlas: Vector2i) -> void:
	var sid := source_id(tex)
	var src := tile_set.get_source(sid) as TileSetAtlasSource
	if not src.has_tile(atlas):
		src.create_tile(atlas)
	layer.set_cell(cell, sid, atlas)


## Deterministic per-cell pseudo random number in [0, 1).
static func hash01(cell: Vector2i, salt: int = 0) -> float:
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	return float(h & 0xffff) / 65536.0


## Blob piece for a cell given which 4-neighbours belong to the same group.
## `o` is the origin of the 3x3 set; caps live at o+(3,0..2) (vertical) and o+(0..2,3) (horizontal).
static func blob_piece(o: Vector2i, n: bool, e: bool, s: bool, w: bool) -> Vector2i:
	var count := int(n) + int(e) + int(s) + int(w)
	match count:
		4:
			return o + Vector2i(1, 1)
		3:
			if not n:
				return o + Vector2i(1, 0)
			if not s:
				return o + Vector2i(1, 2)
			if not w:
				return o + Vector2i(0, 1)
			return o + Vector2i(2, 1)
		2:
			if n and s:
				return o + Vector2i(3, 1)
			if e and w:
				return o + Vector2i(1, 3)
			if s and e:
				return o + Vector2i(0, 0)
			if s and w:
				return o + Vector2i(2, 0)
			if n and e:
				return o + Vector2i(0, 2)
			return o + Vector2i(2, 2)
		1:
			if s:
				return o + Vector2i(3, 0)
			if n:
				return o + Vector2i(3, 2)
			if e:
				return o + Vector2i(0, 3)
			return o + Vector2i(2, 3)
	return o + Vector2i(3, 3)

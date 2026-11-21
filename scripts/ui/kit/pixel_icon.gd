class_name PixelIcon extends RefCounted
## Builds tiny textures from rows of characters so small status glyphs (hearts, season
## and weather icons, ticks) need no image files. '.' and ' ' are transparent; every
## other character looks up its colour in the legend. Results are cached per key.

static var _cache: Dictionary[String, ImageTexture] = {}


## Texture for `rows` (all rows the same width) coloured by `legend` (char -> Color).
## `key` identifies the icon in the cache; pass a unique string per distinct bitmap.
static func make(key: String, rows: PackedStringArray, legend: Dictionary) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var width := rows[0].length()
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in width:
			var glyph := rows[y][x]
			if glyph != "." and glyph != " " and legend.has(glyph):
				image.set_pixel(x, y, legend[glyph])
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

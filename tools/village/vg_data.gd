extends RefCounted
## Art catalogue for the village bake: which atlas regions are buildings, props and ground blobs.
## All art is the CC0 Ninja Adventure pack. Coordinates are in 16px cells of each sheet.

const BASE := "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Backgrounds/Tilesets/"

const TEXTURES := {
	&"house": BASE + "TilesetHouse.png",
	&"nature": BASE + "TilesetNature.png",
	&"element": BASE + "TilesetElement.png",
	&"floor": BASE + "TilesetFloor.png",
	&"water": BASE + "TilesetWater.png",
	&"field": BASE + "TilesetField.png",
}

## Grid letter -> building. rect = sheet region in cells (x, y, w, h); door = door column offset
## inside the rect (the door is on the bottom row); solid = bottom rows that block movement
## (rows above stay walkable, so the player passes behind the roof); place = Places id.
const BUILDINGS := {
	"M": {"name": "Manor", "place": &"manor", "tex": &"house", "rect": Rect2i(29, 0, 4, 4), "door": 1, "solid": 4},
	"H": {"name": "Church", "place": &"church", "tex": &"house", "rect": Rect2i(25, 7, 4, 7), "door": 1, "solid": 5},
	"A": {"name": "Alehouse", "place": &"alehouse", "tex": &"house", "rect": Rect2i(19, 0, 4, 3), "door": 2, "solid": 3},
	"K": {"name": "Chandlery", "place": &"chandlery", "tex": &"house", "rect": Rect2i(16, 0, 3, 3), "door": 1, "solid": 3},
	"S": {"name": "Smithy", "place": &"smithy", "tex": &"house", "rect": Rect2i(23, 0, 3, 3), "door": 1, "solid": 3},
	"1": {"name": "CottageOne", "place": &"", "tex": &"house", "rect": Rect2i(0, 0, 4, 3), "door": 1, "solid": 3},
	"2": {"name": "CottageTwo", "place": &"", "tex": &"house", "rect": Rect2i(8, 0, 4, 3), "door": 1, "solid": 3},
	"3": {"name": "CottageThree", "place": &"", "tex": &"house", "rect": Rect2i(26, 0, 3, 3), "door": 1, "solid": 3},
	"L": {"name": "Mill", "place": &"mill", "tex": &"house", "rect": Rect2i(25, 14, 4, 5), "door": 1, "solid": 4},
	"U": {"name": "ShepherdHut", "place": &"shepherd_hut", "tex": &"house", "rect": Rect2i(3, 8, 3, 2), "door": 1, "solid": 2},
}

## Grid char -> prop sprite. anchor "bl" = char is the bottom-left cell, "bc" = bottom-centre.
## foot = solid footprint in cells (w, h) from the anchor cell, extending right and up.
const PROPS := {
	"t": {"name": "Tree", "tex": &"nature", "rect": Rect2i(0, 0, 2, 2), "anchor": "bl", "foot": Vector2i(2, 1)},
	"T": {"name": "BigTree", "tex": &"nature", "rect": Rect2i(3, 18, 3, 3), "anchor": "bc", "foot": Vector2i(1, 1)},
	"b": {"name": "Barrel", "tex": &"house", "rect": Rect2i(16, 15, 1, 1), "anchor": "bl", "foot": Vector2i(1, 1)},
	"c": {"name": "Crate", "tex": &"house", "rect": Rect2i(19, 15, 1, 1), "anchor": "bl", "foot": Vector2i(1, 1)},
	"e": {"name": "Stall", "tex": &"house", "rect": Rect2i(16, 16, 3, 2), "anchor": "bl", "foot": Vector2i(3, 1)},
	"x": {"name": "MarketCross", "tex": &"nature", "rect": Rect2i(16, 8, 2, 2), "anchor": "bc", "foot": Vector2i(1, 1),
		"over": {"tex": &"element", "rect": Rect2i(3, 2, 1, 1), "dy": -21}},
	"g": {"name": "Grave", "tex": &"element", "rect": Rect2i(4, 2, 1, 1), "anchor": "bl", "foot": Vector2i(1, 1)},
	"k": {"name": "Cross", "tex": &"element", "rect": Rect2i(3, 2, 1, 1), "anchor": "bl", "foot": Vector2i(1, 1)},
	"w": {"name": "Well", "tex": &"element", "rect": Rect2i(6, 1, 1, 1), "anchor": "bl", "foot": Vector2i(1, 1)},
}

## Flower / tuft decor tiles scattered on 'f' cells (nature sheet).
const FLOWER_TILES: Array[Vector2i] = [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11)]

## Plain grass (floor sheet) and its rarer tufted variants.
const GRASS_TILE := Vector2i(11, 12)
const GRASS_VARIANTS: Array[Vector2i] = [Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12), Vector2i(15, 12)]

## Sea fill under and around the village.
const SEA_COLOR := Color8(155, 211, 196)  ## Raw colour; the level modulate turns it into the farm sea colour.
const LILY_TILE := Vector2i(11, 3)  ## lily pad drawn on pond cells marked l.

## 3x3 "blob" tile groups: origin of the top-left corner piece of the 9-piece set.
## caps: vertical strip is at origin + (3, 0..2) and horizontal strip at origin + (0..2, 3).
const COAST_BLOB := {"tex": &"field", "origin": Vector2i(0, 6)}
const DIRT_BLOB := {"tex": &"floor", "origin": Vector2i(11, 7)}

## Fence pieces (house sheet): horizontal rail and vertical rail.
const FENCE_H := Vector2i(11, 7)
const FENCE_V := Vector2i(11, 6)

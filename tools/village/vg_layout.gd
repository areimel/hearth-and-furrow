extends RefCounted
## Village layout as a character grid (one char per 16px cell) plus its legend.
## Edit the grid, then re-run `tools/bake_village.gd` to regenerate scenes/world/village.tscn.
##
## Ground chars:  .  grass     ,  dirt path / plaza     ~  pond (solid)     #  fence (solid)
## Prop chars (anchor cell; sprite sizes live in vg_data.gd):
##   t small tree (anchor bottom-left)   T big tree (anchor bottom-centre)   f flowers
##   g gravestone   k grave cross   l lily pad (pond)
##   b barrel   c crate   e market stall (anchor bottom-left)   x market cross
## Building chars: each letter block is one building, see VgData.BUILDINGS.
## The outer ring (row 0, last row, last column) is the coast: drawn, but never walkable.

## World cell of grid[0][0]; x = 29 is the farm island's east shore column.
const ORIGIN := Vector2i(29, -14)

## Grid rows (inclusive) where the farm island continues west of column 0 (no shore drawn there).
const FARM_ROWS := Vector2i(0, 28)

## Farm WaterGrassLayer cells to erase so the gate is walkable (the island's shore tiles collide).
const FARM_GAP: Array[Vector2i] = [Vector2i(29, -1), Vector2i(29, 0)]

const GRID: PackedStringArray = [
	".................HHHH.....................",
	"#................HHHH.....................",
	"#..f.............HHHH.....................",
	"#....fMMMM....t..HHHHk.t..................",
	"#.....MMMM.......HHHH.g..AAAA...KKK..SSS..",
	"#t....MMMM.....f.HHHHf.g.AAAA...KKK..SSS..",
	"#.....MMMM..t....HHHH.t.bAAAAbtbKKKbcSSSb.",
	"#..,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.",
	"#..,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.",
	"#..,,....ff.........,,.........t......t...",
	"#.t,,...f..t....t...,,..f.....cf....f.....",
	"#..,,..T.....f......,,...f.1111..333.2222.",
	"#..,,...........f.ooooo....1111..333.2222.",
	",,,,,,,,,,,,,,,,,,ooooo.e..1111..333.2222.",
	",,,,,,,,,,,,,,,,,,ooxoo,,,,,,,,,,,,,,,,,,.",
	"#.................ooooo,,,,,,,,,,,,,,,,,,.",
	"#.f.....f.........ooooo..w.......f.....f..",
	"#......f..f...e.....,,........f...f...f...",
	"#....t..............,,..f...t..f.f..f.....",
	"#.......,,,,,,,,,,,,,,.f..................",
	"#.......,,,,,,,,,,,,,,.....~~l~~~~........",
	"#.......,,..........,,....f~~~~~~~.LLLL...",
	"#..#####..#####.....,,...f.~~~~~~~.LLLL...",
	"#..#........f.#.....,,.....~~~~~~~.LLLL...",
	"#..#.f........#.T...,,.....~~~~l~~.LLLL...",
	"#..#......UUU.#.....,,............bLLLL...",
	"#..#...f..UUU.#.....,,,,,,,,,,,,,,,,,,....",
	"#..#..........#.....,,,,,,,,,,,,,,,,,,....",
	"#..#..........#...........................",
	"#..############...........................",
	"#.............................T.......T...",
	"..........................................",
]

## Place id -> grid cell (col, row) for places that are not a building door.
const PLACE_CELLS := {
	&"village_green": Vector2i(24, 17),
	&"market_cross": Vector2i(20, 16),
	&"pasture": Vector2i(6, 25),
	&"farm_gate": Vector2i(0, 13),
	&"feast_ground": Vector2i(24, 20),
}

## Feast gathering spots relative to feast_ground (cells), spot_1..8.
const FEAST_SPOTS: Array[Vector2i] = [
	Vector2i(-2, -2), Vector2i(0, -2), Vector2i(2, -2), Vector2i(2, 0),
	Vector2i(2, 2), Vector2i(0, 2), Vector2i(-2, 2), Vector2i(-2, 0),
]

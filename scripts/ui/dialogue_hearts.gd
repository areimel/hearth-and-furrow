class_name DialogueHearts extends Control
## Row of small pixel hearts showing friendship: `hearts` of Balance.MAX_HEARTS are filled.
## Drawn in code so no art is needed; colours come from UIPalette.

const SHAPE: Array[String] = [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]
const GAP: int = 1

## Filled hearts, 0..Balance.MAX_HEARTS.
var hearts: int = 0:
	set(value):
		hearts = clampi(value, 0, Balance.MAX_HEARTS)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := SHAPE[0].length()
	custom_minimum_size = Vector2(Balance.MAX_HEARTS * (width + GAP) - GAP, SHAPE.size())
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var width := SHAPE[0].length()
	for i in Balance.MAX_HEARTS:
		var color := UIPalette.CRIMSON if i < hearts else UIPalette.PARCHMENT_DARK
		for y in SHAPE.size():
			for x in width:
				if SHAPE[y][x] == "X":
					draw_rect(Rect2(i * (width + GAP) + x, y, 1, 1), color)

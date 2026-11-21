class_name Placeable extends StaticBody2D
## Base for anything built on the farm grid in build mode (stations, coops,
## fences, ...). Follows the setup() convention: position itself, add itself to
## `parent`, and register with the level's FarmGrid. Frees itself on remove()
## and releases its cell whenever it leaves the tree.

var coord: Vector2i
var grid: FarmGrid


## Place at `grid_coord` under `parent` and claim the cell. Subclasses override
## to wire their own signals, then call super().
func setup(grid_coord: Vector2i, level: Level, parent: Node) -> void:
	coord = grid_coord
	grid = level.farm_grid
	position = Vector2(grid_coord * Balance.TILE_SIZE)
	parent.add_child(self)
	grid.occupy(coord, self)


## Remove from the world (the cell is released on exit_tree).
func remove() -> void:
	queue_free()


func _exit_tree() -> void:
	if grid and grid.occupant(coord) == self:
		grid.release(coord)

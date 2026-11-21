extends TestCase

const Balance := preload("res://data/balance.gd")
## Proves the runner works and the project's autoloads are reachable from tests.


func test_autoloads_are_available() -> void:
	check(tree.root.has_node("Content"), "Content autoload missing")
	eq(Balance.TILE_SIZE, 16, "tile size")

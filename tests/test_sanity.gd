extends TestCase
## Proves the runner works and the project's autoloads are reachable from tests.


func test_autoloads_are_available() -> void:
	check(tree.root.has_node("Data"), "Data autoload missing")
	eq(Data.TILE_SIZE, 16, "tile size")

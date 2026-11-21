extends RefCounted
## Tool tier rows. Keys: name, rank, next (tier upgraded to), coins and items (cost to
## upgrade TO this tier at the blacksmith), unlock (Progress flag), area, power.

const ROWS: Dictionary = {
	&"wooden": {name = "Wooden", rank = 1, next = &"iron_shod", area = 1, power = 1.0},
	&"iron_shod": {name = "Iron-shod", rank = 2, coins = 250, items = {&"log": 5},
		area = 2, power = 1.5},
}

## Tool kinds that exist in every tier (one item per kind x tier).
const TOOL_KINDS: Array[int] = [
	G.ToolKind.AXE, G.ToolKind.HOE, G.ToolKind.WATERING_CAN, G.ToolKind.SICKLE,
	G.ToolKind.FISHING_ROD,
]

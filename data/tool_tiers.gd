extends RefCounted
## Tool tier rows. Keys: name, rank, next (tier upgraded to), coins and items (cost to
## upgrade TO this tier at the blacksmith), unlock (Progress flag), area (cells per swing for
## the kinds in AREA_KINDS), power (axe damage per hit), bonus_logs (extra logs per felled
## tree), fishing_ease (multiplier on the fishing minigame's catch speed, divides its lose speed).

const ROWS: Dictionary = {
	&"wooden": {name = "Wooden", rank = 1, next = &"iron_shod", area = 1, power = 1.0, bonus_logs = 0, fishing_ease = 1.0},
	&"iron_shod": {name = "Iron-shod", rank = 2, coins = 550, items = {&"log": 5, &"stone": 3},
		area = 2, power = 1.5, bonus_logs = 1, fishing_ease = 1.35},
}

## Tool kinds that exist in every tier (one item per kind x tier).
const TOOL_KINDS: Array[int] = [
	G.ToolKind.AXE, G.ToolKind.HOE, G.ToolKind.WATERING_CAN, G.ToolKind.SICKLE,
	G.ToolKind.FISHING_ROD,
]

## Tool kinds whose swing covers `area` cells in a line (the facing direction).
const AREA_KINDS: Array[int] = [G.ToolKind.HOE, G.ToolKind.WATERING_CAN, G.ToolKind.SICKLE]

class_name GatherableData extends Resource
## A kind of world node the player gathers raw materials from (hazel coppice, bramble,
## stone outcrop, clay pit, reed bed). Built from data/gatherables.gd by Content.

## Placement rule: any free, dry cell.
const PLACE_ANY_GRASS := &"any_grass"
## Placement rule: a dry cell orthogonally next to water.
const PLACE_NEAR_WATER := &"near_water"

## Unique id, e.g. &"bramble".
@export var id: StringName
@export var display_name: String
## Prompt text while ready, e.g. "Pick berries".
@export var verb: String = "Gather"
## Yield rows: {item: StringName, min: int, max: int, seasons: Array (empty = any),
## from_day: int (optional, first day of the season the yield is available)}.
@export var yields: Array[Dictionary] = []
## Days after gathering until the node is ready again.
@export var regrow_days: int = 3
## Tool needed to gather (G.ToolKind), NONE for bare hands.
@export var tool_kind: int = G.ToolKind.NONE
## Whether the node blocks movement.
@export var blocks_movement: bool = true
## PLACE_ANY_GRASS or PLACE_NEAR_WATER.
@export var placement: StringName = PLACE_ANY_GRASS
## Nodes scattered on a new game.
@export var scatter_count: int = 0
@export var full_path: String
@export var empty_path: String
## Sprite while ready (placeholder if missing).
@export var full_texture: Texture2D
## Sprite while depleted or nothing is ripe.
@export var empty_texture: Texture2D


## Yield rows available in `season` on `day_of_season` (1..28).
func yields_for(season: int, day_of_season: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in yields:
		var seasons: Array = row.get("seasons", [])
		if not seasons.is_empty() and not season in seasons:
			continue
		if day_of_season < int(row.get("from_day", 1)):
			continue
		out.append(row)
	return out


## True if bare hands are not enough.
func needs_tool() -> bool:
	return tool_kind != G.ToolKind.NONE

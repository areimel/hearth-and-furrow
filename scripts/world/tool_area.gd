class_name ToolArea extends RefCounted
## Which cells one tool swing covers. The tool's tier row decides how many cells in a
## line (`ToolTierData.area`), but only for the kinds listed in ToolTiers.AREA_KINDS.

const ToolTiers := preload("res://data/tool_tiers.gd")


## Cells a swing of `action` with `tier` covers, starting at `origin` and continuing in
## `step` (the facing direction as a cell offset). `tier` may be null (single cell).
static func cells(action: int, tier: ToolTierData, origin: Vector2i, step: Vector2i) -> Array[Vector2i]:
	var count := 1
	if tier != null and action in ToolTiers.AREA_KINDS:
		count = maxi(tier.area, 1)
	var out: Array[Vector2i] = []
	for i in count:
		out.append(origin + step * i)
	return out

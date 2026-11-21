class_name PlayerActions extends RefCounted
## What the action button does for the selected hotbar item. Tools map to their
## G.ToolKind; seeds are a pseudo action (SOW). One table maps every action to its
## animation state in the player's ToolStateMachine and to its sound node.

## Seeds sow a crop. Not a G.ToolKind (those are tool items); never stored or saved.
const SOW: int = -1

## Action -> state name in the AnimationTree's ToolStateMachine. The legacy
## "Sword" animation is the sickle's reaping swing.
const ANIMATIONS: Dictionary = {
	G.ToolKind.HOE: &"Hoe",
	G.ToolKind.AXE: &"Axe",
	G.ToolKind.WATERING_CAN: &"Water",
	G.ToolKind.SICKLE: &"Sword",
	G.ToolKind.FISHING_ROD: &"Fish",
	SOW: &"Seed",
}

## Action -> child of the player's `Sounds` node played when the swing lands.
const SOUNDS: Dictionary = {
	G.ToolKind.HOE: &"Hoe",
	G.ToolKind.AXE: &"Axe",
	G.ToolKind.WATERING_CAN: &"Water",
	G.ToolKind.SICKLE: &"Axe",
	G.ToolKind.FISHING_ROD: &"Fish",
}


## The ToolTierData of a tool item, or null for anything else.
static func tier_of(item: ItemData) -> ToolTierData:
	if item == null or not item.is_tool() or item.tool_tier.is_empty():
		return null
	return Content.tool_tier(item.tool_tier)


## The action `item` performs: its G.ToolKind, SOW for a seed, else G.ToolKind.NONE.
static func for_item(item: ItemData) -> int:
	if item == null:
		return G.ToolKind.NONE
	if item.is_tool():
		return item.tool_kind
	if item.is_seed() and Content.crop_for_seed(item.id) != null:
		return SOW
	return G.ToolKind.NONE

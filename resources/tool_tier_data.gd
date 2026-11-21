class_name ToolTierData extends Resource
## A tool tier (wooden, iron-shod). Tool items reference it by id via ItemData.tool_tier.

## Unique tier id, e.g. &"iron_shod".
@export var id: StringName
@export var display_name: String
## 1-based rank; higher is better.
@export var rank: int = 1
## Tier the blacksmith upgrades this one to; empty = top tier.
@export var next_tier: StringName
## Coins the blacksmith charges to upgrade a tool TO this tier.
@export var upgrade_coins: int = 0
## Items consumed to upgrade a tool TO this tier.
@export var upgrade_items: Dictionary[StringName, int] = {}
## Progress flag required before the upgrade is offered; empty = always.
@export var unlock_flag: StringName
## Tiles affected per use (1 = single tile).
@export var area: int = 1
## Multiplier on tool animation speed / chopping power.
@export var power: float = 1.0
## Extra logs a felled tree gives with an axe of this tier.
@export var bonus_logs: int = 0
## Fishing minigame forgiveness: catch speed is multiplied and lose speed divided by this.
@export var fishing_ease: float = 1.0

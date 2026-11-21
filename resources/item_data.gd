class_name ItemData extends Resource
## One kind of inventory item. Built by Content from data/items_*.gd; never edit at runtime.

## Unique id, e.g. &"wheat_sheaf".
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## One-line flavour/help text.
@export var description: String
## G.ItemCategory value.
@export var category: int = G.ItemCategory.MATERIAL
## Price a shop pays and charges, in coins. 0 = cannot be sold or bought.
@export var base_price: int = 0
## Max items per inventory slot (1 for tools, Balance.STACK_SIZE otherwise).
@export var stack_size: int = 99
## G.ToolKind for tools, G.ToolKind.NONE otherwise.
@export var tool_kind: int = G.ToolKind.NONE
## ToolTierData id for tools (&"wooden", &"iron_shod"); empty otherwise.
@export var tool_tier: StringName
## Backpack slots gained when this item is used (linen sack = 6); 0 otherwise.
@export var backpack_slots: int = 0
## Free-form tags for filtering, e.g. &"grain". See Content.items_with_tag().
@export var tags: Array[StringName] = []
## Source path of the icon (kept for validation and placeholder regeneration).
@export var icon_path: String
## Loaded icon; a magenta placeholder if icon_path is missing.
@export var icon: Texture2D


func is_tool() -> bool:
	return tool_kind != G.ToolKind.NONE


func is_seed() -> bool:
	return category == G.ItemCategory.SEED


## Tools and upgrades are not gifts; everything else may be offered.
func is_giftable() -> bool:
	return category != G.ItemCategory.TOOL and category != G.ItemCategory.UPGRADE


func is_sellable() -> bool:
	return base_price > 0

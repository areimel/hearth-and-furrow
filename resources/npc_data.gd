class_name NPCData extends Resource
## A villager: identity, gift preferences, shop stock and daily schedule.

## Unique npc id, e.g. &"miller".
@export var id: StringName
@export var display_name: String
## Short role shown in the relationships tab, e.g. "Miller".
@export var role: String
## Item ids this villager loves / likes / dislikes as gifts. Anything else is neutral.
@export var loved_gifts: Array[StringName] = []
@export var liked_gifts: Array[StringName] = []
@export var disliked_gifts: Array[StringName] = []
## Item or animal ids this villager sells; empty = not a shop. Prices come from Economy.
@export var shop_stock: Array[StringName] = []
## Buys any sellable item from the player when true.
@export var buys_items: bool = false
@export var schedule: Array[NPCScheduleEntry] = []
@export var sprite_path: String
@export var faceset_path: String
## Loaded textures (placeholder if missing).
@export var sprite: Texture2D
@export var faceset: Texture2D


## G.GiftReaction for an item, ignoring the once-a-day rule.
func reaction_to(item_id: StringName) -> int:
	if item_id in loved_gifts:
		return G.GiftReaction.LOVED
	if item_id in liked_gifts:
		return G.GiftReaction.LIKED
	if item_id in disliked_gifts:
		return G.GiftReaction.DISLIKED
	return G.GiftReaction.NEUTRAL


## Where the villager should be; empty StringName if no entry matches.
func location_at(hour: int, weekday: int, season: int, raining: bool) -> StringName:
	for rain_pass: bool in ([true, false] if raining else [false]):
		var best: NPCScheduleEntry = null
		for entry in schedule:
			if entry.rain_only != rain_pass or entry.start_hour > hour:
				continue
			if not entry.matches(weekday, season, raining):
				continue
			if best == null or entry.start_hour >= best.start_hour:
				best = entry
		if best != null:
			return best.location
	return &""

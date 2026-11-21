class_name QuestData extends Resource
## A quest: who gives it, what unlocks it, what it asks and what it pays.
## Dialogue for it lives in data/dialogue_quests.gd under the same id.

## Unique quest id, e.g. &"prologue".
@export var id: StringName
@export var title: String
@export var description: String
## NPC id that offers the quest; empty for story quests.
@export var giver: StringName
## Quest ids that must be complete before this can start.
@export var requires: Array[StringName] = []
## All must hold for the quest to be completable.
@export var conditions: Array[QuestCondition] = []
@export var rewards: Array[QuestReward] = []
## Conditions are steps done in order: only the current one is tracked, and a finished
## step stays finished (item conditions excepted). QuestManager.current_step() tells
## which; a Journal shows steps up to the current one.
@export var sequential: bool = false
## Started by itself as soon as can_start() (the prologue), not offered by the giver.
@export var auto_start: bool = false
## Almanack note: one or two plain sentences of history behind the quest.
@export var note: String
## Production chain the quest teaches (a data/recipes.gd CHAINS key), or empty.
@export var chain: StringName
## Crop ids whose harvest the quest needs; when none grows this season the giver says
## when to come back (data/dialogue_quests.gd `out_of_season`).
@export var crops: Array[StringName] = []
## Daily favour the giver offers once the quest is complete: dialogue option text,
## items handed over and items taken in exchange. Empty `perk_text` = no favour.
@export var perk_text: String
@export var perk_gives: Dictionary[StringName, int] = {}
@export var perk_takes: Dictionary[StringName, int] = {}


## True if completing this quest unlocks a daily favour.
func has_perk() -> bool:
	return not perk_text.is_empty() and not perk_gives.is_empty()

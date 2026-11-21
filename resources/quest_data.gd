class_name QuestData extends Resource
## A quest: who gives it, what unlocks it, what it asks and what it pays.

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

class_name QuestReward extends Resource
## One reward granted when a quest completes.

## `amount` coins (target ignored).
const COINS: StringName = &"coins"
## `amount` of item `target`.
const ITEM: StringName = &"item"
## Sets progress flag `target` (unlocks recipes, tool tiers, quests).
const FLAG: StringName = &"flag"
## `amount` friendship points with npc `target`.
const FRIENDSHIP: StringName = &"friendship"

const KINDS: Array[StringName] = [COINS, ITEM, FLAG, FRIENDSHIP]

@export var kind: StringName
@export var target: StringName
@export var amount: int = 1

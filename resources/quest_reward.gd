class_name QuestReward extends Resource
## One reward granted when a quest completes (or a feast tier is reached).
## QuestManager.grant() applies it.

## `amount` coins (target ignored).
const COINS: StringName = &"coins"
## `amount` of item `target`.
const ITEM: StringName = &"item"
## Sets progress flag `target` (unlocks recipes, tool tiers, quests).
const FLAG: StringName = &"flag"
## `amount` friendship points with npc `target`.
const FRIENDSHIP: StringName = &"friendship"
## `amount` friendship points with every villager (at a feast: everyone present).
const FRIENDSHIP_ALL: StringName = &"friendship_all"

const KINDS: Array[StringName] = [COINS, ITEM, FLAG, FRIENDSHIP, FRIENDSHIP_ALL]

@export var kind: StringName
@export var target: StringName
@export var amount: int = 1
## Optional player-facing text; replaces describe()'s default (e.g. for a flag).
@export var text: String


## Short player-facing description, e.g. "50 coins", "6 Seed Barley",
## "Friendship: Ned Miller". Flags without `text` describe as "" (hidden).
func describe() -> String:
	if not text.is_empty():
		return text
	match kind:
		COINS:
			return "%d coins" % amount
		ITEM:
			var item := Content.item(target) if Content.has_item(target) else null
			var name := item.display_name if item else String(target)
			return name if amount == 1 else "%d %s" % [amount, name]
		FRIENDSHIP:
			var npc := Content.npc(target)
			return "Friendship: %s" % (npc.display_name if npc else String(target))
		FRIENDSHIP_ALL:
			return "Friendship with all"
	return ""

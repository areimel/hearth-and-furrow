class_name QuestCondition extends Resource
## One objective of a quest. `kind` decides how `target` and `amount` are read.

## Have `amount` of item `target` in the inventory (not consumed).
const HAVE_ITEM: StringName = &"have_item"
## Hand over `amount` of item `target`; removed from the inventory on completion.
const DELIVER_ITEM: StringName = &"deliver_item"
## Progress flag `target` is set (amount ignored).
const FLAG: StringName = &"flag"
## Progress counter `target` (e.g. &"crafted.bread") >= amount.
const COUNTER: StringName = &"counter"
## Talked to npc `target` at least once (amount ignored).
const TALK_TO: StringName = &"talk_to"
## Hearts with npc `target` >= amount.
const HEARTS: StringName = &"hearts"

const KINDS: Array[StringName] = [HAVE_ITEM, DELIVER_ITEM, FLAG, COUNTER, TALK_TO, HEARTS]

## One of the constants above.
@export var kind: StringName
## Item, flag, counter or npc id, depending on kind.
@export var target: StringName
@export var amount: int = 1
## Player-facing objective text, e.g. "Bring Ned 5 wheat sheaves".
@export var text: String

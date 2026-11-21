class_name QuestCondition extends Resource
## One objective of a quest (or one ask of a feast). `kind` decides how `target`,
## `targets` and `amount` are read.

## Have `amount` of item `target` in the inventory (not consumed).
const HAVE_ITEM: StringName = &"have_item"
## Hand over `amount` of item `target`; removed from the inventory on completion.
## A feast ask uses this kind with `targets`: any of those items counts.
const DELIVER_ITEM: StringName = &"deliver_item"
## Progress flag `target` is set (amount ignored).
const FLAG: StringName = &"flag"
## Progress counter `target` (e.g. &"crafted.bread") >= amount. With `targets`, the sum
## of those counters counts instead (e.g. any harvest).
const COUNTER: StringName = &"counter"
## Talked to npc `target` at least once (amount ignored).
const TALK_TO: StringName = &"talk_to"
## Hearts with npc `target` >= amount.
const HEARTS: StringName = &"hearts"
## Has met (talked to or gifted) at least `amount` different villagers (target ignored).
const MET: StringName = &"met"
## At least `amount` days have begun since the quest started (since the step started,
## in a sequential quest). Target ignored.
const DAYS: StringName = &"days"
## The number a world probe reports, e.g. &"sown.wheat" (crops of that kind standing in
## the field). Probes are registered with QuestManager.register_probe() by scene code;
## an unregistered probe reads 0.
const PROBE: StringName = &"probe"

const KINDS: Array[StringName] = [HAVE_ITEM, DELIVER_ITEM, FLAG, COUNTER, TALK_TO, HEARTS,
	MET, DAYS, PROBE]
## Kinds whose progress is read from the Inventory (never latched by sequential quests).
const ITEM_KINDS: Array[StringName] = [HAVE_ITEM, DELIVER_ITEM]

## One of the constants above.
@export var kind: StringName
## Item, flag, counter, npc or probe id, depending on kind.
@export var target: StringName
## Alternatives to `target` (COUNTER: summed counters; feast asks: accepted items).
@export var targets: Array[StringName] = []
@export var amount: int = 1
## Player-facing objective text, e.g. "Bring Ned 5 wheat sheaves".
@export var text: String


## Every id this condition reads: `target` (if set) followed by `targets`.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if not target.is_empty():
		out.append(target)
	for id in targets:
		if not id in out:
			out.append(id)
	return out


## True if item `item_id` counts towards this condition (feast asks, deliveries).
func accepts(item_id: StringName) -> bool:
	return item_id in ids()

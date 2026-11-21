class_name QuestText extends RefCounted
## Turns QuestData into readable lines for the journal, driven by the condition kind:
## nothing here names a particular quest.

## Fallback wording per QuestCondition kind when a condition has no text of its own.
const FALLBACKS: Dictionary = {
	QuestCondition.HAVE_ITEM: "Have %d x %s",
	QuestCondition.DELIVER_ITEM: "Bring %d x %s",
	QuestCondition.FLAG: "%s",
	QuestCondition.COUNTER: "%s (%d)",
	QuestCondition.TALK_TO: "Speak with %s",
	QuestCondition.HEARTS: "Reach %d hearts with %s",
}
## Kinds whose progress is a count worth showing as "3/5".
const COUNTED: Array[StringName] = [
	QuestCondition.HAVE_ITEM, QuestCondition.DELIVER_ITEM, QuestCondition.COUNTER,
	QuestCondition.HEARTS,
]


## Objectives of a quest as [{text, done, progress}]; progress is "3/5" or "".
## Completed quests report every objective done.
static func objectives(quest_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var quest := Content.quest(quest_id)
	if quest == null:
		return out
	var complete := QuestManager.is_complete(quest_id)
	for i in quest.conditions.size():
		var cond := quest.conditions[i]
		var needed := required(cond)
		var have := needed if complete else QuestManager.condition_progress(quest_id, i)
		out.append({
			"text": cond.text if cond.text != "" else _fallback(cond),
			"done": have >= needed,
			"progress": "%d/%d" % [have, needed] if cond.kind in COUNTED and needed > 1 else "",
		})
	return out


## Amount a condition needs (1 for the yes/no kinds).
static func required(cond: QuestCondition) -> int:
	return maxi(cond.amount, 1) if cond.kind in COUNTED else 1


## "Reward: 80 coins, 3 Barm" from the quest's coin and item rewards ("" if none).
static func reward_line(quest: QuestData) -> String:
	var parts: Array[String] = []
	for reward in quest.rewards:
		if reward.kind == QuestReward.COINS:
			parts.append("%d coins" % reward.amount)
		elif reward.kind == QuestReward.ITEM and Content.has_item(reward.target):
			parts.append("%d %s" % [reward.amount, Content.item(reward.target).display_name])
	return "Reward: " + ", ".join(parts) if not parts.is_empty() else ""


## Display name of an NPC id ("" for none).
static func giver_name(npc_id: StringName) -> String:
	var npc := Content.npc(npc_id) if not npc_id.is_empty() else null
	return npc.display_name if npc else ""


static func _fallback(cond: QuestCondition) -> String:
	var template: String = FALLBACKS.get(cond.kind, "%s")
	var label := _target_name(cond)
	match cond.kind:
		QuestCondition.HAVE_ITEM, QuestCondition.DELIVER_ITEM, QuestCondition.HEARTS:
			return template % [cond.amount, label]
		QuestCondition.COUNTER:
			return template % [label, cond.amount]
	return template % label


static func _target_name(cond: QuestCondition) -> String:
	match cond.kind:
		QuestCondition.HAVE_ITEM, QuestCondition.DELIVER_ITEM:
			return Content.item(cond.target).display_name if Content.has_item(cond.target) else String(cond.target)
		QuestCondition.TALK_TO, QuestCondition.HEARTS:
			var npc_name := giver_name(cond.target)
			return npc_name if npc_name != "" else String(cond.target)
	return String(cond.target).replace("_", " ")

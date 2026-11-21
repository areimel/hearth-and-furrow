class_name QuestText extends RefCounted
## Turns QuestData into readable lines for the journal. Progress comes from QuestManager
## (condition_progress / condition_required / current_step); nothing here names a quest.


## Objectives of a quest as [{text, done, progress}]; progress is "3/5" when more than one
## is needed, else "". A sequential quest lists only its steps up to the current one
## (earlier ticked, the current live); a completed quest lists everything done.
static func objectives(quest_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var quest := Content.quest(quest_id)
	if quest == null:
		return out
	var shown := quest.conditions.size()
	if quest.sequential and not QuestManager.is_complete(quest_id):
		shown = mini(QuestManager.current_step(quest_id) + 1, shown)
	for i in shown:
		var needed := QuestManager.condition_required(quest_id, i)
		var have := QuestManager.condition_progress(quest_id, i)
		out.append({
			"text": quest.conditions[i].text,
			"done": have >= needed,
			"progress": "%d/%d" % [have, needed] if needed > 1 else "",
		})
	return out


## "Reward: 50 coins, 6 Seed Barley" from the quest's rewards ("" if none are visible).
static func reward_line(quest: QuestData) -> String:
	var parts: Array[String] = []
	for reward in quest.rewards:
		if not reward.describe().is_empty():
			parts.append(reward.describe())
	return "Reward: " + ", ".join(parts) if not parts.is_empty() else ""


## Display name of an NPC id ("" for none).
static func giver_name(npc_id: StringName) -> String:
	var npc := Content.npc(npc_id) if not npc_id.is_empty() else null
	return npc.display_name if npc else ""

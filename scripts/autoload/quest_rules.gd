extends RefCounted
## Pure rules behind QuestManager: how much a condition requires, how far along it is,
## and how a reward is applied. Static; QuestManager is the only caller.


## Required value of a condition (1 for flags and talks).
static func required(cond: QuestCondition) -> int:
	match cond.kind:
		QuestCondition.FLAG, QuestCondition.TALK_TO:
			return 1
	return cond.amount


## Uncapped progress of `cond`. `since_day` is the day DAYS conditions count from;
## `probes` maps probe keys to Callables returning ints.
static func progress(cond: QuestCondition, since_day: int, probes: Dictionary) -> int:
	match cond.kind:
		QuestCondition.HAVE_ITEM, QuestCondition.DELIVER_ITEM:
			return Inventory.count(cond.target)
		QuestCondition.FLAG:
			return 1 if Progress.has_flag(cond.target) else 0
		QuestCondition.COUNTER:
			var total := 0
			for key in cond.ids():
				total += Progress.count(key)
			return total
		QuestCondition.TALK_TO:
			return 1 if Relationships.has_met(cond.target) else 0
		QuestCondition.HEARTS:
			return Relationships.hearts(cond.target)
		QuestCondition.MET:
			return Content.npcs().filter(
					func(n: NPCData) -> bool: return Relationships.has_met(n.id)).size()
		QuestCondition.DAYS:
			return maxi(0, GameClock.day_index - since_day)
		QuestCondition.PROBE:
			var probe: Callable = probes.get(cond.target, Callable())
			return int(probe.call()) if probe.is_valid() else 0
	return 0


## Apply one reward. FRIENDSHIP_ALL goes to `npc_ids` (empty: every villager). Item rewards
## go through Loot (toast, no Progress verb); what does not fit in a full pack is lost.
static func grant(tree: SceneTree, reward: QuestReward, npc_ids: Array[StringName]) -> void:
	match reward.kind:
		QuestReward.COINS:
			Economy.add_coins(reward.amount)
		QuestReward.ITEM:
			Loot.give(tree, reward.target, reward.amount, &"")
		QuestReward.FLAG:
			Progress.set_flag(reward.target)
		QuestReward.FRIENDSHIP:
			Relationships.add_points(reward.target, reward.amount)
		QuestReward.FRIENDSHIP_ALL:
			var ids: Array[StringName] = npc_ids.duplicate()
			if ids.is_empty():
				for npc in Content.npcs():
					ids.append(npc.id)
			for id in ids:
				Relationships.add_points(id, reward.amount)

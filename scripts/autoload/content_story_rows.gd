extends RefCounted
## Quest and festival row -> resource builders (no textures involved). Used by ContentBuilder.


static func quest(id: StringName, row: Dictionary) -> QuestData:
	var res := QuestData.new()
	res.id = id
	res.title = row.get("title", String(id))
	res.description = row.get("desc", "")
	res.giver = row.get("giver", &"")
	res.requires.assign(row.get("requires", []))
	for c: Dictionary in row.get("conditions", []):
		res.conditions.append(condition(c))
	res.rewards.assign(rewards(row.get("rewards", [])))
	res.sequential = row.get("sequential", false)
	res.auto_start = row.get("auto", false)
	res.note = row.get("note", "")
	res.chain = row.get("chain", &"")
	res.crops.assign(row.get("crops", []))
	var perk: Dictionary = row.get("perk", {})
	res.perk_text = perk.get("text", "")
	res.perk_gives.assign(perk.get("gives", {}))
	res.perk_takes.assign(perk.get("takes", {}))
	return res


## A QuestCondition from {kind, target, targets, amount, text}.
static func condition(c: Dictionary) -> QuestCondition:
	var cond := QuestCondition.new()
	cond.kind = c.get("kind", &"")
	cond.target = c.get("target", &"")
	cond.targets.assign(c.get("targets", []))
	cond.amount = c.get("amount", 1)
	cond.text = c.get("text", "")
	return cond


## QuestRewards from [{kind, target, amount, text}].
static func rewards(rows: Array) -> Array[QuestReward]:
	var out: Array[QuestReward] = []
	for r: Dictionary in rows:
		var reward := QuestReward.new()
		reward.kind = r.get("kind", &"")
		reward.target = r.get("target", &"")
		reward.amount = r.get("amount", 1)
		reward.text = r.get("text", "")
		out.append(reward)
	return out


static func festival(id: StringName, row: Dictionary) -> FestivalData:
	var res := FestivalData.new()
	res.id = id
	res.display_name = row.get("name", String(id))
	res.description = row.get("desc", "")
	res.season = row.get("season", G.Season.SPRING)
	res.day = row.get("day", 1)
	res.location = row.get("loc", &"")
	res.start_hour = row.get("start", 9)
	res.end_hour = row.get("end", 18)
	res.shops_closed = row.get("shops_closed", true)
	res.note = row.get("note", "")
	res.gather_place = row.get("gather", res.location)
	res.spot_prefix = row.get("spots", "spot_")
	res.announce = row.get("announce", "")
	res.reminder = row.get("reminder", "")
	for a: Dictionary in row.get("asks", []):
		var ask := condition(a)
		ask.kind = QuestCondition.DELIVER_ITEM
		res.asks.append(ask)
	for t: Dictionary in row.get("tiers", []):
		var tier := RewardTier.new()
		tier.min_count = t.get("min", 0)
		tier.text = t.get("text", "")
		tier.rewards.assign(rewards(t.get("rewards", [])))
		res.tiers.append(tier)
	return res

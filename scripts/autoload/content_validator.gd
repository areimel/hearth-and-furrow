extends RefCounted
## Cross-checks every id reference in the built content. Used by Content.validate().

var _c: Node
var _out: Array[String] = []


func run(content: Node) -> Array[String]:
	_c = content
	_out.clear()
	_check_items()
	_check_crops()
	_check_recipes_and_stations()
	_check_animals()
	_check_gatherables()
	_check_npcs()
	_check_quests()
	_check_festivals()
	_check_tool_tiers()
	_check_chains()
	for entry: Array in Balance.START_LOADOUT:
		_need_item(entry[0], "START_LOADOUT")
	return _out


## Item ids obtainable from raw items (G.RAW_CATEGORIES) by applying recipes repeatedly.
static func craftable_from_raw(content: Node) -> Dictionary[StringName, bool]:
	var have: Dictionary[StringName, bool] = {}
	for item: ItemData in content.items():
		if item.category in G.RAW_CATEGORIES:
			have[item.id] = true
	var grew := true
	while grew:
		grew = false
		for r: RecipeData in content.recipes():
			if r.inputs.keys().all(func(id: StringName) -> bool: return have.has(id)):
				for out_id: StringName in r.outputs:
					if not have.has(out_id):
						have[out_id] = true
						grew = true
	return have


func _check_items() -> void:
	for item: ItemData in _c.items():
		if item.is_tool() and not _has_tier(item.tool_tier):
			_out.append("item %s: unknown tool tier %s" % [item.id, item.tool_tier])
		if item.category == G.ItemCategory.UPGRADE and item.backpack_slots <= 0:
			_out.append("item %s: upgrade with no effect" % item.id)
		if item.is_seed() and _c.crop_for_seed(item.id) == null:
			_out.append("seed %s: no crop uses it" % item.id)
		if item.category in G.RAW_CATEGORIES:
			if _c.recipes_using(item.id).is_empty() and not item.is_sellable():
				_out.append("raw item %s: feeds no recipe and cannot be sold" % item.id)
	var tools: Dictionary[String, bool] = {}
	for item: ItemData in _c.items():
		if item.is_tool():
			tools["%d/%s" % [item.tool_kind, item.tool_tier]] = true
	for tier: ToolTierData in _c.tool_tiers():
		for kind: int in _c.tool_kinds():
			if not tools.has("%d/%s" % [kind, tier.id]):
				_out.append("no tool item for kind %d tier %s" % [kind, tier.id])


func _check_crops() -> void:
	for crop: CropData in _c.crops():
		var where := "crop %s" % crop.id
		_need_item(crop.seed_item, where)
		_need_item(crop.yield_item, where)
		if _c.has_item(crop.seed_item) and not _c.item(crop.seed_item).is_seed():
			_out.append("%s: seed %s is not a SEED item" % [where, crop.seed_item])
		if crop.seasons.is_empty() or crop.days_to_mature <= 0 or crop.yield_amount <= 0:
			_out.append("%s: needs seasons, days > 0 and amount > 0" % where)


func _check_recipes_and_stations() -> void:
	for r: RecipeData in _c.recipes():
		var where := "recipe %s" % r.id
		if r.inputs.is_empty() or r.outputs.is_empty():
			_out.append("%s: needs inputs and outputs" % where)
		_need_station(r.station, where)
		_need_counts(r.inputs, where)
		_need_counts(r.outputs, where)
	for s: StationData in _c.stations():
		_need_counts(s.build_cost, "station %s" % s.id)
		if _c.recipes_for_station(s.id).is_empty():
			_out.append("station %s: no recipes" % s.id)


func _check_animals() -> void:
	for a: AnimalData in _c.animals():
		_need_item(a.product_item, "animal %s" % a.id)
		_need_item(a.feed_item, "animal %s" % a.id)


func _check_gatherables() -> void:
	for g: GatherableData in _c.gatherables():
		if g.yields.is_empty():
			_out.append("gatherable %s: no yields" % g.id)
		for row in g.yields:
			_need_item(row.get("item", &""), "gatherable %s" % g.id)
			if int(row.get("min", 1)) > int(row.get("max", 1)):
				_out.append("gatherable %s: min > max" % g.id)


func _check_npcs() -> void:
	for n: NPCData in _c.npcs():
		var where := "npc %s" % n.id
		for id: StringName in n.loved_gifts + n.liked_gifts + n.disliked_gifts:
			_need_item(id, where + " gift")
		for id: StringName in n.shop_stock:
			if not _c.has_item(id) and not _c.has_animal(id):
				_out.append("%s: stock %s is neither item nor animal" % [where, id])
		if n.schedule.is_empty():
			_out.append("%s: empty schedule" % where)


func _check_quests() -> void:
	var quest_ids: Array[StringName] = []
	for q: QuestData in _c.quests():
		quest_ids.append(q.id)
	for q: QuestData in _c.quests():
		var where := "quest %s" % q.id
		if not q.giver.is_empty() and not _has_npc(q.giver):
			_out.append("%s: unknown giver %s" % [where, q.giver])
		for req: StringName in q.requires:
			if not req in quest_ids:
				_out.append("%s: requires unknown quest %s" % [where, req])
		for cond: QuestCondition in q.conditions:
			_check_condition(cond, where)
		_check_rewards(q.rewards, where)
		for crop_id: StringName in q.crops:
			if not _c.crops().any(func(c: CropData) -> bool: return c.id == crop_id):
				_out.append("%s: unknown crop %s" % [where, crop_id])
		if not q.chain.is_empty() and not _c.chains().has(q.chain):
			_out.append("%s: unknown chain %s" % [where, q.chain])
		_need_counts(q.perk_gives, where + " perk")
		_need_counts(q.perk_takes, where + " perk")


func _check_condition(cond: QuestCondition, where: String) -> void:
	if not cond.kind in QuestCondition.KINDS:
		_out.append("%s: unknown condition kind %s" % [where, cond.kind])
	elif cond.kind in QuestCondition.ITEM_KINDS:
		if cond.ids().is_empty():
			_out.append("%s: item condition without items" % where)
		for id: StringName in cond.ids():
			_need_item(id, where)
	elif cond.kind in [QuestCondition.TALK_TO, QuestCondition.HEARTS]:
		if not _has_npc(cond.target):
			_out.append("%s: unknown npc %s" % [where, cond.target])
	if cond.amount <= 0:
		_out.append("%s: condition amount must be > 0" % where)


func _check_rewards(rewards: Array[QuestReward], where: String) -> void:
	for reward: QuestReward in rewards:
		if not reward.kind in QuestReward.KINDS:
			_out.append("%s: unknown reward kind %s" % [where, reward.kind])
		elif reward.kind == QuestReward.ITEM:
			_need_item(reward.target, where)
		elif reward.kind == QuestReward.FRIENDSHIP and not _has_npc(reward.target):
			_out.append("%s: unknown npc %s" % [where, reward.target])


func _check_festivals() -> void:
	for f: FestivalData in _c.festivals():
		var where := "festival %s" % f.id
		if f.day < 1 or f.day > Balance.DAYS_PER_SEASON or f.season < 0 \
				or f.season >= Balance.SEASONS_PER_YEAR:
			_out.append("%s: bad date" % where)
		if f.start_hour < Balance.DAY_START_HOUR or f.end_hour <= f.start_hour \
				or f.end_hour > 24:
			_out.append("%s: bad hours" % where)
		for ask: QuestCondition in f.asks:
			_check_condition(ask, where + " ask")
		var last := -1
		for tier: RewardTier in f.tiers:
			if tier.min_count <= last or tier.min_count > f.total_asked():
				_out.append("%s: tier thresholds must rise and be reachable" % where)
			last = tier.min_count
			_check_rewards(tier.rewards, where + " tier")


func _check_tool_tiers() -> void:
	for t: ToolTierData in _c.tool_tiers():
		if not t.next_tier.is_empty() and not _has_tier(t.next_tier):
			_out.append("tool tier %s: unknown next tier %s" % [t.id, t.next_tier])
		_need_counts(t.upgrade_items, "tool tier %s" % t.id)


func _check_chains() -> void:
	var have := craftable_from_raw(_c)
	var chains: Dictionary = _c.chains()
	for chain: StringName in chains:
		for target: StringName in chains[chain]:
			if not have.has(target):
				_out.append("chain %s: %s not craftable from raw items" % [chain, target])


func _has_npc(id: StringName) -> bool:
	return _c.npcs().any(func(n: NPCData) -> bool: return n.id == id)


func _has_tier(id: StringName) -> bool:
	return _c.tool_tiers().any(func(t: ToolTierData) -> bool: return t.id == id)


func _need_item(id: StringName, where: String) -> void:
	if not _c.has_item(id):
		_out.append("%s: unknown item %s" % [where, id])


func _need_station(id: StringName, where: String) -> void:
	if not _c.stations().any(func(s: StationData) -> bool: return s.id == id):
		_out.append("%s: unknown station %s" % [where, id])


func _need_counts(counts: Dictionary, where: String) -> void:
	for id: StringName in counts:
		_need_item(id, where)
		if int(counts[id]) <= 0:
			_out.append("%s: count for %s must be > 0" % [where, id])

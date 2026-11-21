extends Node
## Autoload `QuestManager`: quest states and objective tracking for QuestData rows.
## Conditions are re-evaluated whenever Inventory, Progress or Relationships change;
## completion is explicit (complete()), usually from the giver's dialogue.

signal quest_started(quest_id: StringName)
## An objective's current value changed. current is capped at required.
signal objective_progress(quest_id: StringName, index: int, current: int, required: int)
## All conditions of an active quest are now met (may fire again after becoming unmet).
signal quest_ready(quest_id: StringName)
signal quest_completed(quest_id: StringName)

var _states: Dictionary[StringName, int] = {}
## quest id -> last reported progress per condition, to emit only on change.
var _last: Dictionary[StringName, Array] = {}


func _ready() -> void:
	SaveManager.register(&"quests", self)
	Inventory.changed.connect(refresh)
	Progress.flag_set.connect(func(_f: StringName) -> void: refresh())
	Progress.counter_changed.connect(func(_k: StringName, _v: int) -> void: refresh())
	Relationships.hearts_changed.connect(func(_n: StringName, _h: int) -> void: refresh())
	Relationships.talked.connect(func(_n: StringName) -> void: refresh())


## G.QuestState of a quest.
func state(quest_id: StringName) -> int:
	return _states.get(quest_id, G.QuestState.INACTIVE)


func is_active(quest_id: StringName) -> bool:
	return state(quest_id) == G.QuestState.ACTIVE


func is_complete(quest_id: StringName) -> bool:
	return state(quest_id) == G.QuestState.COMPLETE


func active_quests() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _states:
		if _states[id] == G.QuestState.ACTIVE:
			out.append(id)
	return out


## Inactive, known, and every `requires` quest is complete.
func can_start(quest_id: StringName) -> bool:
	var quest := Content.quest(quest_id)
	if quest == null or state(quest_id) != G.QuestState.INACTIVE:
		return false
	return quest.requires.all(func(req: StringName) -> bool: return is_complete(req))


func start(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	_states[quest_id] = G.QuestState.ACTIVE
	quest_started.emit(quest_id)
	refresh()
	return true


## Current value of one condition, capped at its required amount.
func condition_progress(quest_id: StringName, index: int) -> int:
	var quest := Content.quest(quest_id)
	if quest == null or index < 0 or index >= quest.conditions.size():
		return 0
	var cond := quest.conditions[index]
	return mini(_raw_progress(cond), _required(cond))


## Active and every condition met.
func is_ready(quest_id: StringName) -> bool:
	var quest := Content.quest(quest_id)
	if quest == null or not is_active(quest_id):
		return false
	for i in quest.conditions.size():
		if condition_progress(quest_id, i) < _required(quest.conditions[i]):
			return false
	return true


## Consumes DELIVER_ITEM items, grants rewards and marks the quest complete.
## False (no change) unless is_ready().
func complete(quest_id: StringName) -> bool:
	if not is_ready(quest_id):
		return false
	var quest := Content.quest(quest_id)
	_states[quest_id] = G.QuestState.COMPLETE
	_last.erase(quest_id)
	for cond: QuestCondition in quest.conditions:
		if cond.kind == QuestCondition.DELIVER_ITEM:
			Inventory.remove(cond.target, cond.amount)
	for reward: QuestReward in quest.rewards:
		_grant(reward)
	quest_completed.emit(quest_id)
	return true


## Re-evaluates active quests and emits objective_progress / quest_ready on change.
func refresh() -> void:
	for quest_id: StringName in active_quests():
		var quest := Content.quest(quest_id)
		if quest == null:
			continue
		var previous: Array = _last.get(quest_id, [])
		var now: Array = []
		for i in quest.conditions.size():
			now.append(condition_progress(quest_id, i))
			if i >= previous.size() or previous[i] != now[i]:
				objective_progress.emit(quest_id, i, now[i], _required(quest.conditions[i]))
		_last[quest_id] = now
		if _all_met(quest, now) and not _all_met(quest, previous):
			quest_ready.emit(quest_id)


func reset() -> void:
	_states.clear()
	_last.clear()


func to_dict() -> Dictionary:
	return {"states": _states.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("states", {})
	for quest_id: StringName in saved:
		_states[quest_id] = int(saved[quest_id])


func _all_met(quest: QuestData, values: Array) -> bool:
	if values.size() != quest.conditions.size():
		return false
	for i in values.size():
		if values[i] < _required(quest.conditions[i]):
			return false
	return true


func _required(cond: QuestCondition) -> int:
	match cond.kind:
		QuestCondition.FLAG, QuestCondition.TALK_TO:
			return 1
	return cond.amount


func _raw_progress(cond: QuestCondition) -> int:
	match cond.kind:
		QuestCondition.HAVE_ITEM, QuestCondition.DELIVER_ITEM:
			return Inventory.count(cond.target)
		QuestCondition.FLAG:
			return 1 if Progress.has_flag(cond.target) else 0
		QuestCondition.COUNTER:
			return Progress.count(cond.target)
		QuestCondition.TALK_TO:
			return 1 if Relationships.has_met(cond.target) else 0
		QuestCondition.HEARTS:
			return Relationships.hearts(cond.target)
	return 0


func _grant(reward: QuestReward) -> void:
	match reward.kind:
		QuestReward.COINS:
			Economy.add_coins(reward.amount)
		QuestReward.ITEM:
			var leftover := Inventory.add(reward.target, reward.amount)
			if leftover > 0:
				push_warning("QuestManager: no room for %d %s" % [leftover, reward.target])
		QuestReward.FLAG:
			Progress.set_flag(reward.target)
		QuestReward.FRIENDSHIP:
			Relationships.add_points(reward.target, reward.amount)

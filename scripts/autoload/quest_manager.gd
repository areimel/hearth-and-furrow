extends Node
## Autoload `QuestManager`: quest states and objective tracking for QuestData rows.
## Conditions are re-evaluated whenever Inventory, Progress, Relationships or the day
## change (and on demand via refresh(), e.g. after a world probe moved); completion is
## explicit (complete()), usually from the giver's dialogue. Sequential quests advance
## step by step on their own and emit step_advanced. Finished errands may offer a daily
## favour (perk) through can_claim_perk() / claim_perk().

const Rules := preload("res://scripts/autoload/quest_rules.gd")

signal quest_started(quest_id: StringName)
## An objective's current value changed. current is capped at required.
signal objective_progress(quest_id: StringName, index: int, current: int, required: int)
## All conditions of an active quest are now met (may fire again after becoming unmet).
signal quest_ready(quest_id: StringName)
signal quest_completed(quest_id: StringName)
## A sequential quest finished step `step - 1`; `step` is the new current step
## (== conditions.size() once every step is done).
signal step_advanced(quest_id: StringName, step: int)

var _states: Dictionary[StringName, int] = {}
## quest id -> last reported progress per condition, to emit only on change.
var _last: Dictionary[StringName, Array] = {}
## Sequential quests: current step index, and the day that step began.
var _steps: Dictionary[StringName, int] = {}
var _step_days: Dictionary[StringName, int] = {}
var _start_days: Dictionary[StringName, int] = {}
## quest id -> day index its perk was last claimed.
var _perk_days: Dictionary[StringName, int] = {}
var _probes: Dictionary[StringName, Callable] = {}


func _ready() -> void:
	SaveManager.register(&"quests", self)
	Inventory.changed.connect(refresh)
	Progress.flag_set.connect(func(_f: StringName) -> void: refresh())
	Progress.counter_changed.connect(func(_k: StringName, _v: int) -> void: refresh())
	Relationships.hearts_changed.connect(func(_n: StringName, _h: int) -> void: refresh())
	Relationships.talked.connect(func(_n: StringName) -> void: refresh())
	GameClock.day_passed.connect(func(_d: int) -> void: refresh())


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
	_start_days[quest_id] = GameClock.day_index
	if Content.quest(quest_id).sequential:
		_steps[quest_id] = 0
		_step_days[quest_id] = GameClock.day_index
	quest_started.emit(quest_id)
	refresh()
	return true


## Start every `auto_start` quest that can start now. Returns the ids started.
func start_auto_quests() -> Array[StringName]:
	var started: Array[StringName] = []
	for quest in Content.quests():
		if quest.auto_start and can_start(quest.id) and start(quest.id):
			started.append(quest.id)
	return started


## Sequential quests: index of the step being worked on (conditions.size() when all are
## done). Other quests: 0. Steps after it are not shown in a Journal.
func current_step(quest_id: StringName) -> int:
	return _steps.get(quest_id, 0)


## Current value of one condition, capped at its required amount. In a sequential quest
## finished steps read as met and later ones as 0 (item conditions always read live).
func condition_progress(quest_id: StringName, index: int) -> int:
	var quest := Content.quest(quest_id)
	if quest == null or index < 0 or index >= quest.conditions.size():
		return 0
	var cond := quest.conditions[index]
	if is_complete(quest_id):
		return _required(cond)
	if quest.sequential and not cond.kind in QuestCondition.ITEM_KINDS:
		var step := current_step(quest_id)
		if index < step:
			return _required(cond)
		if index > step:
			return 0
	return mini(_raw_progress(quest_id, cond), _required(cond))


## Required value of condition `index` (1 for flags and talks).
func condition_required(quest_id: StringName, index: int) -> int:
	var quest := Content.quest(quest_id)
	if quest == null or index < 0 or index >= quest.conditions.size():
		return 0
	return _required(quest.conditions[index])


## Active and every condition met.
func is_ready(quest_id: StringName) -> bool:
	var quest := Content.quest(quest_id)
	if quest == null or not is_active(quest_id):
		return false
	if quest.sequential and current_step(quest_id) < quest.conditions.size():
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
		grant(reward)
	quest_completed.emit(quest_id)
	return true


## Re-evaluates active quests: advances sequential steps and emits step_advanced,
## objective_progress and quest_ready on change.
func refresh() -> void:
	for quest_id: StringName in active_quests():
		var quest := Content.quest(quest_id)
		if quest == null:
			continue
		if quest.sequential:
			_advance_steps(quest)
		var previous: Array = _last.get(quest_id, [])
		var now: Array = []
		for i in quest.conditions.size():
			now.append(condition_progress(quest_id, i))
			if i >= previous.size() or previous[i] != now[i]:
				objective_progress.emit(quest_id, i, now[i], _required(quest.conditions[i]))
		_last[quest_id] = now
		if is_ready(quest_id) and not _all_met(quest, previous):
			quest_ready.emit(quest_id)


## Register a world probe for PROBE conditions: `probe` takes no arguments and returns
## an int. Call refresh() when the value may have changed.
func register_probe(key: StringName, probe: Callable) -> void:
	_probes[key] = probe


func unregister_probe(key: StringName) -> void:
	_probes.erase(key)


# --- Perks ---

## The quest is complete, has a favour, and it was not yet claimed today.
func perk_available(quest_id: StringName) -> bool:
	var quest := Content.quest(quest_id)
	return quest != null and quest.has_perk() and is_complete(quest_id) \
			and _perk_days.get(quest_id, -1) != GameClock.day_index


## perk_available() and the Inventory holds the exchange and has room for the gift.
func can_claim_perk(quest_id: StringName) -> bool:
	if not perk_available(quest_id):
		return false
	var quest := Content.quest(quest_id)
	if not Loot.has_all(quest.perk_takes):
		return false
	for id: StringName in quest.perk_gives:
		if not Inventory.can_add(id, quest.perk_gives[id]):
			return false
	return true


## Take the favour for today: removes perk_takes, adds perk_gives. False if not possible.
func claim_perk(quest_id: StringName) -> bool:
	if not can_claim_perk(quest_id):
		return false
	var quest := Content.quest(quest_id)
	_perk_days[quest_id] = GameClock.day_index
	Loot.take(quest.perk_takes)
	for id: StringName in quest.perk_gives:
		Loot.give(get_tree(), id, quest.perk_gives[id], &"")
	return true


# --- Rewards ---

## Apply one reward. FRIENDSHIP_ALL goes to `npc_ids` (default: every villager).
func grant(reward: QuestReward, npc_ids: Array[StringName] = []) -> void:
	Rules.grant(get_tree(), reward, npc_ids)


# --- Save ---

func reset() -> void:
	_states.clear()
	_last.clear()
	_steps.clear()
	_step_days.clear()
	_start_days.clear()
	_perk_days.clear()


func to_dict() -> Dictionary:
	return {"states": _states.duplicate(), "steps": _steps.duplicate(),
		"step_days": _step_days.duplicate(), "start_days": _start_days.duplicate(),
		"perk_days": _perk_days.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	_load_ints(data.get("states", {}), _states)
	_load_ints(data.get("steps", {}), _steps)
	_load_ints(data.get("step_days", {}), _step_days)
	_load_ints(data.get("start_days", {}), _start_days)
	_load_ints(data.get("perk_days", {}), _perk_days)


func _load_ints(saved: Dictionary, into: Dictionary[StringName, int]) -> void:
	for key: Variant in saved:
		into[StringName(str(key))] = int(saved[key])


# --- Internals ---

func _advance_steps(quest: QuestData) -> void:
	var step := current_step(quest.id)
	while step < quest.conditions.size():
		var cond := quest.conditions[step]
		if _raw_progress(quest.id, cond) < _required(cond):
			return
		step += 1
		_steps[quest.id] = step
		_step_days[quest.id] = GameClock.day_index
		step_advanced.emit(quest.id, step)


func _all_met(quest: QuestData, values: Array) -> bool:
	if values.size() != quest.conditions.size():
		return false
	for i in values.size():
		if values[i] < _required(quest.conditions[i]):
			return false
	return true


func _required(cond: QuestCondition) -> int:
	return Rules.required(cond)


func _raw_progress(quest_id: StringName, cond: QuestCondition) -> int:
	var since: int = _step_days.get(quest_id, _start_days.get(quest_id, GameClock.day_index))
	return Rules.progress(cond, since, _probes)

class_name QuestGiver extends Node
## Feature root for quests. Add scenes/world/quest_giver.tscn under the Level (one line);
## it sets itself up deferred. For every quest row with a giver it registers dialogue
## options on that villager through Villagers.register_option():
##   offer    (QuestManager.can_start, not for auto quests) -> starts it, says `offer`
##   hand-in  (QuestManager.is_ready)                       -> completes it, says `complete`
##   progress (active, not ready)                           -> hint / progress chatter
##   favour   (QuestManager.perk_available)                 -> claim_perk, says `perk`
## It starts auto quests (the prologue) on a new game, plays sequential hand-offs as the
## giver's lines, toasts "New errand" / "Errand complete", and registers the field probes.
## All words come from data/quests.gd and data/dialogue_quests.gd.

const Lines := preload("res://data/dialogue_quests.gd")
const OPT_OFFER := "About that errand..."
const OPT_READY := "I have it for you."
const OPT_PROGRESS := "About your errand..."
const TOAST_STARTED := "New errand: %s"
const TOAST_COMPLETED := "Errand complete: %s"
const TOAST_STEP := "Done: %s"

## Villagers feature root; found by name when left empty (tests may set a stand-in).
var villagers: Node
## Speaks quest lines as the giver.
var speaker := QuestSpeaker.new()
var _probes := QuestProbes.new()
var _bound: bool = false


func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_started)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.step_advanced.connect(_on_step_advanced)
	SaveManager.new_game_started.connect(_on_new_game)
	SaveManager.loaded.connect(_on_loaded)
	bind.call_deferred()


func _exit_tree() -> void:
	_probes.unbind()


func _process(_delta: float) -> void:
	speaker.flush(get_tree())


## Find the Villagers and the Level, register options and probes, start auto quests.
## Runs once, deferred from _ready (tests may call it directly).
func bind() -> void:
	if _bound or not is_inside_tree():
		return
	_bound = true
	if villagers == null:
		villagers = QuestSpeaker.find_villagers(get_tree())
	speaker.villagers = villagers
	var level: Node = get_parent() if get_parent() is Level \
			else get_tree().get_first_node_in_group(&"Level")
	_probes.bind(level)
	_register_options()
	QuestManager.start_auto_quests()


## Pool `key` of quest `quest_id`'s dialogue, typed (empty when missing).
static func lines(quest_id: StringName, key: String) -> Array[String]:
	var pool: Dictionary = Lines.LINES.get(quest_id, {})
	return QuestSpeaker.lines_of(pool.get(key, []))


## True when the quest needs crops and none of them grows in the current season.
static func out_of_season(quest: QuestData) -> bool:
	if quest.crops.is_empty():
		return false
	for crop_id in quest.crops:
		var crop := Content.crop(crop_id)
		if crop != null and crop.grows_in(Calendar.season()):
			return false
	return true


## What the giver says when asked about an active quest that is not ready.
static func progress_lines(quest: QuestData) -> Array[String]:
	if quest.sequential:
		var hints := lines(quest.id, "hints")
		var step := QuestManager.current_step(quest.id)
		return [hints[step]] as Array[String] if step < hints.size() else hints
	if out_of_season(quest):
		return lines(quest.id, "out_of_season")
	return lines(quest.id, "progress")


# ---------------------------------------------------------------- options

func _register_options() -> void:
	if villagers == null:
		return
	for quest in Content.quests():
		if quest.giver.is_empty():
			continue
		var id := quest.id
		var pool: Dictionary = Lines.LINES.get(id, {})
		if not quest.auto_start:
			villagers.register_option(quest.giver, pool.get("opt_offer", OPT_OFFER),
					offer.bind(id), QuestManager.can_start.bind(id))
		villagers.register_option(quest.giver, pool.get("opt_ready", OPT_READY),
				hand_in.bind(id), QuestManager.is_ready.bind(id))
		villagers.register_option(quest.giver, pool.get("opt_progress", OPT_PROGRESS),
				ask_progress.bind(id), _under_way.bind(id))
		if quest.has_perk():
			villagers.register_option(quest.giver, quest.perk_text, ask_favour.bind(id),
					QuestManager.perk_available.bind(id))


## Option callback: accept the errand and hear what it asks.
func offer(quest_id: StringName) -> void:
	if not QuestManager.start(quest_id):
		return
	var quest := Content.quest(quest_id)
	var said := lines(quest_id, "offer")
	if out_of_season(quest):
		said.append_array(lines(quest_id, "out_of_season"))
	speaker.say_now(get_tree(), quest.giver, said)


## Option callback: hand the errand in (consumes deliveries, grants rewards).
func hand_in(quest_id: StringName) -> void:
	if QuestManager.complete(quest_id):
		speaker.say_now(get_tree(), Content.quest(quest_id).giver, lines(quest_id, "complete"))


## Option callback: progress chatter for an errand under way.
func ask_progress(quest_id: StringName) -> void:
	var quest := Content.quest(quest_id)
	speaker.say_now(get_tree(), quest.giver, progress_lines(quest))


## Option callback: the daily favour of a finished errand.
func ask_favour(quest_id: StringName) -> void:
	var key := "perk" if QuestManager.claim_perk(quest_id) else "perk_short"
	speaker.say_now(get_tree(), Content.quest(quest_id).giver, lines(quest_id, key))


func _under_way(quest_id: StringName) -> bool:
	return QuestManager.is_active(quest_id) and not QuestManager.is_ready(quest_id)


# ---------------------------------------------------------------- events

func _on_quest_started(quest_id: StringName) -> void:
	var quest := Content.quest(quest_id)
	Toast.show_message(get_tree(), TOAST_STARTED % quest.title)
	if quest.auto_start:
		speaker.say_later(quest.giver, lines(quest_id, "intro"))


func _on_quest_completed(quest_id: StringName) -> void:
	Toast.show_message(get_tree(), TOAST_COMPLETED % Content.quest(quest_id).title)


func _on_step_advanced(quest_id: StringName, step: int) -> void:
	var quest := Content.quest(quest_id)
	if step < 1 or step > quest.conditions.size():
		return
	Toast.show_message(get_tree(), TOAST_STEP % quest.conditions[step - 1].text)
	var hand_offs: Array = (Lines.LINES.get(quest_id, {}) as Dictionary).get("steps", [])
	if step - 1 < hand_offs.size():
		speaker.say_later(quest.giver, QuestSpeaker.lines_of(hand_offs[step - 1]))


func _on_new_game() -> void:
	speaker.clear()
	if _bound:
		QuestManager.start_auto_quests()


func _on_loaded(_path: String) -> void:
	speaker.clear()
	if _bound:
		QuestManager.start_auto_quests()

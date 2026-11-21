extends Node
## Throwaway demo for screenshots: the level with QuestGiver and FestivalDirector added the
## way the integrator will (one child each under Level). Use with the harness, e.g.
##   godot --path . res://tools/screenshot.tscn -- --scene res://tools/quests_demo.tscn \
##       --setup prologue --frames 120 --size 1280x720 --name prologue
## Setup steps: prologue (the reeve's first words on a new game), handin (the miller's
## options with the loaf in the pack), handin_done (his thanks), may_day, harvest_home
## (the feast table screen with some contributions made).

var _level: Level
var _giver: QuestGiver
var _director: FestivalDirector


func _ready() -> void:
	SaveManager.new_game()
	_level = load("res://scenes/levels/level.tscn").instantiate()
	_giver = load("res://scenes/world/quest_giver.tscn").instantiate()
	_director = load("res://scenes/world/festival_director.tscn").instantiate()
	_level.add_child(_giver)
	_level.add_child(_director)
	add_child(_level)


## Nothing to do: the prologue starts by itself and the reeve speaks once the level is up.
func prologue() -> void:
	pass


## The miller's conversation choices once the loaf is baked.
func handin() -> void:
	await _ready_errand()
	_talk_to(&"miller")
	await get_tree().create_timer(2.5).timeout
	_press(&"action")


## The miller's thanks after the hand-in.
func handin_done() -> void:
	await _ready_errand()
	_giver.hand_in(&"errand_miller_wheat")
	await get_tree().create_timer(0.1).timeout
	_box().call(&"_advance_pressed")


func may_day() -> void:
	await _feast(G.Season.SPRING, 20, 11, {&"hazel_rod": 4, &"reed": 9, &"egg": 1, &"apple": 2})
	_director.contribute(0)
	_director.contribute(1)


func harvest_home() -> void:
	await _feast(G.Season.AUTUMN, 7, 17, {&"wheat_sheaf": 8, &"bread": 1, &"ale": 2})
	_director.contribute(0)


func _feast(season: int, day: int, hour: int, items: Dictionary) -> void:
	await get_tree().process_frame
	_box().close()
	GameClock.day_index = Calendar.day_index_for(1, season, day)
	GameClock.hour = hour
	_director.sync()
	for id: StringName in items:
		Inventory.add(id, items[id])
	_director.open_table()


func _ready_errand() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_box().close()
	_giver.speaker.clear()
	QuestManager.register_probe(&"sown.wheat", func() -> int: return 4)
	QuestManager.register_probe(&"watered.cabbage", func() -> int: return 1)
	QuestManager.refresh()
	GameClock.day_index += 1
	Progress.record(&"harvested", &"wheat_sheaf")
	Progress.record(&"crafted", &"grain")
	Progress.record(&"crafted", &"flour")
	for npc: StringName in [&"reeve", &"miller", &"alewife", &"chandler"]:
		Relationships.talk(npc)
	QuestManager.complete(&"prologue")
	QuestManager.start(&"errand_miller_wheat")
	Inventory.add(&"bread", 2)
	_giver.speaker.clear()
	await get_tree().process_frame
	_box().close()


func _talk_to(npc_id: StringName) -> void:
	var villagers := _level.get_node("Villagers") as Villagers
	villagers.npc(npc_id).call(&"_talk")


func _box() -> DialogueBox:
	return get_tree().get_first_node_in_group(DialogueBox.BOX_GROUP) as DialogueBox


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

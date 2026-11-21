extends Node2D
## Throwaway demo: three villagers on a grass patch with Place markers, plus the
## DialogueBox. Use with the screenshot harness:
##   --scene res://tools/villagers_demo.tscn --frames 40 --name villagers
##   (add `--mode dialogue` to open the dialogue box with choices)

const NPC_SCENE := preload("res://scenes/actors/npc.tscn")
const BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const PLACES := {&"mill": Vector2(60, 60), &"village_green": Vector2(160, 80),
	&"alehouse": Vector2(260, 60)}

var _box: DialogueBox


func _ready() -> void:
	var ground := ColorRect.new()
	ground.color = UIPalette.MOSS
	ground.size = Vector2(320, 200)
	add_child(ground)
	for id: StringName in PLACES:
		var marker := Marker2D.new()
		marker.name = String(id)
		marker.position = PLACES[id]
		marker.add_to_group(&"Place")
		add_child(marker)
	GameClock.hour = 12
	var layer := CanvasLayer.new()
	add_child(layer)
	_box = BOX_SCENE.instantiate()
	layer.add_child(_box)
	var spots := {&"miller": Vector2(100, 90), &"alewife": Vector2(160, 100),
		&"shepherd": Vector2(220, 90)}
	for id: StringName in spots:
		var npc: NPC = NPC_SCENE.instantiate()
		npc.npc_id = id
		add_child(npc)
		npc.global_position = spots[id]
	if "dialogue" in OS.get_cmdline_user_args() or _mode() == "dialogue":
		Relationships.add_points(&"miller", 430)
		var miller := Content.npc(&"miller")
		var lines: Array[String] = ["Good morrow! Fresh flour, fair toll and full measure, whatever they say."]
		var options: Array[Dictionary] = [{"text": "Trade", "payload": 1},
			{"text": "About that errand...", "payload": 2}]
		_box.show_dialogue(miller, lines, options)
		await get_tree().create_timer(1.5).timeout
		_press(&"action")


func _mode() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--mode")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

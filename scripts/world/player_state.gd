class_name PlayerState extends Node
## Save provider `player`: what the farmer owns that matters across days. Position is
## deliberately not saved (you always wake at the bed) and the hotbar selection already
## lives in Inventory, so this is only the target-highlighter toggle. GameSession adds one
## to the Level when a session starts; it registers itself like any scene-owned service.

const SAVE_KEY := &"player"

## Last value applied or read; waits here until a Player exists to receive it.
var highlighter_on: bool = false


func _ready() -> void:
	SaveManager.register(SAVE_KEY, self)


func _exit_tree() -> void:
	if SaveManager.is_registered(SAVE_KEY):
		SaveManager.unregister(SAVE_KEY)


func to_dict() -> Dictionary:
	var player := _player()
	if player:
		highlighter_on = player.highlighter_on
	return {"highlighter_on": highlighter_on}


func from_dict(data: Dictionary) -> void:
	highlighter_on = bool(data.get("highlighter_on", false))
	var player := _player()
	if player:
		player.highlighter_on = highlighter_on


func reset() -> void:
	from_dict({})


func _player() -> Player:
	if not is_inside_tree():
		return null
	var level := get_tree().get_first_node_in_group(&"Level") as Level
	return level.player if level else null

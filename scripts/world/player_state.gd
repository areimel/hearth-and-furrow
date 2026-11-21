class_name PlayerState extends LevelFeature
## Save provider `player`: what the farmer carries across sessions besides the pack:
## the target-highlighter toggle, where they stand and which way they face. The hotbar
## selection already lives in Inventory. A new game keeps the spawn point from the scene.

## Last value applied or read.
var highlighter_on: bool = false


## Snapshot: highlighter, position (pixels) and facing direction.
func to_dict() -> Dictionary:
	if level == null or level.player == null:
		return {"highlighter_on": highlighter_on}
	var player := level.player
	highlighter_on = player.highlighter_on
	return {"highlighter_on": highlighter_on, "pos": [player.position.x, player.position.y],
			"facing": [player.animation_direction.x, player.animation_direction.y]}


func _restore(data: Dictionary) -> void:
	highlighter_on = bool(data.get("highlighter_on", false))
	var player := level.player
	player.highlighter_on = highlighter_on
	if data.has("pos"):
		var pos: Array = data["pos"]
		player.position = Vector2(float(pos[0]), float(pos[1]))
	if data.has("facing"):
		var facing: Array = data["facing"]
		_face(player, Vector2(float(facing[0]), float(facing[1])))


func _new_game_setup() -> void:
	_restore({})


## Turn the player to `dir` the way walking does: target direction plus every blend position.
func _face(player: Player, dir: Vector2) -> void:
	player.animation_direction = dir
	var anim_tree := player.get_node("Animation/AnimationTree") as AnimationTree
	for path: String in ["StateMachine/idle", "StateMachine/walk", "FishIdleBlendSpace2D"]:
		anim_tree.set("parameters/%s/blend_position" % path, dir)
	for animation: StringName in PlayerActions.ANIMATIONS.values():
		anim_tree.set("parameters/ToolStateMachine/%s/blend_position" % animation, dir)

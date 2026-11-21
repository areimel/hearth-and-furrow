class_name NPCEmote extends Sprite2D
## Emote bubble above a villager's head that shows a gift reaction for a moment.

const SECONDS: float = 1.6
const PATH: String = "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Emote/emote%d.png"
## Ninja Adventure emote numbers per G.GiftReaction (heart, happy, flat, sad).
const NUMBER_FOR_REACTION: Dictionary = {
	G.GiftReaction.LOVED: 27, G.GiftReaction.LIKED: 7, G.GiftReaction.NEUTRAL: 5,
	G.GiftReaction.DISLIKED: 16, G.GiftReaction.ALREADY_GIFTED: 5,
}

var _tween: Tween


func _ready() -> void:
	hide()


## Pop the bubble for a G.GiftReaction.
func show_reaction(reaction: int) -> void:
	texture = load(PATH % NUMBER_FOR_REACTION.get(reaction, 5)) as Texture2D
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SECONDS)
	_tween.tween_callback(hide)

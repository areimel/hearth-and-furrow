class_name Emote extends Sprite2D
## The one emote bubble: a Ninja Adventure emote icon that pops above a character's head
## for a moment and fades. Add a hidden Sprite2D with this script as a child of an NPC or
## animal and call pop().

const PATH := "res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Emote/emote%d.png"
const SECONDS := 1.4
const FADE := 0.3
## Common emote numbers.
const HEART := 27
const HAPPY := 7
const FLAT := 5
const SAD := 16

var _tween: Tween


func _ready() -> void:
	hide()


## Show emote icon `emote_number` (see the Ui/Emote folder), then fade it out.
func pop(emote_number: int) -> void:
	texture = load(PATH % emote_number) as Texture2D
	modulate.a = 1.0
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)

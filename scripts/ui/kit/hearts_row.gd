class_name HeartsRow extends HBoxContainer
## A row of small hearts showing friendship, e.g. 4 of 10. Filled hearts are crimson,
## the rest are dim. Sized to the heart bitmap so it lines up in any list.

const _HEART: PackedStringArray = [
	".kk.kk.", "kkkkkkk", "kkkkkkk", ".kkkkk.", "..kkk..", "...k...",
]

var _hearts: Array[TextureRect] = []


func _init() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show `value` filled hearts out of `max_hearts`.
func set_hearts(value: int, max_hearts: int) -> void:
	while _hearts.size() > max_hearts:
		var extra: TextureRect = _hearts.pop_back()
		remove_child(extra)
		extra.queue_free()
	while _hearts.size() < max_hearts:
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(8, 6)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_hearts.append(rect)
	var full := PixelIcon.make("heart_full", _HEART, {"k": UIPalette.CRIMSON})
	var empty := PixelIcon.make("heart_empty", _HEART, {"k": UIPalette.INK_DISABLED})
	for i in _hearts.size():
		_hearts[i].texture = full if i < value else empty

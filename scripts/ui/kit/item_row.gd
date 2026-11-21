class_name ItemRow extends HBoxContainer
## A captioned row of small ItemSlots ("Needs", "Makes", "Costs"). With `check_have`
## each slot shows have/need against the Inventory, dimmed and red when short.
## Display only: the slots take no focus or mouse.

## Width reserved for the caption so several rows line up.
const CAPTION_WIDTH := 30

var _caption: Label


func _init(caption: String = "") -> void:
	add_theme_constant_override("separation", 1)
	_caption = Label.new()
	_caption.text = caption
	_caption.custom_minimum_size.x = CAPTION_WIDTH
	add_child(_caption)


## Replace the slots with `items` ({item_id: amount}).
func show_items(items: Dictionary, check_have: bool = false) -> void:
	while get_child_count() > 1:
		var old := get_child(1)
		remove_child(old)
		old.queue_free()
	for id: StringName in items:
		var need: int = int(items[id])
		var slot := ItemSlot.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_item(id, need)
		if check_have:
			var have := Inventory.count(id)
			slot.set_count_text("%d/%d" % [have, need], have < need)
			slot.dimmed = have < need
		add_child(slot)

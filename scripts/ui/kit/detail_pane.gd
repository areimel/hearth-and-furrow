class_name DetailPane extends VBoxContainer
## The detail side of a ListDetail for crafting, shop and build screens: a title, a hint
## line, fact lines, what a thing needs (have/need slots) and makes, and a refusal note.
## Pure display; the screen decides what to show. Empty parts are hidden.

var _title: Label
var _desc: Label
var _facts: Label
var _needs: ItemRow
var _makes: ItemRow
var _note: Label


## `wrap_width` is the width text wraps at, so long lines wrap instead of widening the pane.
func _init(wrap_width: int = 120) -> void:
	add_theme_constant_override("separation", 2)
	_title = UIText.label("", &"HeaderLabel", wrap_width)
	_desc = UIText.label("", &"HintLabel", wrap_width)
	_facts = UIText.label("", &"NoteLabel", wrap_width)
	_needs = ItemRow.new("Needs")
	_makes = ItemRow.new("Makes")
	_note = UIText.label("", &"WarnLabel", wrap_width)
	for node: Control in [_title, _desc, _facts, _needs, _makes, _note]:
		add_child(node)


## Show one thing. `desc` is a dim description, `facts` plain lines, `needs` ({item: n})
## is counted against the Inventory, `makes` ({item: n}) is listed, `note` is a reason it
## cannot be had.
func show_info(title: String, desc: String = "", facts: Array[String] = [], needs: Dictionary = {},
		note: String = "", makes: Dictionary = {}) -> void:
	_title.text = title
	_fill(_desc, desc)
	_fill(_facts, "\n".join(facts))
	_fill(_note, note)
	_needs.show_items(needs, true)
	_needs.visible = not needs.is_empty()
	_makes.show_items(makes)
	_makes.visible = not makes.is_empty()


func _fill(label: Label, text: String) -> void:
	label.text = text
	label.visible = not text.is_empty()

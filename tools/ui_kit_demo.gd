extends Control
## Throwaway demo of the UI kit: PanelFrame + ListMenu + Prompt + Toast on a grass
## backdrop. Open it with the screenshot harness (--scene res://tools/ui_kit_demo.tscn).

const APPLE := preload("res://graphics/icons/apple.png")
const AXE := preload("res://graphics/icons/axe.png")

@onready var _frame: PanelFrame = $PanelFrame
@onready var _prompt: Prompt = $Prompt
@onready var _toasts: Toast = $Toasts


func _ready() -> void:
	var menu := ListMenu.new()
	_frame.add_content(menu)
	var entries: Array[Dictionary] = [
		{"text": "Apple seeds", "icon": APPLE, "payload": 1},
		{"text": "Iron axe", "icon": AXE, "payload": 2},
		{"text": "Fishing rod", "payload": 3},
		{"text": "Sold out", "disabled": true, "payload": 4},
		{"text": "Wheat sack", "payload": 5},
		{"text": "Rain barrel", "payload": 6},
		{"text": "Scarecrow", "payload": 7},
	]
	menu.max_rows = 5
	menu.set_entries(entries)
	menu.entry_selected.connect(func(payload: Variant) -> void:
		_toasts.push("Bought item %s" % payload, APPLE))
	menu.focus_first()
	_prompt.show_prompt(&"action", "Talk")
	_toasts.push("Picked up an apple", APPLE)
	_toasts.push("Day 3 begins")

class_name Interactable extends Area2D
## Reusable "press action to use me" component. Instance
## res://scenes/components/interactable.tscn as a child of any object and connect
## `interacted(player)`. The player tracks every Interactable in range and
## triggers only the nearest one; that one shows its prompt sign.
##
## Resize the child CollisionShape2D to set the interaction reach.

## Emitted when the player presses action while this is the nearest interactable.
signal interacted(player: Node)

## Emitted when `prompt_text` changes, so the HUD can update a prompt already on screen.
signal prompt_changed(text: String)

## What pressing action will do, shown in the HUD prompt ("Talk", "Milk", "Sleep").
@export var prompt_text: String = "Use":
	set(value):
		if value != prompt_text:
			prompt_text = value
			prompt_changed.emit(value)

## Disabled interactables are ignored by the player and show no prompt.
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_sign()

## True while this is the nearest interactable in the player's range.
var focused: bool = false:
	set(value):
		focused = value
		_refresh_sign()

@onready var _sign: Node2D = $InteractSign


func _ready() -> void:
	_refresh_sign()


## Called by the player; fires `interacted` if enabled.
func interact(player: Node) -> void:
	if enabled:
		interacted.emit(player)


func _refresh_sign() -> void:
	if _sign:
		_sign.visible = focused and enabled

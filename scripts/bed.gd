extends StaticBody2D
## Sleeping in the bed ends the day.


func _on_interactable_interacted(player: Node) -> void:
	player.day_change.emit()

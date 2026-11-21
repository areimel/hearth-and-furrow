extends StaticBody2D
## Sleeping in the bed ends the day through the level's DayCycle.


func _on_interactable_interacted(_player: Node) -> void:
	var cycle := get_tree().get_first_node_in_group(DayCycle.GROUP) as DayCycle
	if cycle:
		cycle.end_day()

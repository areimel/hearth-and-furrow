class_name Villagers extends Node
## Feature root for the village folk. Instance scenes/world/villagers.tscn under the Level:
## it spawns one NPC per Content.npcs() row into Level.npcs() (or under itself when there
## is no Level) and places each according to the schedule. Other systems reach villagers
## through here: npc(id), all(), register_option() and gather_at() / release().

## Fires once all villagers exist.
signal spawned

const NPC_SCENE := preload("res://scenes/actors/npc.tscn")

var _npcs: Dictionary[StringName, NPC] = {}
var _pending: Dictionary[StringName, Array] = {}


func _ready() -> void:
	var container := _find_container()
	for row in Content.npcs():
		var villager := NPC_SCENE.instantiate() as NPC
		villager.npc_id = row.id
		villager.name = String(row.id)
		container.add_child(villager)
		_npcs[row.id] = villager
		for option: Dictionary in _pending.get(row.id, []):
			villager.add_dialogue_option(option["text"], option["callback"], option["condition"])
	_pending.clear()
	spawned.emit()


## Level.npcs() from an ancestor (the Level joins its group only after its children are
## ready) or from the Level group, else this node.
func _find_container() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method(&"npcs"):
			return node.npcs()
		node = node.get_parent()
	var level := get_tree().get_first_node_in_group(&"Level")
	return level.npcs() if level and level.has_method(&"npcs") else self


## The villager with this id, or null before spawning / for unknown ids.
func npc(id: StringName) -> NPC:
	return _npcs.get(id)


## Every spawned villager.
func all() -> Array[NPC]:
	var out: Array[NPC] = []
	out.assign(_npcs.values())
	return out


## Attach a dialogue choice to a villager, even before the NPC node exists (it is applied
## on spawn). Same arguments as NPC.add_dialogue_option().
func register_option(npc_id: StringName, text: String, callback: Callable,
		condition: Callable = Callable()) -> void:
	var existing := npc(npc_id)
	if existing:
		existing.add_dialogue_option(text, callback, condition)
		return
	var list: Array = _pending.get(npc_id, [])
	list.append({"text": text, "callback": callback, "condition": condition})
	_pending[npc_id] = list


## Options registered for a villager that has not spawned yet.
func pending_options(npc_id: StringName) -> Array:
	return _pending.get(npc_id, [])


## Send every villager to the child markers of `place_id` whose names start with
## `spot_prefix` (round robin; the place itself when it has none) and hold them there
## until release().
func gather_at(place_id: StringName, spot_prefix: String = "") -> void:
	var spots := NPCNav.spots(get_tree(), place_id, spot_prefix)
	var center: Variant = NPCNav.position_of(get_tree(), place_id)
	if center == null:
		return
	if spots.is_empty():
		spots.append(center)
	var index := 0
	for villager in all():
		villager.hold_at(spots[index % spots.size()], place_id)
		index += 1


## End a gathering: everyone walks back to wherever their schedule says.
func release() -> void:
	for villager in all():
		villager.release_hold()

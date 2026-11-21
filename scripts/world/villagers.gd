class_name Villagers extends Node
## Feature root for the village folk. Instance scenes/world/villagers.tscn under the Level:
## it spawns one NPC per Content.npcs() row into Level.npcs() (or under itself when there
## is no Level) and places each according to the schedule. Other systems reach villagers
## through here: npc(id), all(), register_option(), set_line_override() and
## gather_at() / release().

## Fires once all villagers exist.
signal spawned

const NPC_SCENE := preload("res://scenes/actors/npc.tscn")

var _npcs: Dictionary[StringName, NPC] = {}
var _line_override: Callable = Callable()
var _queued_options: Dictionary[StringName, Array] = {}


func _ready() -> void:
	var container := _find_container()
	for row in Content.npcs():
		var villager := NPC_SCENE.instantiate() as NPC
		villager.npc_id = row.id
		villager.name = String(row.id)
		container.add_child(villager)
		_npcs[row.id] = villager
		for option: Dictionary in _queued_options.get(row.id, []):
			villager.add_dialogue_option(option["text"], option["callback"], option["condition"])
	_queued_options.clear()
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
	var list: Array = _queued_options.get(npc_id, [])
	list.append({"text": text, "callback": callback, "condition": condition})
	_queued_options[npc_id] = list


## Let a system replace what villagers say when talked to (a feast greeting, say).
## `provider(npc_id: StringName) -> Array[String]` returns the lines for that villager, or
## an empty array to fall through to the ordinary greeting. Pass Callable() to clear.
func set_line_override(provider: Callable) -> void:
	_line_override = provider


## The override lines for `npc_id` (empty when there is no override). NPCs call this first.
func line_override(npc_id: StringName) -> Array[String]:
	var lines: Array[String] = []
	if _line_override.is_valid():
		lines.assign(_line_override.call(npc_id))
	return lines


## Send every villager to the child markers of `place_id` whose names start with
## `spot_prefix` (round robin; the place itself when it has none) and hold them there
## until release().
func gather_at(place_id: StringName, spot_prefix: String = "") -> void:
	if not Places.has(get_tree(), place_id):
		return
	var spots := Places.spots(get_tree(), place_id, spot_prefix)
	if spots.is_empty():
		spots.append(Places.position_of(get_tree(), place_id))
	var index := 0
	for villager in all():
		villager.hold_at(spots[index % spots.size()], place_id)
		index += 1


## End a gathering: everyone walks back to wherever their schedule says.
func release() -> void:
	for villager in all():
		villager.release_hold()

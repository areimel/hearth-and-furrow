class_name QuestSpeaker extends RefCounted
## Lets quest and feast code speak as a villager. say_now() answers inside a conversation
## (an option callback): through the NPC when it exists, else the DialogueBox directly.
## say_later() queues lines the villager "calls out" (a hand-off, an announcement) and
## flush() shows them once no screen is open and no day transition is running.
## A missing DialogueBox drops the lines quietly (headless tests, tools).

## Villagers feature root (or a stand-in with npc(id)); may be null.
var villagers: Node
var _queue: Array[Dictionary] = []


## The Villagers feature root in `tree` (a node named "Villagers" that can register
## options), or null.
static func find_villagers(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var found := tree.root.find_child("Villagers", true, false)
	if found != null and found.has_method(&"register_option"):
		return found
	return null


## Number of queued say_later() entries not yet shown.
func pending() -> int:
	return _queue.size()


## Say `lines` as `npc_id` right away (replaces the conversation that is closing).
func say_now(tree: SceneTree, npc_id: StringName, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var npc: Node = villagers.call(&"npc", npc_id) if is_instance_valid(villagers) else null
	if npc != null and npc.has_method(&"say"):
		npc.call(&"say", lines)
		return
	_show(tree, npc_id, lines)


## Queue `lines` as `npc_id` for the next quiet moment.
func say_later(npc_id: StringName, lines: Array[String]) -> void:
	if not lines.is_empty():
		_queue.append({"npc": npc_id, "lines": lines})


## Show the oldest queued lines if the player is free. Call every frame.
func flush(tree: SceneTree) -> void:
	if _queue.is_empty() or tree == null or UIScreen.any_open(tree) \
			or DayCycle.is_transitioning(tree):
		return
	if tree.get_first_node_in_group(DialogueBox.BOX_GROUP) == null:
		_queue.clear()
		return
	var entry: Dictionary = _queue.pop_front()
	var lines: Array[String] = []
	lines.assign(entry["lines"])
	_show(tree, entry["npc"], lines)


## Forget queued lines (new game).
func clear() -> void:
	_queue.clear()


## Typed copy of a dialogue pool (data pools are untyped Arrays).
static func lines_of(pool: Variant) -> Array[String]:
	var out: Array[String] = []
	if pool is Array:
		for line: Variant in pool:
			out.append(str(line))
	return out


func _show(tree: SceneTree, npc_id: StringName, lines: Array[String]) -> void:
	if tree == null:
		return
	var box := tree.get_first_node_in_group(DialogueBox.BOX_GROUP) as DialogueBox
	var data := Content.npc(npc_id)
	if box != null and data != null:
		box.show_dialogue(data, lines)

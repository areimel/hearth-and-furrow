extends Node
## Stand-in for the Villagers feature root in quest and feast tests (no test_ methods, so
## the runner skips it). Records registered options and gather/release calls.

## [{npc, text, callback, condition}]
var options: Array[Dictionary] = []
## [[place_id, spot_prefix]] per gather_at() call.
var gathered: Array = []
var released: int = 0
var line_provider: Callable = Callable()


func register_option(npc_id: StringName, text: String, callback: Callable,
		condition: Callable = Callable()) -> void:
	options.append({"npc": npc_id, "text": text, "callback": callback, "condition": condition})


func set_line_override(provider: Callable) -> void:
	line_provider = provider


func npc(_id: StringName) -> Node:
	return null


func all() -> Array:
	return []


func gather_at(place_id: StringName, spot_prefix: String = "") -> void:
	gathered.append([place_id, spot_prefix])


func release() -> void:
	released += 1


## Texts of the options `npc_id` would offer right now.
func offered(npc_id: StringName) -> Array[String]:
	var out: Array[String] = []
	for option in options:
		var condition: Callable = option["condition"]
		if option["npc"] == npc_id and (not condition.is_valid() or condition.call()):
			out.append(option["text"])
	return out


## Run the callback of the option `text` on `npc_id`. False if not offered.
func choose(npc_id: StringName, text: String) -> bool:
	if not text in offered(npc_id):
		return false
	for option in options:
		if option["npc"] == npc_id and option["text"] == text:
			(option["callback"] as Callable).call()
			return true
	return false

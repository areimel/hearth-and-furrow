extends Node
## Autoload `Progress`: story flags and counters shared by quests, recipe unlocks, tool
## tiers and festivals. Flags are StringNames like &"prologue_done". Counter keys are
## "<verb>.<id>", e.g. &"crafted.bread", &"harvested.wheat_sheaf"; use record().
## Verbs in use: crafted, harvested, gathered, caught, sold, bought, gifted.

signal flag_set(flag: StringName)
signal counter_changed(key: StringName, value: int)

var _flags: Dictionary[StringName, bool] = {}
var _counters: Dictionary[StringName, int] = {}


func _ready() -> void:
	SaveManager.register(&"progress", self)


func set_flag(flag: StringName) -> void:
	if _flags.has(flag):
		return
	_flags[flag] = true
	flag_set.emit(flag)


## True for an empty flag, so `has_flag(recipe.unlock_flag)` works for unlocked recipes.
func has_flag(flag: StringName) -> bool:
	return flag.is_empty() or _flags.has(flag)


func flags() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_flags.keys())
	return out


func add_count(key: StringName, amount: int = 1) -> int:
	_counters[key] = _counters.get(key, 0) + amount
	counter_changed.emit(key, _counters[key])
	return _counters[key]


func count(key: StringName) -> int:
	return _counters.get(key, 0)


## add_count for "<verb>.<id>", e.g. record(&"crafted", &"bread", 2).
func record(verb: StringName, id: StringName, amount: int = 1) -> int:
	return add_count(counter_key(verb, id), amount)


static func counter_key(verb: StringName, id: StringName) -> StringName:
	return StringName("%s.%s" % [verb, id])


func reset() -> void:
	_flags.clear()
	_counters.clear()


func to_dict() -> Dictionary:
	return {"flags": _flags.keys(), "counters": _counters.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for flag: StringName in data.get("flags", []):
		_flags[flag] = true
	for key: StringName in data.get("counters", {}):
		_counters[key] = int(data["counters"][key])

class_name FestivalLedger extends RefCounted
## What happened at each feast, per year: items given per ask, whether the player came,
## and the tier paid out once the feast resolved. Plain data; FestivalDirector saves it
## under the `festivals` key. Keys are "<festival id>:<year>".

## key -> Array of ints, one per ask.
var _given: Dictionary = {}
## key -> true
var _attended: Dictionary = {}
## key -> tier index paid (-1 = resolved with nothing paid)
var _resolved: Dictionary = {}


static func key(festival_id: StringName, year: int) -> String:
	return "%s:%d" % [festival_id, year]


## Items given to ask `ask_index` of that feast in that year.
func given(festival_id: StringName, year: int, ask_index: int) -> int:
	var list: Array = _given.get(key(festival_id, year), [])
	return int(list[ask_index]) if ask_index < list.size() else 0


## Items given to the whole feast in that year.
func total(festival_id: StringName, year: int) -> int:
	var sum := 0
	for n: Variant in _given.get(key(festival_id, year), []):
		sum += int(n)
	return sum


## Record `amount` more items for an ask (the caller caps it at the ask's amount).
func add(festival_id: StringName, year: int, ask_index: int, amount: int) -> void:
	var k := key(festival_id, year)
	var list: Array = _given.get(k, [])
	while list.size() <= ask_index:
		list.append(0)
	list[ask_index] = int(list[ask_index]) + amount
	_given[k] = list


func attended(festival_id: StringName, year: int) -> bool:
	return _attended.has(key(festival_id, year))


func mark_attended(festival_id: StringName, year: int) -> void:
	_attended[key(festival_id, year)] = true


func is_resolved(festival_id: StringName, year: int) -> bool:
	return _resolved.has(key(festival_id, year))


## Tier index paid out, or -1 (not resolved, or resolved with nothing).
func resolved_tier(festival_id: StringName, year: int) -> int:
	return int(_resolved.get(key(festival_id, year), -1))


func mark_resolved(festival_id: StringName, year: int, tier: int) -> void:
	_resolved[key(festival_id, year)] = tier


func reset() -> void:
	_given.clear()
	_attended.clear()
	_resolved.clear()


func to_dict() -> Dictionary:
	return {"given": _given.duplicate(true), "attended": _attended.keys(),
		"resolved": _resolved.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var given_data: Dictionary = data.get("given", {})
	for k: Variant in given_data:
		var list: Array = []
		for n: Variant in given_data[k]:
			list.append(int(n))
		_given[str(k)] = list
	for k: Variant in data.get("attended", []):
		_attended[str(k)] = true
	var resolved_data: Dictionary = data.get("resolved", {})
	for k: Variant in resolved_data:
		_resolved[str(k)] = int(resolved_data[k])

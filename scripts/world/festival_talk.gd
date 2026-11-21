class_name FestivalTalk extends RefCounted
## The feast's words, for FestivalDirector: registers the feast greeting option on every
## villager and the eve option on the host, picks greeting and thanks lines, and reads
## the pools of data/dialogue_feasts.gd.

const Lines := preload("res://data/dialogue_feasts.gd")

var _director: FestivalDirector


func _init(director: FestivalDirector) -> void:
	_director = director


## Pool `key` of feast `festival_id` (untyped; see data/dialogue_feasts.gd).
static func pool(festival_id: StringName, key: String) -> Variant:
	return (Lines.LINES.get(festival_id, {}) as Dictionary).get(key, [])


## Typed lines of pool `key`.
static func lines(festival_id: StringName, key: String) -> Array[String]:
	return QuestSpeaker.lines_of(pool(festival_id, key))


## The villager who speaks for the village at this feast.
static func host(festival_id: StringName) -> StringName:
	var who: Variant = pool(festival_id, "host")
	return who if who is StringName else &"reeve"


## Register the greeting (while the feast runs) and eve (the day before) options.
func register(villagers: Node) -> void:
	if villagers == null:
		return
	for feast in Content.festivals():
		var greet_text: String = str(pool(feast.id, "opt_greet")) if pool(feast.id, "opt_greet") is String \
				else "Happy feast day!"
		for npc in Content.npcs():
			villagers.register_option(npc.id, greet_text, greet.bind(feast.id, npc.id),
					_is_running.bind(feast.id))
		var eve_text: String = str(pool(feast.id, "opt_eve")) if pool(feast.id, "opt_eve") is String \
				else "Any news?"
		villagers.register_option(host(feast.id), eve_text, eve.bind(feast.id),
				_is_tomorrow.bind(feast.id))


## Option callback: a villager's feast greeting (counts as attending).
func greet(festival_id: StringName, npc_id: StringName) -> void:
	_director.mark_attended()
	var by_npc: Variant = pool(festival_id, "greet")
	var said := QuestSpeaker.lines_of((by_npc as Dictionary).get(npc_id, [])) \
			if by_npc is Dictionary else [] as Array[String]
	if not said.is_empty():
		var line := said[posmod(GameClock.day_index + hash(npc_id), said.size())]
		_director.speaker.say_now(_director.get_tree(), npc_id, [line] as Array[String])


## Option callback: the host tells what tomorrow's feast wants.
func eve(festival_id: StringName) -> void:
	_director.speaker.say_now(_director.get_tree(), host(festival_id), lines(festival_id, "eve"))


## A thanks line from someone at the feast, e.g. "Margery Brewster: Well gathered!".
func reaction(festival_id: StringName, people: Array[StringName], salt: int) -> String:
	var thanks := lines(festival_id, "thanks")
	if thanks.is_empty() or people.is_empty():
		return ""
	var who := Content.npc(people[posmod(salt * 7 + GameClock.day_index, people.size())])
	return "%s: %s" % [who.display_name, thanks[posmod(salt, thanks.size())]]


func _is_running(festival_id: StringName) -> bool:
	var feast := _director.running()
	return feast != null and feast.id == festival_id


func _is_tomorrow(festival_id: StringName) -> bool:
	var feast := _director.tomorrow()
	return feast != null and feast.id == festival_id

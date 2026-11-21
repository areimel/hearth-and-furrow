class_name FestivalTalk extends RefCounted
## The feast's words, for FestivalDirector: installs the feast greeting override on the
## villagers and the eve option on the host, picks greeting and thanks lines, and reads
## the pools of data/dialogue_feasts.gd.

const Lines := preload("res://data/dialogue_feasts.gd")
## Said by a shopkeeper on a feast day that closes the shops (Trade is hidden then).
const SHOP_SHUT := "My shop is shut for the feast, but come back tomorrow."

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


## Register the eve option on the host and the feast greeting override on the villagers.
func register(villagers: Node) -> void:
	if villagers == null:
		return
	if villagers.has_method(&"set_line_override"):
		villagers.call(&"set_line_override", greeting)
	for feast in Content.festivals():
		var eve_text: String = str(pool(feast.id, "opt_eve")) if pool(feast.id, "opt_eve") is String \
				else "Any news?"
		villagers.register_option(host(feast.id), eve_text, eve.bind(feast.id),
				_is_tomorrow.bind(feast.id))


## Villagers.set_line_override provider: while a feast runs, a villager's own feast greeting
## (talking to them counts as attending), plus a line from a shopkeeper whose shop is shut.
## Empty outside a feast, so the ordinary greeting plays.
func greeting(npc_id: StringName) -> Array[String]:
	var feast := _director.running()
	var out: Array[String] = []
	if feast == null:
		return out
	_director.mark_attended()
	var by_npc: Variant = pool(feast.id, "greet")
	var said := QuestSpeaker.lines_of((by_npc as Dictionary).get(npc_id, [])) \
			if by_npc is Dictionary else ([] as Array[String])
	if not said.is_empty():
		out.append(said[posmod(GameClock.day_index + hash(npc_id), said.size())])
	if feast.shops_closed and _keeps_shop(npc_id) and not out.is_empty():
		out.append(SHOP_SHUT)
	return out


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


func _keeps_shop(npc_id: StringName) -> bool:
	for shop in Content.shops():
		if shop.keeper == npc_id:
			return true
	return false


func _is_tomorrow(festival_id: StringName) -> bool:
	var feast := _director.tomorrow()
	return feast != null and feast.id == festival_id

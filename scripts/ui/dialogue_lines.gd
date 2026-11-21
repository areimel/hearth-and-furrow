class_name DialogueLines extends RefCounted
## Chooses what a villager says. Pure functions over data/dialogue.gd, deterministic for a
## given `salt` (callers pass day, npc and talk count) so the choice is testable and a line
## does not change if the same conversation is rebuilt.

const Dialogue := preload("res://data/dialogue.gd")

const SEASON_KEYS: Array[String] = ["spring", "summer", "autumn", "winter"]
const WEATHER_KEYS: Array[String] = ["clear", "rain", "storm"]
const REACTION_KEYS: Dictionary = {
	G.GiftReaction.LOVED: "loved",
	G.GiftReaction.LIKED: "liked",
	G.GiftReaction.NEUTRAL: "neutral",
	G.GiftReaction.DISLIKED: "disliked",
	G.GiftReaction.ALREADY_GIFTED: "already",
}


## Greeting band key for a heart count: greet_low (0-2), greet_mid (3-5), greet_high (6+).
static func greeting_key(hearts: int) -> String:
	if hearts >= 6:
		return "greet_high"
	return "greet_mid" if hearts >= 3 else "greet_low"


## Every line of a pool, falling back to the generic table when the villager has none.
static func pool(npc_id: StringName, key: String) -> Array[String]:
	var out: Array[String] = []
	var own: Dictionary = Dialogue.BY_NPC.get(npc_id, {})
	out.assign(own.get(key, Dialogue.FALLBACK.get(key, [])))
	return out


## One line of a pool chosen by `salt`; empty when the pool is empty.
static func pick(npc_id: StringName, key: String, salt: int) -> String:
	var lines := pool(npc_id, key)
	return "" if lines.is_empty() else lines[absi(salt) % lines.size()]


## Lines for a conversation. First talk of the day: greeting by friendship band, a remark
## on rain, market day or the season, and (if the villager has weather lore) a forecast
## hint. Later talks: one lore line.
static func conversation(npc_id: StringName, hearts: int, first_today: bool, season: int,
		raining: bool, market_day: bool, forecast: int, salt: int) -> Array[String]:
	var out: Array[String] = []
	if not first_today:
		_append(out, pick(npc_id, "lore", salt))
		return out
	_append(out, pick(npc_id, greeting_key(hearts), salt))
	var remark := SEASON_KEYS[season]
	if raining:
		remark = "rain"
	elif market_day:
		remark = "market"
	_append(out, pick(npc_id, remark, salt + 1))
	_append(out, pick(npc_id, "forecast_" + WEATHER_KEYS[forecast], salt + 2))
	return out


## The reply to a gift (a G.GiftReaction); empty for NOT_GIFTABLE.
static func gift_line(npc_id: StringName, reaction: int, salt: int) -> String:
	if not REACTION_KEYS.has(reaction):
		return ""
	return pick(npc_id, REACTION_KEYS[reaction], salt)


static func _append(lines: Array[String], line: String) -> void:
	if line != "":
		lines.append(line)

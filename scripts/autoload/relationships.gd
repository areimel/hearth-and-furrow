extends Node
## Autoload `Relationships`: friendship points per villager. Hearts = points /
## Balance.POINTS_PER_HEART, 0..Balance.MAX_HEARTS. One talk and one gift count per
## villager per day; begin_day() clears those.

signal points_changed(npc_id: StringName, points: int)
signal hearts_changed(npc_id: StringName, hearts: int)
## First talk of the day with a villager.
signal talked(npc_id: StringName)
signal gifted(npc_id: StringName, item_id: StringName, reaction: int)

const Balance := preload("res://data/balance.gd")
const MAX_POINTS: int = Balance.MAX_HEARTS * Balance.POINTS_PER_HEART

var _points: Dictionary[StringName, int] = {}
var _met: Dictionary[StringName, bool] = {}
var _talked_today: Dictionary[StringName, bool] = {}
var _gifted_today: Dictionary[StringName, bool] = {}


func _ready() -> void:
	SaveManager.register(&"relationships", self)


func points(npc_id: StringName) -> int:
	return _points.get(npc_id, 0)


func hearts(npc_id: StringName) -> int:
	return floori(points(npc_id) / float(Balance.POINTS_PER_HEART))


## Adds (or with a negative amount removes) points, clamped to 0..MAX_POINTS.
func add_points(npc_id: StringName, amount: int) -> void:
	if Content.npc(npc_id) == null:
		return
	var before := hearts(npc_id)
	_points[npc_id] = clampi(points(npc_id) + amount, 0, MAX_POINTS)
	points_changed.emit(npc_id, _points[npc_id])
	if hearts(npc_id) != before:
		hearts_changed.emit(npc_id, hearts(npc_id))


## Records a conversation. Returns true (and grants TALK_POINTS) on the first talk of
## the day with this villager. Dialogue itself is the dialogue system's job.
func talk(npc_id: StringName) -> bool:
	if Content.npc(npc_id) == null or talked_today(npc_id):
		return false
	_talked_today[npc_id] = true
	_met[npc_id] = true
	add_points(npc_id, Balance.TALK_POINTS)
	talked.emit(npc_id)
	return true


func talked_today(npc_id: StringName) -> bool:
	return _talked_today.has(npc_id)


## Has ever talked to this villager.
func has_met(npc_id: StringName) -> bool:
	return _met.has(npc_id)


func gifted_today(npc_id: StringName) -> bool:
	return _gifted_today.has(npc_id)


## Gives one `item_id` from the Inventory. Returns a G.GiftReaction. On LOVED / LIKED /
## NEUTRAL / DISLIKED the item is removed and points applied; ALREADY_GIFTED and
## NOT_GIFTABLE change nothing.
func gift(npc_id: StringName, item_id: StringName) -> int:
	var npc := Content.npc(npc_id)
	if npc == null or not Content.has_item(item_id):
		return G.GiftReaction.NOT_GIFTABLE
	if not Content.item(item_id).is_giftable() or not Inventory.has(item_id):
		return G.GiftReaction.NOT_GIFTABLE
	if gifted_today(npc_id):
		return G.GiftReaction.ALREADY_GIFTED
	var reaction := npc.reaction_to(item_id)
	Inventory.remove(item_id, 1)
	_gifted_today[npc_id] = true
	_met[npc_id] = true
	add_points(npc_id, Balance.GIFT_POINTS[reaction])
	Progress.record(&"gifted", item_id)
	gifted.emit(npc_id, item_id, reaction)
	return reaction


## Called by GameClock.advance_day() only.
func begin_day(_day: int) -> void:
	_talked_today.clear()
	_gifted_today.clear()


func reset() -> void:
	_points.clear()
	_met.clear()
	_talked_today.clear()
	_gifted_today.clear()


func to_dict() -> Dictionary:
	return {"points": _points.duplicate(), "met": _met.keys(),
		"talked_today": _talked_today.keys(), "gifted_today": _gifted_today.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved_points: Dictionary = data.get("points", {})
	for npc_id: StringName in saved_points:
		_points[npc_id] = int(saved_points[npc_id])
	for npc_id: StringName in data.get("met", []):
		_met[npc_id] = true
	for npc_id: StringName in data.get("talked_today", []):
		_talked_today[npc_id] = true
	for npc_id: StringName in data.get("gifted_today", []):
		_gifted_today[npc_id] = true

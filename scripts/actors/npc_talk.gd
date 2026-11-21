class_name NPCTalk extends RefCounted
## Conversation logic of one NPC: the ordinary greeting (or a line override from
## Villagers.set_line_override()), the dialogue choices other systems attach, and the
## "Give <item>" choice offered while the selected item is giftable. Talk is always the
## default interaction; gifting is a choice, so registered options stay reachable.

## Ninja Adventure emote numbers per G.GiftReaction.
const EMOTES: Dictionary = {
	G.GiftReaction.LOVED: Emote.HEART, G.GiftReaction.LIKED: Emote.HAPPY,
	G.GiftReaction.NEUTRAL: Emote.FLAT, G.GiftReaction.DISLIKED: Emote.SAD,
	G.GiftReaction.ALREADY_GIFTED: Emote.FLAT,
}

## True while a conversation with this villager is open.
var busy: bool = false

var _npc: NPC
var _emote: Emote
var _options: Array[Dictionary] = []
var _count: int = 0
var _box: DialogueBox


func _init(npc: NPC, emote: Emote) -> void:
	_npc = npc
	_emote = emote


## Attach a choice shown at the end of every conversation (see NPC.add_dialogue_option).
func add_option(text: String, callback: Callable, condition: Callable = Callable()) -> void:
	_options.append({"text": text, "callback": callback, "condition": condition})


## The registered choices currently offered ({text, payload}), conditions applied.
func options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option in _options:
		var condition: Callable = option["condition"]
		if condition.is_valid() and not condition.call():
			continue
		out.append({"text": option["text"], "payload": option["callback"]})
	return out


## Say `lines` with no choices. No-op without a DialogueBox in the tree.
func say(lines: Array[String]) -> void:
	_converse(lines, false)


## The player talked to the villager: score the talk and open the conversation.
func talk() -> void:
	var id := _npc.npc_id
	var first := Relationships.talk(id)
	_count += 1
	_npc.talked.emit(id)
	var lines := _override_lines()
	if lines.is_empty():
		lines = DialogueLines.conversation(id, Relationships.hearts(id), first, Calendar.season(),
				Weather.is_raining(), Calendar.is_market_day(), Weather.forecast, _salt())
	_converse(lines, true)


## Give the selected item as a gift: emote and reaction line.
func give() -> void:
	var item := Inventory.selected_item()
	if item == null or not item.is_giftable():
		return
	var reaction := Relationships.gift(_npc.npc_id, item.id)
	if reaction == G.GiftReaction.NOT_GIFTABLE:
		return
	_emote.pop(EMOTES.get(reaction, Emote.FLAT))
	_count += 1
	_converse([DialogueLines.gift_line(_npc.npc_id, reaction, _salt())] as Array[String], false)


func _override_lines() -> Array[String]:
	var villagers := _npc.get_tree().get_first_node_in_group(&"Villagers") as Villagers
	return villagers.line_override(_npc.npc_id) if villagers else ([] as Array[String])


## Choices shown after the greeting: "Give <item>" first (when allowed), then the registered ones.
func _choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var item := Inventory.selected_item()
	if item != null and item.is_giftable() and not Relationships.gifted_today(_npc.npc_id):
		out.append({"text": "Give %s" % item.display_name, "payload": give})
	out.append_array(options())
	return out


func _salt() -> int:
	return GameClock.day_index * 31 + _count + hash(_npc.npc_id) % 97


func _converse(lines: Array[String], with_options: bool) -> void:
	var box := _npc.get_tree().get_first_node_in_group(DialogueBox.BOX_GROUP) as DialogueBox
	if box == null or _npc.data == null:
		return
	busy = true
	_box = box
	if not box.finished.is_connected(_on_finished):
		box.finished.connect(_on_finished)
		box.option_chosen.connect(_on_option_chosen)
	var choices: Array[Dictionary] = []
	if with_options:
		choices = _choices()
	box.show_dialogue(_npc.data, lines, choices)


func _on_option_chosen(payload: Variant) -> void:
	if payload is Callable and (payload as Callable).is_valid():
		(payload as Callable).call()


func _on_finished() -> void:
	_box.finished.disconnect(_on_finished)
	_box.option_chosen.disconnect(_on_option_chosen)
	busy = false
	_npc.walk_to_schedule()

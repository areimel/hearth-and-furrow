class_name AlmanackLorePage extends FocusScroll
## Historical notes for what the player has met so far: quests started (QuestData.note),
## feasts this season or already past (FestivalData.note) and production chains whose final
## good has been crafted (data/almanack.gd). Nothing unmet is listed, so it never spoils.

const NOTES := preload("res://data/almanack.gd")
const WRAP_WIDTH := 260

var _body: VBoxContainer


func _init() -> void:
	super()
	scroll_keys = true
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
	add_child(_body)


## Rebuild the list from the quests, calendar and Progress counters.
func refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var shown := 0
	for entry in notes():
		_body.add_child(UIText.label(entry["title"], &"HeaderLabel", WRAP_WIDTH))
		_body.add_child(UIText.label(entry["note"], &"NoteLabel", WRAP_WIDTH))
		shown += 1
	if shown == 0:
		_body.add_child(UIText.label("Nothing yet. Notes appear as you meet the year's work.",
				&"HintLabel", WRAP_WIDTH))


## The notes to show as [{title, note}], quests then feasts then chains.
static func notes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest in Content.quests():
		if not quest.note.is_empty() and QuestManager.state(quest.id) != G.QuestState.INACTIVE:
			out.append({"title": quest.title, "note": quest.note})
	for feast in Content.festivals():
		if not feast.note.is_empty() and feast_met(feast):
			out.append({"title": feast.display_name, "note": feast.note})
	for chain: StringName in Content.chains():
		if NOTES.CHAINS.has(chain) and chain_made(chain):
			out.append({"title": String(chain).capitalize(), "note": NOTES.CHAINS[chain]})
	return out


## A feast is met once it falls in the current season or has already passed.
static func feast_met(feast: FestivalData) -> bool:
	return feast.season == Calendar.season() \
			or Calendar.today() >= Calendar.day_index_for(1, feast.season, feast.day)


## A chain is met once any of its final goods has been crafted.
static func chain_made(chain: StringName) -> bool:
	for item: StringName in Content.chains()[chain]:
		if Progress.count(Progress.counter_key(&"crafted", item)) > 0:
			return true
	return false

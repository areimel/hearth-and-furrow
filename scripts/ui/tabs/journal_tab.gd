class_name JournalTab extends MenuTab
## Active quests on the left (a tick marks one ready to hand in), the focused quest's
## story, objectives and reward on the right. Finished quests fold away under a
## "Completed" entry that opens and closes with accept.

const LIST_WIDTH := 108
const DONE_ENTRY := &"__completed__"

var _list: ListMenu
var _body: VBoxContainer
var _show_done: bool = false
var _focused: StringName = &""


func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	_list = ListMenu.new()
	_list.custom_minimum_size.x = LIST_WIDTH
	_list.max_rows = 7
	_list.entry_selected.connect(_on_selected)
	_list.entry_focused.connect(_on_focused)
	row.add_child(_list)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := FocusScroll.new()
	panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)
	row.add_child(panel)


func tab_title() -> String:
	return "Journal"


func on_shown() -> void:
	_rebuild(&"")


func initial_focus() -> Control:
	return _list.entry_button(0) if _list.entry_count() > 0 else null


## Quest ids in the list, in order (the completed-section toggle is not included).
func listed_quests() -> Array[StringName]:
	var out: Array[StringName] = QuestManager.active_quests()
	if _show_done:
		out.append_array(_completed())
	return out


func _rebuild(focus_payload: StringName) -> void:
	var entries: Array[Dictionary] = []
	for id in QuestManager.active_quests():
		entries.append({"text": Content.quest(id).title, "payload": id,
			"icon": StatusIcons.tick(true) if QuestManager.is_ready(id) else null})
	var done := _completed()
	if not done.is_empty():
		entries.append({"text": "%s Completed (%d)" % ["-" if _show_done else "+", done.size()],
			"payload": DONE_ENTRY})
		if _show_done:
			for id in done:
				entries.append({"text": Content.quest(id).title, "payload": id})
	_list.set_entries(entries)
	if entries.is_empty():
		_show_quest(&"")
		return
	var index := 0
	for i in entries.size():
		if entries[i]["payload"] == focus_payload:
			index = i
	_focus_deferred.call_deferred(index)
	var first: StringName = entries[index]["payload"]
	_show_quest(first if first != DONE_ENTRY else &"")


func _focus_deferred(index: int) -> void:
	if is_visible_in_tree() and index < _list.entry_count():
		_list.entry_button(index).grab_focus()


func _completed() -> Array[StringName]:
	var out: Array[StringName] = []
	for quest in Content.quests():
		if QuestManager.is_complete(quest.id):
			out.append(quest.id)
	return out


func _on_selected(payload: StringName) -> void:
	if payload == DONE_ENTRY:
		_show_done = not _show_done
		_rebuild(DONE_ENTRY)


func _on_focused(payload: StringName) -> void:
	_show_quest(payload if payload != DONE_ENTRY else &"")


func _show_quest(id: StringName) -> void:
	_focused = id
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if id.is_empty():
		if QuestManager.active_quests().is_empty():
			_body.add_child(_label("No tasks yet. Speak with the folk of the village."))
		return
	var quest := Content.quest(id)
	_body.add_child(_label(quest.title, &"HeaderLabel"))
	var giver := QuestText.giver_name(quest.giver)
	if giver != "":
		_body.add_child(_label("From " + giver, &"SmallLabel"))
	_body.add_child(_label(quest.description))
	for objective in QuestText.objectives(id):
		var line := IconLabel.new()
		line.set_content(StatusIcons.tick(objective["done"]), _objective_text(objective))
		line.label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.label().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(line)
	var reward := QuestText.reward_line(quest)
	if reward != "":
		_body.add_child(_label(reward, &"SmallLabel"))
	if QuestManager.is_ready(id):
		var hand_in := _label("Ready to hand in.", &"HeaderLabel")
		hand_in.add_theme_color_override("font_color", UIPalette.MOSS)
		_body.add_child(hand_in)


func _objective_text(objective: Dictionary) -> String:
	var progress: String = objective["progress"]
	return objective["text"] + (" (%s)" % progress if progress != "" else "")


func _label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation != &"":
		label.theme_type_variation = variation
	return label

class_name DialogueBox extends UIScreen
## Bottom-anchored conversation panel: portrait, name and role, friendship hearts,
## typewriter text and, after the last line, an optional list of choices plus "Farewell".
## Advance with `action` / `ui_accept` (first press completes the line, next moves on).
## Finds itself in group `DialogueBox`; being a UIScreen it pauses player input while open.

## The conversation ended (last line dismissed, Farewell, or cancelled).
signal finished
## A choice from show_dialogue()'s `options` was picked; `payload` is its "payload" value.
signal option_chosen(payload: Variant)

const BOX_GROUP := &"DialogueBox"
const CHARS_PER_SECOND: float = 48.0
const FAREWELL_PAYLOAD := &"__farewell"

var _lines: Array[String] = []
var _index: int = -1
var _options: Array[Dictionary] = []
var _npc: NPCData
var _progress: float = 0.0
var _typing: bool = false
var _choosing: bool = false
var _closing: bool = false

@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _role_label: Label = %RoleLabel
@onready var _hearts: HeartsRow = %Hearts
@onready var _text: Label = %Text
@onready var _advance: TextureRect = %Advance
@onready var _choice_panel: PanelContainer = %ChoicePanel
@onready var _choices: ListMenu = %Choices


func _ready() -> void:
	super()
	add_to_group(BOX_GROUP)
	add_to_group(InputGlyphs.GROUP)
	_choices.entry_selected.connect(_on_choice_selected)
	_choices.cancelled.connect(_request_close)
	Relationships.hearts_changed.connect(_on_hearts_changed)
	set_process(false)


## Open the box on `lines` (each shown in turn). `options`: [{text, payload}] choices
## offered after the last line, followed by an automatic "Farewell".
## Calling it while open (e.g. from an option callback) replaces the conversation.
func show_dialogue(npc: NPCData, lines: Array[String], options: Array[Dictionary] = []) -> void:
	_npc = npc
	_lines = lines
	_options = options
	_index = -1
	_closing = false
	_choosing = false
	_choice_panel.hide()
	_portrait.texture = npc.faceset
	_name_label.text = npc.display_name
	_role_label.text = "(%s)" % npc.role
	_hearts.set_hearts(Relationships.hearts(npc.id), Balance.MAX_HEARTS)
	_advance.texture = InputGlyphs.texture_for(&"action")
	open()
	_next_line()


## Redraw the advance glyph for the current device (InputGlyphs.GROUP calls this).
func refresh_glyphs() -> void:
	_advance.texture = InputGlyphs.texture_for(&"action")


func close() -> void:
	if not is_open:
		return
	_closing = false
	_choosing = false
	_typing = false
	set_process(false)
	_choice_panel.hide()
	super()
	finished.emit()


func _process(delta: float) -> void:
	if not _typing:
		return
	_progress += delta * CHARS_PER_SECOND
	_text.visible_characters = int(_progress)
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open or _choosing or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"action") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_advance_pressed()


func _advance_pressed() -> void:
	if _typing:
		_finish_typing()
	else:
		_next_line()


func _next_line() -> void:
	_index += 1
	if _index < _lines.size():
		_text.text = _lines[_index]
		_text.visible_characters = 0
		_progress = 0.0
		_typing = true
		_advance.hide()
		set_process(true)
	elif not _options.is_empty():
		_show_choices()
	else:
		_request_close()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_advance.visible = _advance.texture != null
	set_process(false)


func _show_choices() -> void:
	_choosing = true
	_advance.hide()
	var entries: Array[Dictionary] = []
	entries.append_array(_options)
	entries.append({"text": "Farewell", "payload": FAREWELL_PAYLOAD})
	_choices.set_entries(entries)
	_choice_panel.show()
	_choices.focus_first()


func _on_choice_selected(payload: Variant) -> void:
	_request_close()
	if not (payload is StringName and payload == FAREWELL_PAYLOAD):
		option_chosen.emit(payload)


## Close on the next frame, so a button press that dismissed us is not also read by the
## player (which polls input) as a fresh interaction. A new show_dialogue() cancels it.
func _request_close() -> void:
	_closing = true
	await get_tree().process_frame
	# The box can be freed (scene change) or reopened while we waited.
	if is_instance_valid(self) and is_inside_tree() and _closing:
		close()


func _on_hearts_changed(npc_id: StringName, value: int) -> void:
	if is_open and _npc != null and _npc.id == npc_id:
		_hearts.set_hearts(value, Balance.MAX_HEARTS)

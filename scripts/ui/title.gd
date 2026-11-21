class_name TitleScreen extends Control
## The boot scene: game name over a simple backdrop and a ListMenu with Continue (only
## when a save exists, labelled with its in-game date), New Game (asks before overwriting
## a save) and Quit. Entirely keyboard/gamepad driven through ListMenu focus.
## Actions go to the GameSession autoload unless `auto_connect` is false (tests).

## Raised instead of calling GameSession when auto_connect is off.
signal action_chosen(action: StringName)

const CONTINUE := &"continue"
const NEW_GAME := &"new_game"
const QUIT := &"quit"
const CONFIRM_NEW := &"confirm_new"
const CANCEL := &"cancel"

## Connect choices to GameSession / get_tree().quit(). Tests turn this off.
@export var auto_connect: bool = true

var menu: ListMenu
var _frame: PanelFrame
var _message: Label
var _confirming: bool = false
var _busy: bool = false


func _ready() -> void:
	_frame = $Frame
	var subtitle := Label.new()
	subtitle.text = "A Tudor farming year"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame.add_content(subtitle)
	menu = ListMenu.new()
	menu.entry_selected.connect(_on_selected)
	menu.cancelled.connect(_on_cancelled)
	_frame.add_content(menu)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override(&"font_color", UIPalette.CRIMSON)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 160
	_frame.add_content(_message)
	show_main()


## Show Continue / New Game / Quit and focus the first usable entry.
func show_main() -> void:
	_confirming = false
	var entries: Array[Dictionary] = []
	if SaveManager.has_save():
		var summary := SaveManager.peek_summary()
		if summary.is_empty():
			entries.append({"text": "Continue (save unreadable)", "disabled": true, "payload": CONTINUE})
		else:
			entries.append({"text": "Continue - %s" % summary["date"], "payload": CONTINUE})
	entries.append({"text": "New Game", "payload": NEW_GAME})
	entries.append({"text": "Quit", "payload": QUIT})
	menu.set_entries(entries)
	menu.focus_first.call_deferred()


## Ask before a new game replaces the existing save.
func show_confirm() -> void:
	_confirming = true
	_message.text = "Begin anew? Your saved farm will be lost."
	var entries: Array[Dictionary] = [
		{"text": "No, go back", "payload": CANCEL},
		{"text": "Yes, start a new game", "payload": CONFIRM_NEW},
	]
	menu.set_entries(entries)
	menu.focus_first.call_deferred()


## Whether the overwrite confirmation is showing.
func is_confirming() -> bool:
	return _confirming


func _on_selected(action: StringName) -> void:
	if _busy:
		return
	match action:
		NEW_GAME:
			if SaveManager.has_save():
				show_confirm()
			else:
				_dispatch(NEW_GAME)
		CANCEL:
			_message.text = ""
			show_main()
		_:
			_dispatch(action)


func _on_cancelled() -> void:
	if _confirming:
		_message.text = ""
		show_main()


func _dispatch(action: StringName) -> void:
	if not auto_connect:
		action_chosen.emit(action)
		return
	match action:
		CONTINUE:
			_busy = true
			var err: Error = await GameSession.continue_game()
			if err != OK:
				_busy = false
				_message.text = SaveManager.last_message
		NEW_GAME, CONFIRM_NEW:
			_busy = true
			GameSession.start_new()
		QUIT:
			get_tree().quit()

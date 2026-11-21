extends TestCase
## Title menu: Continue only with a save (labelled with its date), New Game asks before
## overwriting, everything reachable by keyboard focus.

const TEMP_PATH := "user://test_title.json"

var title: TitleScreen
var _chosen: Array[StringName] = []


func before_each() -> void:
	SaveManager.save_path = TEMP_PATH
	SaveManager.delete_save()
	SaveManager.new_game()
	_chosen.clear()


func _open() -> void:
	title = load("res://scenes/ui/title.tscn").instantiate()
	title.auto_connect = false
	title.action_chosen.connect(func(action: StringName) -> void: _chosen.append(action))
	tree.root.add_child(title)
	await tree.process_frame
	await tree.process_frame


func _close() -> void:
	title.free()
	SaveManager.delete_save()
	SaveManager.save_path = SaveManager.DEFAULT_PATH
	SaveManager.new_game()


func _texts() -> Array[String]:
	var out: Array[String] = []
	for i in title.menu.entry_count():
		out.append(title.menu.entry_button(i).text)
	return out


func test_without_a_save_there_is_no_continue() -> void:
	await _open()
	eq(_texts(), ["New Game", "Quit"] as Array[String], "entries")
	check(title.menu.entry_button(0).has_focus(), "first entry focused")
	title.menu.entry_button(0).pressed.emit()
	eq(_chosen, [TitleScreen.NEW_GAME] as Array[StringName], "new game starts at once")
	_close()


func test_with_a_save_continue_shows_the_date_and_new_game_confirms() -> void:
	GameClock.day_index = 11
	SaveManager.save_game()
	await _open()
	var texts := _texts()
	eq(texts.size(), 3, "three entries")
	eq(texts[0], "Continue - %s" % Calendar.date_string(11), "continue labelled with the date")
	check(title.menu.entry_button(0).has_focus(), "continue focused")
	title.menu.entry_button(1).pressed.emit()
	check(title.is_confirming(), "asks before overwriting")
	eq(_chosen.size(), 0, "nothing started yet")
	title.menu.cancelled.emit()
	check(not title.is_confirming(), "cancel goes back")
	title.menu.entry_button(1).pressed.emit()
	title.menu.entry_button(1).pressed.emit()
	eq(_chosen, [TitleScreen.CONFIRM_NEW] as Array[StringName], "confirmed new game")
	_close()


func test_unreadable_save_disables_continue() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	await _open()
	check(title.menu.entry_button(0).disabled, "continue disabled")
	check(title.menu.entry_button(1).has_focus(), "focus skips to New Game")
	_close()

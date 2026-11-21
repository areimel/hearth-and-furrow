extends Node
## Autoload `GameSession`: the one place that knows how a game starts and stops.
## It is an autoload because it must outlive the scene change between title and level
## (it awaits frames across it) and owns the session-wide switches (autosave on, the
## "Saved" toast, the pause menu hookup). Scene-owned save providers need no special
## wait: continue_game() loads *before* the level exists, SaveManager keeps the sections
## nobody has registered yet and hands each to its provider the moment it registers.
## A new game is the mirror: the autoloads are reset first and the level's own starter
## herd / yard only appear because no section is waiting for them.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
## Frames to let the level finish its deferred setup (livestock, stations) before wiring.
const SETTLE_FRAMES := 3

## True between entering the level and returning to the title.
var in_game: bool = false
var _saved_since_toast: bool = false


func _ready() -> void:
	SaveManager.saved.connect(func(_path: String) -> void: _saved_since_toast = true)


## Begin a fresh game: reset every service, drop the old save, enter the level and write
## the first save so Continue is available immediately.
func start_new() -> void:
	SaveManager.new_game()
	SaveManager.delete_save()
	await _enter_level()
	SaveManager.save_game()


## Load the save and enter the level. Returns OK, or the load error (the title stays up;
## see SaveManager.last_message for the reason).
func continue_game() -> Error:
	var err := SaveManager.load_game()
	if err != OK:
		return err
	var from_backup := SaveManager.restored_from_backup
	await _enter_level()
	if from_backup:
		Toast.show_message(get_tree(), "Save was damaged - restored the previous one")
	return OK


## Save now, then return to the title.
func save_and_quit() -> void:
	SaveManager.save_game()
	quit_to_title()


## Return to the title without saving.
func quit_to_title() -> void:
	in_game = false
	SaveManager.autosave_enabled = false
	SaveManager.discard_pending()
	GameClock.stop()
	GameClock.set_paused(false)
	get_tree().paused = false
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	get_tree().change_scene_to_file(TITLE_SCENE)


func _enter_level() -> void:
	in_game = true
	SaveManager.autosave_enabled = true
	_saved_since_toast = false
	get_tree().change_scene_to_file(LEVEL_SCENE)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var level := get_tree().get_first_node_in_group(&"Level") as Level
	if level == null:
		return
	if level.get_node_or_null("PlayerState") == null:
		var state := PlayerState.new()
		state.name = "PlayerState"
		level.add_child(state)
	level.day_cycle.transition_finished.connect(_on_morning)
	for node in get_tree().get_nodes_in_group(&"GameMenu"):
		_hook_menu(node)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _on_morning() -> void:
	if _saved_since_toast:
		_saved_since_toast = false
		Toast.show_message(get_tree(), "Saved")


func _on_node_added(node: Node) -> void:
	if node.has_signal(&"save_and_quit_requested"):
		_hook_menu(node)


## Connect a pause menu (any node with the GameMenu signals) once.
func _hook_menu(menu: Node) -> void:
	if menu.has_signal(&"save_and_quit_requested") \
			and not menu.is_connected(&"save_and_quit_requested", save_and_quit):
		menu.connect(&"save_and_quit_requested", save_and_quit)
	if menu.has_signal(&"quit_requested") \
			and not menu.is_connected(&"quit_requested", quit_to_title):
		menu.connect(&"quit_requested", quit_to_title)

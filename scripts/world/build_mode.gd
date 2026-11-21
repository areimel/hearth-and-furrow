class_name BuildMode extends Node
## Placing and removing crafting stations on the farm grid (PRD 4.6). A child of Level.
## The `build` action opens the BuildMenu; choosing a station starts PLACE (a green/red
## preview on the cell in front of the player, `action` builds), choosing "Remove a
## structure" starts REMOVE (`action` takes the targeted station down for a refund).
## `build` or ui_cancel leaves build mode. While active, the player's `action_override`
## routes the action button here, so tools do not fire; walking is unaffected.

## Which kind of build action is active.
enum Mode { OFF, PLACE, REMOVE }

## Mode changed (also emitted when switching between PLACE and REMOVE).
signal mode_changed(mode: Mode)

const Balance := preload("res://data/balance.gd")
const TINT_VALID := Color(0.55, 1.0, 0.55, 0.8)
const TINT_INVALID := Color(1.0, 0.4, 0.4, 0.8)

## Prompt used for the hint (set in the scene).
@export var prompt: Prompt
@export var workstations: Workstations

var mode: Mode = Mode.OFF
## The station being placed (PLACE only).
var station_id: StringName = &""

var _level: Level
var _menu: BuildMenu
var _last_prompt: String = ""
var _last_valid: int = -1


func _ready() -> void:
	_level = get_parent() as Level
	_bind.call_deferred()


## True while placing or removing.
func active() -> bool:
	return mode != Mode.OFF


## Start placing `id` (does nothing unless it is a station the player can afford).
func start_placing(id: StringName) -> void:
	if not workstations.can_afford_build(id):
		return
	_enter(Mode.PLACE)
	station_id = id
	_level.show_placement_preview(Content.station(id).texture, TINT_INVALID)


## Start removing structures.
func start_removing() -> void:
	_enter(Mode.REMOVE)


## Leave build mode and clear every on-screen hint.
func exit() -> void:
	if mode == Mode.OFF:
		return
	mode = Mode.OFF
	station_id = &""
	_level.player.action_override = Callable()
	_level.hide_placement_preview()
	_level.farm_grid.clear_highlight()
	prompt.hide_prompt()
	_last_prompt = ""
	mode_changed.emit(mode)


## Whether `action` would do something on the cell in front of the player right now.
func target_valid() -> bool:
	if mode == Mode.PLACE:
		return _level.can_place_at_target()
	return mode == Mode.REMOVE and workstations.can_remove(_level.target_cell())


## What the action button does now: build at, or remove from, the targeted cell.
func perform() -> void:
	if mode == Mode.PLACE:
		_place()
	elif mode == Mode.REMOVE:
		_remove()


func _process(_delta: float) -> void:
	if mode == Mode.OFF:
		return
	var player := _level.player
	if player.current_state != Player.State.DEFAULT or player.input_locked or _level.day_cycle.busy:
		exit()
		return
	_refresh_feedback()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and active() and not UIScreen.any_open(get_tree()):
		exit()
		get_viewport().set_input_as_handled()


func _bind() -> void:
	_menu = get_tree().get_first_node_in_group(BuildMenu.BUILD_GROUP) as BuildMenu
	if _menu:
		_menu.station_chosen.connect(start_placing)
		_menu.remove_chosen.connect(start_removing)


func _toggle() -> void:
	if _menu == null:
		return
	if _menu.is_open:
		_menu.close()
	elif active():
		exit()
	elif _can_open():
		_menu.open_menu()


func _can_open() -> bool:
	var player := _level.player
	return player.current_state == Player.State.DEFAULT and player.can_move \
			and not player.input_locked and not UIScreen.any_open(get_tree()) \
			and not _level.day_cycle.busy


func _enter(new_mode: Mode) -> void:
	_level.player.action_override = perform
	mode = new_mode
	_last_valid = -1
	_last_prompt = ""
	if new_mode == Mode.REMOVE:
		_level.hide_placement_preview()
	Toast.show_message(get_tree(), "Building: press to finish", InputGlyphs.texture_for(&"build"))
	mode_changed.emit(mode)


func _refresh_feedback() -> void:
	var valid := target_valid()
	if mode == Mode.PLACE:
		if int(valid) != _last_valid:
			_level.show_placement_preview(Content.station(station_id).texture,
					TINT_VALID if valid else TINT_INVALID)
	else:
		_level.farm_grid.highlight_cell(_level.target_cell(), valid)
	_last_valid = int(valid)
	_set_prompt(_prompt_text(valid))


func _prompt_text(valid: bool) -> String:
	if mode == Mode.PLACE:
		var label := Content.station(station_id).display_name
		return "Build %s" % label if valid else "Cannot build here"
	var station := workstations.station_at(_level.target_cell())
	if station == null:
		return "Nothing to remove"
	return "Remove %s" % station.display_name() if valid else "%s is busy" % station.display_name()


func _set_prompt(text: String) -> void:
	if text != _last_prompt:
		_last_prompt = text
		prompt.show_prompt(&"action", text)


func _place() -> void:
	var data := Content.station(station_id)
	if workstations.build(station_id, _level.target_cell()) == null:
		Toast.show_message(get_tree(), "Cannot build here")
		return
	Toast.show_message(get_tree(), "Built %s" % data.display_name, data.texture)
	if not workstations.can_afford_build(station_id):
		Toast.show_message(get_tree(), "Out of materials")
		exit()


func _remove() -> void:
	var cell := _level.target_cell()
	var station := workstations.station_at(cell)
	if station == null:
		Toast.show_message(get_tree(), "Nothing to remove here")
		return
	if not workstations.can_remove(cell):
		var reason := "has output waiting" if station.has_output() else "is still working"
		Toast.show_message(get_tree(), "%s %s" % [station.display_name(), reason])
		return
	var refund := workstations.refund_of(station.station_id)
	var removed_name := station.display_name()
	workstations.remove(cell)
	Toast.show_message(get_tree(), "Removed %s" % removed_name)
	for id: StringName in refund:
		Loot.give(get_tree(), id, int(refund[id]), &"refunded")

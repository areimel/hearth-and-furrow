class_name LevelFeature extends Node
## Base of the "feature roots" that live under Level (livestock, stations, foraging, risks,
## player state). It does the shared plumbing: finds the Level, registers a save section
## under `save_key` and unregisters on exit, and holds back a section that arrives before
## the Level has started the feature.
##
## Start-up is driven by the Level: at the end of Level._ready() it calls start() on every
## LevelFeature child in tree order, so a feature can rely on the ones above it having
## claimed their ground. Subclasses override the hooks below and to_dict().

## Save section key; empty means the feature is not saved.
@export var save_key: StringName = &""

## The owning Level (nearest Level ancestor); null when used outside one.
var level: Level
## True once the Level has called start().
var started: bool = false

var _pending: Dictionary = {}
var _has_pending: bool = false


func _ready() -> void:
	var node := get_parent()
	while node != null and not node is Level:
		node = node.get_parent()
	level = node as Level
	if save_key != &"":
		SaveManager.register(save_key, self)


func _exit_tree() -> void:
	if save_key != &"" and SaveManager.is_registered(save_key):
		SaveManager.unregister(save_key)


## Called by Level once its own nodes exist: runs _on_level_ready(), then restores the
## section that was waiting, or sets up a new game when none was.
func start() -> void:
	if started or level == null:
		return
	started = true
	_on_level_ready()
	if _has_pending:
		_has_pending = false
		_restore(_pending)
	else:
		_new_game_setup()


## Save section. Override.
func to_dict() -> Dictionary:
	return {}


## Replace the feature's state with a saved section. Before start() it is held until then.
func from_dict(data: Dictionary) -> void:
	if not started:
		_pending = data
		_has_pending = true
		return
	_clear()
	_restore(data)


## New game: drop everything and set the starter state up again (held until start()).
func reset() -> void:
	_has_pending = false
	if started:
		_clear()
		_new_game_setup()


## Hook: the Level exists and its nodes are ready (before any restore or new-game setup).
func _on_level_ready() -> void:
	pass


## Hook: build the state from a saved section (already cleared).
func _restore(_data: Dictionary) -> void:
	pass


## Hook: remove everything the feature spawned or remembers.
func _clear() -> void:
	pass


## Hook: starter content of a new game (runs after _clear()).
func _new_game_setup() -> void:
	pass

extends Node
## Autoload `AudioDirector`: plays SFX events from data/audio.gd through a small player pool and
## maps seasons to music tracks. Missing files are skipped silently; unknown events do nothing.

const AudioTable := preload("res://data/audio.gd")
const POOL_SIZE: int = 6
## Minimum gap between two pickup sounds, in milliseconds.
const PICKUP_GAP_MSEC: int = 100
## Hours on which the church bell rings (GameClock hours may be 24+).
const BELL_HOURS: Array[int] = [6, 12, 18, 24]

## Number of known events accepted by play(), whether or not a stream was found. Tests read this.
var sounds_played: int = 0

var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _streams: Dictionary = {}
var _last_pickup_msec: int = -1000000


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)
	_connect_signal(Inventory, &"item_added", _on_item_added)
	_connect_signal(Economy, &"coins_changed", _on_coins_changed)
	_connect_signal(QuestManager, &"quest_started", _on_quest_event)
	_connect_signal(QuestManager, &"quest_completed", _on_quest_event)
	_connect_signal(GameClock, &"hour_passed", _on_hour_passed)


## Plays a named SFX event from AudioTable.SFX at a random pitch. Unknown events are ignored.
func play(event: StringName) -> void:
	if not AudioTable.SFX.has(event):
		return
	var row: Dictionary = AudioTable.SFX[event]
	sounds_played += 1
	var stream := _stream_for(row.path)
	if stream == null:
		return
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = stream
	player.volume_db = row.volume_db
	player.pitch_scale = randf_range(row.pitch_min, row.pitch_max)
	player.play()


## Returns the music track path for a G.Season value, or the fallback track.
func music_for_season(season: int) -> String:
	var path: String = AudioTable.MUSIC.get(season, AudioTable.MUSIC_FALLBACK)
	return path


## Loads and caches a stream; returns null (cached too) when the file is missing.
func _stream_for(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[path]


## Connects handler to source's signal only if both exist, so a renamed signal cannot crash boot.
func _connect_signal(source: Object, signal_name: StringName, handler: Callable) -> void:
	if is_instance_valid(source) and source.has_signal(signal_name):
		source.connect(signal_name, handler)


func _on_item_added(_id: StringName, _amount: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_pickup_msec < PICKUP_GAP_MSEC:
		return
	_last_pickup_msec = now
	play(&"pickup")


func _on_coins_changed(_coins: int, delta: int) -> void:
	if delta != 0:
		play(&"coins")


func _on_quest_event(_quest_id: StringName) -> void:
	play(&"quest")


func _on_hour_passed(hour: int) -> void:
	if BELL_HOURS.has(hour):
		play(&"bell")

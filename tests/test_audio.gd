extends TestCase

## AudioTable paths exist, AudioDirector ignores unknown events, pickups are rate-limited.
## The autoload is not registered in project.godot on this branch, so the script is instanced here.

const AudioTable := preload("res://data/audio.gd")
const DIRECTOR_SCRIPT := "res://scripts/autoload/audio_director.gd"


## Adds the director deferred (the runner is still inside its own _ready) and waits one frame so _ready runs.
func _make_director() -> Node:
	var director: Node = load(DIRECTOR_SCRIPT).new()
	tree.root.add_child.call_deferred(director)
	await tree.process_frame
	return director


func _free_director(director: Node) -> void:
	director.queue_free()
	await tree.process_frame


func test_sfx_paths_exist() -> void:
	for event in AudioTable.SFX:
		var row: Dictionary = AudioTable.SFX[event]
		check(ResourceLoader.exists(row.path), "missing SFX file for %s: %s" % [event, row.path])


func test_music_paths_exist() -> void:
	for season in G.Season.values():
		var path: String = AudioTable.MUSIC.get(season, AudioTable.MUSIC_FALLBACK)
		check(ResourceLoader.exists(path), "missing music for season %d: %s" % [season, path])
	check(ResourceLoader.exists(AudioTable.MUSIC_FALLBACK), "missing fallback music")


func test_music_for_season_returns_track_for_every_season() -> void:
	var director: Node = await _make_director()
	for season in G.Season.values():
		var path: String = director.music_for_season(season)
		check(ResourceLoader.exists(path), "music_for_season(%d) not found: %s" % [season, path])
	await _free_director(director)


func test_unknown_event_is_ignored() -> void:
	var director: Node = await _make_director()
	director.play(&"no_such_sound")
	eq(director.sounds_played, 0, "unknown event should not count as played")
	await _free_director(director)


func test_known_event_is_counted() -> void:
	var director: Node = await _make_director()
	director.play(&"bell")
	eq(director.sounds_played, 1, "known event should count once")
	await _free_director(director)


func test_pickup_burst_is_rate_limited() -> void:
	var director: Node = await _make_director()
	for i in 5:
		director._on_item_added(&"wheat", 1)
	eq(director.sounds_played, 1, "a burst of pickups in one frame should play once")
	await _free_director(director)


func test_bell_only_rings_at_church_hours() -> void:
	var director: Node = await _make_director()
	director._on_hour_passed(13)
	eq(director.sounds_played, 0, "13:00 should not ring")
	director._on_hour_passed(12)
	eq(director.sounds_played, 1, "12:00 should ring")
	await _free_director(director)

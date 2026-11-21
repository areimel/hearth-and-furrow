extends RefCounted
## Audio table: SFX events and the seasonal music track. Const-only; read by AudioDirector.
## Placeholder SFX reuse the existing tool and step sounds with a different pitch. Swap a row's
## path for a real file later; the event names are the contract.

## event -> {path, volume_db, pitch_min, pitch_max}. A random pitch in [pitch_min, pitch_max] is used per play.
const SFX: Dictionary = {
	&"pickup": {path = "res://audio/step.mp3", volume_db = -12.0, pitch_min = 1.4, pitch_max = 1.6},
	&"coins": {path = "res://audio/water.ogg", volume_db = -8.0, pitch_min = 1.8, pitch_max = 2.0},
	&"quest": {path = "res://audio/fish.wav", volume_db = -6.0, pitch_min = 1.3, pitch_max = 1.4},
	&"bell": {path = "res://audio/hoe.wav", volume_db = -4.0, pitch_min = 0.5, pitch_max = 0.6},
}

## G.Season -> music track path.
const MUSIC: Dictionary = {
	G.Season.SPRING: "res://audio/music.mp3",
	G.Season.SUMMER: "res://audio/music.mp3",
	G.Season.AUTUMN: "res://audio/music.mp3",
	G.Season.WINTER: "res://audio/music.mp3",
}

## Used when a season has no row in MUSIC.
const MUSIC_FALLBACK: String = "res://audio/music.mp3"

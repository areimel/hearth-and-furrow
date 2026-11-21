class_name WorldSky extends Node
## Look and sound of the sky: day/night tint, rain particles and rain sound.
## Driven by GameClock.day_progress() and Weather.weather_changed; owns no game state.
## Seasonal palettes plug into base_tint().

## Tint over the day: sampled at GameClock.day_progress() (0 = 6:00, 1 = midnight).
@export var tint_gradient: Gradient
## Overcast colour blended in while raining, strongest at dawn.
@export var rain_color: Color = Color(0.67, 0.67, 0.67)
## Music volume (dB) over the day, sampled like tint_gradient.
@export var volume_curve: Curve
@export var canvas_modulate: CanvasModulate
@export var floor_rain: GPUParticles2D  ## Drops splashing on the ground layer.
@export var screen_rain: GPUParticles2D  ## Streaks across the screen.
@export var rain_sound: AudioStreamPlayer2D
@export var music: AudioStreamPlayer2D

var _raining: bool = false


func _ready() -> void:
	Weather.weather_changed.connect(_on_weather_changed)
	_apply_rain(Weather.is_raining())


func _process(_delta: float) -> void:
	var progress := GameClock.day_progress()
	if music and volume_curve:
		music.volume_db = volume_curve.sample(progress)
	if canvas_modulate:
		canvas_modulate.color = current_tint(progress)


## Final screen tint at `progress` (0..1 of the day): base colour plus weather.
func current_tint(progress: float) -> Color:
	var color := base_tint(progress)
	if _raining:
		color = color.lerp(rain_color, 1.0 - progress)
	return color


## Base tint for the time of day, before weather. The hook where season palettes go.
func base_tint(progress: float) -> Color:
	return tint_gradient.sample(progress) if tint_gradient else Color.WHITE


## True while rain or a storm is shown.
func is_raining() -> bool:
	return _raining


func _on_weather_changed(_today: int, _forecast: int) -> void:
	_apply_rain(Weather.is_raining())


func _apply_rain(value: bool) -> void:
	_raining = value
	if floor_rain:
		floor_rain.emitting = value
	if screen_rain:
		screen_rain.emitting = value
	if rain_sound and rain_sound.playing != value:
		rain_sound.playing = value

class_name WorldSky extends Node
## Look and sound of the sky: day/night tint with a seasonal palette, overcast rain,
## storm darkness with lightning, wind-driven rain and crop sway.
## Driven by GameClock.day_progress(), Calendar and Weather.weather_changed; owns no game state.

const SWAY_SHADER := preload("res://shaders/sway.gdshader")

## Shared material crops put on their sprite (wind sway); the sky sets its strength.
static var sway_material: ShaderMaterial = _make_sway_material()

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
var _stormy: bool = false
var _season_tint: Color = Color.WHITE
var _rain_amount: float = 0.0  ## Eased 0..1 overcast.
var _storm_amount: float = 0.0  ## Eased 0..1 storm darkness.
var _flash: float = 0.0
var _flash_timer: float = 8.0
var _sway: float = Balance.SWAY_CALM
var _rain_material: ParticleProcessMaterial
var _rain_speed: Vector2 = Vector2(150.0, 200.0)  ## Calm min/max velocity, read from the scene.


func _ready() -> void:
	Weather.weather_changed.connect(_on_weather_changed)
	if screen_rain and screen_rain.process_material is ParticleProcessMaterial:
		_rain_material = (screen_rain.process_material as ParticleProcessMaterial).duplicate()
		screen_rain.process_material = _rain_material
		_rain_speed = Vector2(_rain_material.initial_velocity_min, _rain_material.initial_velocity_max)
	_apply_rain(Weather.is_raining())
	snap()


## Jump straight to the tint for the current season and weather (no easing).
func snap() -> void:
	_stormy = Weather.is_stormy()
	_season_tint = (Balance.SEASON_TINTS[Calendar.season()] as Color)
	_rain_amount = 1.0 if _raining else 0.0
	_storm_amount = 1.0 if _stormy else 0.0
	_sway = _target_sway()
	_update_wind()


func _process(delta: float) -> void:
	_ease(delta)
	_tick_lightning(delta)
	var progress := GameClock.day_progress()
	if music and volume_curve:
		music.volume_db = volume_curve.sample(progress)
	if canvas_modulate:
		canvas_modulate.color = current_tint(progress)


## Final screen tint at `progress` (0..1 of the day): base colour plus weather.
func current_tint(progress: float) -> Color:
	var color := base_tint(progress)
	color = color.lerp(rain_color, (1.0 - progress) * _rain_amount)
	color = color.lerp(Balance.STORM_COLOR, Balance.STORM_DIM * _storm_amount)
	return color.lerp(Color.WHITE, _flash * Balance.LIGHTNING_STRENGTH)


## Base tint for the time of day with the eased seasonal palette, before weather.
func base_tint(progress: float) -> Color:
	var day := tint_gradient.sample(progress) if tint_gradient else Color.WHITE
	return day * _season_tint


## Palette colour of the current season (what the eased tint is heading for).
func season_target() -> Color:
	return (Balance.SEASON_TINTS[Calendar.season()] as Color)


## True while rain or a storm is shown.
func is_raining() -> bool:
	return _raining


func _on_weather_changed(_today: int, _forecast: int) -> void:
	_stormy = Weather.is_stormy()
	_apply_rain(Weather.is_raining())
	_update_wind()


func _apply_rain(value: bool) -> void:
	_raining = value
	if floor_rain:
		floor_rain.emitting = value
	if screen_rain:
		screen_rain.emitting = value
	if rain_sound and rain_sound.playing != value:
		rain_sound.playing = value


func _ease(delta: float) -> void:
	var step := Balance.TINT_EASE_SPEED * delta
	_season_tint = _season_tint.lerp(season_target(), clampf(step, 0.0, 1.0))
	_rain_amount = move_toward(_rain_amount, 1.0 if _raining else 0.0, step)
	_storm_amount = move_toward(_storm_amount, 1.0 if _stormy else 0.0, step)
	_sway = move_toward(_sway, _target_sway(), step)
	sway_material.set_shader_parameter(&"strength", _sway)
	_flash = maxf(0.0, _flash - Balance.LIGHTNING_DECAY * delta)


func _tick_lightning(delta: float) -> void:
	if not _stormy:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash = 1.0
		_flash_timer = randf_range(Balance.LIGHTNING_GAP_MIN, Balance.LIGHTNING_GAP_MAX)


func _target_sway() -> float:
	return Balance.SWAY_STORM if _stormy else Balance.SWAY_CALM


func _update_wind() -> void:
	if _rain_material:
		_rain_material.direction = Balance.STORM_RAIN_DIRECTION if _stormy else Balance.RAIN_DIRECTION
		var scale := Balance.STORM_RAIN_SPEED if _stormy else 1.0
		_rain_material.initial_velocity_min = _rain_speed.x * scale
		_rain_material.initial_velocity_max = _rain_speed.y * scale


static func _make_sway_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SWAY_SHADER
	material.set_shader_parameter(&"strength", Balance.SWAY_CALM)
	material.set_shader_parameter(&"speed", Balance.SWAY_SPEED)
	return material

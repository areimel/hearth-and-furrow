class_name HudPurse extends PanelContainer
## Coin purse: the coin icon and the amount, with a brief coloured "+12" / "-5" flash
## whenever Economy.coins_changed fires.

const FLASH_SECONDS := 1.2

var _amount: IconLabel
var _delta: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	_amount = IconLabel.new()
	row.add_child(_amount)
	_delta = Label.new()
	_delta.visible = false
	row.add_child(_delta)
	Economy.coins_changed.connect(_on_coins_changed)
	SaveManager.loaded.connect(func(_p: String) -> void: refresh())
	SaveManager.new_game_started.connect(refresh)
	refresh()


## Show the current balance without a flash.
func refresh() -> void:
	_amount.set_content(StatusIcons.coin(), str(Economy.coins))


## The balance text shown.
func amount_text() -> String:
	return _amount.text


## The flash text currently shown ("" when none).
func flash_text() -> String:
	return _delta.text if _delta.visible else ""


func _on_coins_changed(coins: int, delta: int) -> void:
	_amount.set_content(StatusIcons.coin(), str(coins))
	if delta == 0:
		return
	_delta.text = "%+d" % delta
	_delta.theme_type_variation = &"GoodLabel" if delta > 0 else &"WarnLabel"
	_delta.modulate.a = 1.0
	_delta.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(FLASH_SECONDS * 0.6)
	_tween.tween_property(_delta, "modulate:a", 0.0, FLASH_SECONDS * 0.4)
	_tween.tween_callback(_delta.hide)

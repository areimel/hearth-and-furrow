class_name Prompt extends Control
## Small bottom-centre hint such as "[glyph] Talk". Fills its parent but ignores the
## mouse; only the little panel is visible. The glyph follows the active device.

@onready var _panel: PanelContainer = $Panel
@onready var _glyph: TextureRect = $Panel/Row/Glyph
@onready var _label: Label = $Panel/Row/Text

var _action: StringName = &""


func _ready() -> void:
	_panel.hide()
	add_to_group(InputGlyphs.GROUP)


## Show "[glyph for action] text".
func show_prompt(action: StringName, text: String) -> void:
	_action = action
	_label.text = text
	_refresh_glyph()
	_panel.show()


## Hide the hint.
func hide_prompt() -> void:
	_panel.hide()


## Redraw the glyph for the current device (InputGlyphs.GROUP calls this).
func refresh_glyphs() -> void:
	_refresh_glyph()


func _refresh_glyph() -> void:
	var texture := InputGlyphs.texture_for(_action)
	_glyph.texture = texture
	_glyph.visible = texture != null

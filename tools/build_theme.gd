extends SceneTree
## Regenerates scenes/ui/game_theme.tres from UIPalette (the only place colours live).
## Run after editing the palette or the styles below:
##   ~/.local/share/godot/4.6/godot --path . --headless --script res://tools/build_theme.gd
## The theme is the project default (gui/theme/custom) and is tuned for a 320x180 viewport.

const THEME_PATH := "res://scenes/ui/game_theme.tres"
const FONT_PATH := "res://graphics/fonts/PixeloidSans.ttf"
const FONT_SIZE := 9
const SMALL_FONT_SIZE := 8
const THEME_UID := "uid://bv8t0obbc2n47"


func _init() -> void:
	var theme: Theme = load(THEME_PATH) if ResourceLoader.exists(THEME_PATH) else Theme.new()
	theme.clear()
	theme.default_font = load(FONT_PATH)
	theme.default_font_size = FONT_SIZE
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_bars(theme)
	var err := ResourceSaver.save(theme, THEME_PATH)
	ResourceSaver.set_uid(THEME_PATH, ResourceUID.text_to_id(THEME_UID))
	print("build_theme: saved %s (err %d)" % [THEME_PATH, err])
	quit(err)


## A flat box with a 1px border, optional fill and content margins.
func _box(fill: Color, border: Color, margin := Vector2i(3, 2), border_px := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.set_border_width_all(border_px)
	box.border_color = border
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	box.anti_aliasing = false
	return box


func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UIPalette.INK)
	theme.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	theme.set_constant("line_spacing", "Label", 1)
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_color("font_color", "HeaderLabel", UIPalette.RUST)
	# SmallLabel: secondary text (key hints, counts). The Large text option resizes it.
	theme.set_type_variation("SmallLabel", "Label")
	theme.set_font_size("font_size", "SmallLabel", SMALL_FONT_SIZE)
	# HudLabel: light text with a dark outline, for text drawn over the world.
	theme.set_type_variation("HudLabel", "Label")
	theme.set_color("font_color", "HudLabel", UIPalette.PARCHMENT_LIGHT)
	theme.set_color("font_outline_color", "HudLabel", UIPalette.WOOD_DARK)
	theme.set_constant("outline_size", "HudLabel", 1)


func _buttons(theme: Theme) -> void:
	var focus := _box(Color.TRANSPARENT, UIPalette.GOLD)
	focus.set_expand_margin_all(0)
	theme.set_stylebox("normal", "Button", _box(UIPalette.WOOD, UIPalette.WOOD_DARK))
	theme.set_stylebox("hover", "Button", _box(UIPalette.WOOD_LIGHT, UIPalette.WOOD_DARK))
	theme.set_stylebox("pressed", "Button", _box(UIPalette.WOOD_DARK, UIPalette.INK))
	theme.set_stylebox("disabled", "Button", _box(UIPalette.PARCHMENT_DARK, UIPalette.INK_DISABLED))
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", UIPalette.PARCHMENT_LIGHT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", UIPalette.GOLD)
	theme.set_color("font_focus_color", "Button", UIPalette.GOLD)
	theme.set_color("font_disabled_color", "Button", UIPalette.INK_DISABLED)
	theme.set_constant("h_separation", "Button", 3)
	# ListEntry: borderless row for ListMenu; focus fills it so the cursor is obvious.
	theme.set_type_variation("ListEntry", "Button")
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 4
	none.content_margin_right = 4
	none.content_margin_top = 1
	none.content_margin_bottom = 1
	var row := _box(UIPalette.PARCHMENT_DARK, UIPalette.WOOD, Vector2i(3, 0))
	row.border_width_left = 2
	row.border_color = UIPalette.GOLD
	for style_name in ["normal", "pressed"]:
		theme.set_stylebox(style_name, "ListEntry", none)
	theme.set_stylebox("hover", "ListEntry", row)
	theme.set_stylebox("focus", "ListEntry", row)
	theme.set_stylebox("disabled", "ListEntry", none)
	theme.set_color("font_color", "ListEntry", UIPalette.INK)
	theme.set_color("font_hover_color", "ListEntry", UIPalette.INK)
	theme.set_color("font_focus_color", "ListEntry", UIPalette.INK)
	theme.set_color("font_pressed_color", "ListEntry", UIPalette.INK)
	theme.set_color("font_disabled_color", "ListEntry", UIPalette.INK_DISABLED)


func _panels(theme: Theme) -> void:
	var panel := _box(UIPalette.PARCHMENT, UIPalette.WOOD_DARK, Vector2i(4, 3))
	panel.shadow_color = UIPalette.SHADOW
	panel.shadow_offset = Vector2(1, 1)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	# FocusPanel: a highlighted panel (selected card, active slot).
	theme.set_type_variation("FocusPanel", "Panel")
	theme.set_stylebox("panel", "FocusPanel",
			_box(UIPalette.PARCHMENT_LIGHT, UIPalette.GOLD, Vector2i(4, 3), 2))
	# Thin scrollbars that fit a 320px screen.
	var track := _box(UIPalette.PARCHMENT_DARK, UIPalette.PARCHMENT_DARK, Vector2i(0, 0), 0)
	track.content_margin_left = 3
	var grab := _box(UIPalette.WOOD, UIPalette.WOOD, Vector2i(0, 0), 0)
	grab.content_margin_left = 3
	var grab_hi := _box(UIPalette.WOOD_LIGHT, UIPalette.WOOD_LIGHT, Vector2i(0, 0), 0)
	grab_hi.content_margin_left = 3
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)


func _bars(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(UIPalette.WOOD_DARK, UIPalette.INK, Vector2i(0, 0)))
	theme.set_stylebox("fill", "ProgressBar", _box(UIPalette.MOSS, UIPalette.MOSS, Vector2i(0, 0), 0))
	theme.set_constant("outline_size", "ProgressBar", 0)
	theme.set_font_size("font_size", "ProgressBar", FONT_SIZE)
	theme.set_color("font_color", "ProgressBar", UIPalette.PARCHMENT_LIGHT)

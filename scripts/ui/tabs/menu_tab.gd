class_name MenuTab extends Control
## Base for one page of the pause menu (GameMenu). A tab is a Control scene whose root
## script extends this and overrides what it needs; register its scene in
## GameMenu.TABS (one line). Tabs fill the content area and build their widgets in
## _ready(), then refresh from the autoloads in on_shown().


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Title shown on the tab strip.
func tab_title() -> String:
	return ""


## Called every time the tab becomes the visible one (menu opened or tab switched to).
func on_shown() -> void:
	pass


## The control to focus when the tab is shown; null lets the menu pick the first one.
func initial_focus() -> Control:
	return null


## Key hints for the footer, as KeyHints.set_hints() takes them (beyond the shell's own).
func hints() -> Array[Dictionary]:
	return []

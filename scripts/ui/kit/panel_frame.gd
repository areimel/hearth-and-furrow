class_name PanelFrame extends Control
## A titled panel with a content slot. Fills its parent (ignoring the mouse) and places
## the frame at the centre or against one edge, so it stays correct for any viewport
## height (320x180 or 320x200). Add widgets with add_content() or as children of the
## Content node in the scene.

enum Placement { CENTER, TOP, BOTTOM, LEFT, RIGHT }

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_apply_title()
@export var placement: Placement = Placement.CENTER:
	set(value):
		placement = value
		if is_node_ready():
			_apply_placement()
## Gap between the frame and the screen edge (edge placements only).
@export var edge_margin: int = 4
## Minimum frame width in pixels (0 = fit the content).
@export var min_width: int = 0

@onready var _frame: PanelContainer = $Frame
@onready var _title_label: Label = $Frame/Column/Title
@onready var _content: VBoxContainer = $Frame/Column/Content


func _ready() -> void:
	_frame.custom_minimum_size.x = min_width
	_apply_title()
	_apply_placement()


## The container holding the frame's contents.
func content() -> VBoxContainer:
	return _content


## Add a widget to the content slot.
func add_content(node: Control) -> void:
	_content.add_child(node)


func _apply_title() -> void:
	_title_label.text = title
	_title_label.visible = title != ""


func _apply_placement() -> void:
	var anchor := Vector2(0.5, 0.5)
	var offset := Vector2.ZERO
	var grow_h := Control.GROW_DIRECTION_BOTH
	var grow_v := Control.GROW_DIRECTION_BOTH
	match placement:
		Placement.TOP:
			anchor = Vector2(0.5, 0.0)
			offset.y = edge_margin
			grow_v = Control.GROW_DIRECTION_END
		Placement.BOTTOM:
			anchor = Vector2(0.5, 1.0)
			offset.y = -edge_margin
			grow_v = Control.GROW_DIRECTION_BEGIN
		Placement.LEFT:
			anchor = Vector2(0.0, 0.5)
			offset.x = edge_margin
			grow_h = Control.GROW_DIRECTION_END
		Placement.RIGHT:
			anchor = Vector2(1.0, 0.5)
			offset.x = -edge_margin
			grow_h = Control.GROW_DIRECTION_BEGIN
	_frame.anchor_left = anchor.x
	_frame.anchor_right = anchor.x
	_frame.anchor_top = anchor.y
	_frame.anchor_bottom = anchor.y
	_frame.offset_left = offset.x
	_frame.offset_right = offset.x
	_frame.offset_top = offset.y
	_frame.offset_bottom = offset.y
	_frame.grow_horizontal = grow_h
	_frame.grow_vertical = grow_v

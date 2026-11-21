class_name FolkRow extends Button
## One villager in the Folk tab: face, name and role, hearts, and two ticks (spoken
## with today, gift given today). Someone not yet met shows as "???" with a dark face.
## The row is a focusable button only so the list can be scrolled with the d-pad.

const Balance := preload("res://data/balance.gd")
const FACE := 16
const HEIGHT := 18
## Faceset sheets are 38 px with a border; this crop is the 32 px face, shown at half size.
const FACE_CROP := Rect2(3, 3, 32, 32)
## Width of each tick column; the Folk tab's header uses the same.
const TICK_WIDTH := 34

var npc_id: StringName = &""

var _face: TextureRect
var _name: Label
var _role: Label
var _hearts: HeartsRow
var _talked: TextureRect
var _gifted: TextureRect


func _init() -> void:
	theme_type_variation = &"ListEntry"
	custom_minimum_size.y = HEIGHT
	focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 2
	row.offset_right = -2
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(FACE, FACE)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	_name = _label(names)
	_role = _label(names)
	_role.theme_type_variation = &"SmallLabel"
	_hearts = HeartsRow.new()
	_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hearts)
	_talked = _tick(row)
	_gifted = _tick(row)


## Fill the row from NPCData and the Relationships state.
func show_npc(npc: NPCData) -> void:
	npc_id = npc.id
	var met := Relationships.has_met(npc.id)
	_face.texture = _face_texture(npc.faceset)
	custom_minimum_size.y = maxi(HEIGHT, get_theme_font_size(&"font_size", &"Label")
			+ get_theme_font_size(&"font_size", &"SmallLabel") + 2)
	_face.modulate = Color.WHITE if met else Color(0.1, 0.1, 0.1)
	_name.text = npc.display_name if met else "???"
	_role.text = npc.role if met else ""
	_hearts.visible = met
	_talked.visible = met
	_gifted.visible = met
	if met:
		_hearts.set_hearts(Relationships.hearts(npc.id), Balance.MAX_HEARTS)
		_talked.texture = StatusIcons.tick(Relationships.talked_today(npc.id))
		_gifted.texture = StatusIcons.tick(Relationships.gifted_today(npc.id))


## The name shown ("???" for someone unmet).
func shown_name() -> String:
	return _name.text


func _face_texture(sheet: Texture2D) -> Texture2D:
	if sheet == null or sheet.get_width() != 38:
		return sheet
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = FACE_CROP
	return atlas


func _label(parent: Control) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _tick(row: HBoxContainer) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size.x = TICK_WIDTH
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rect)
	return rect

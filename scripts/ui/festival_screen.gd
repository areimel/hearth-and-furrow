class_name FestivalScreen extends UIScreen
## Modal feast table for one FestivalData. Left: the asks with given/wanted counts and a
## "Give all I can" entry; right: the focused ask's accepted items with what the player
## holds; below: the reward tier reached and the next one, and a villager's reaction to
## the last gift. Accept gives; ui_cancel closes. FestivalDirector opens it (finds it in
## group FestivalScreen, or instances scenes/ui/festival_screen.tscn under the menus).

const SCREEN_GROUP := &"FestivalScreen"
const LINES := preload("res://data/dialogue_feasts.gd")
const FRAME_WIDTH := 292
const LIST_WIDTH := 150
const DETAIL_WIDTH := 124
const SLOT_COLUMNS := 6
const GIVE_ALL := -1
const SMALL_FONT := 8

var director: FestivalDirector
var festival: FestivalData
var _frame: PanelFrame
var _header: Label
var _menu: ListMenu
var _ask_title: Label
var _ask_count: Label
var _slots: GridContainer
var _reached: Label
var _next: Label
var _voice: Label
var _focused: int = 0
var _gifts: int = 0


func _ready() -> void:
	super()
	add_to_group(SCREEN_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UIPalette.SHADOW
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_frame = preload("res://scenes/ui/kit/panel_frame.tscn").instantiate()
	_frame.min_width = FRAME_WIDTH
	add_child(_frame)
	_build_body()
	closed.connect(_detach)


## Open on `feast`, contributing through `owner_director`.
func open_for(owner_director: FestivalDirector, feast: FestivalData) -> void:
	_detach()
	director = owner_director
	festival = feast
	Inventory.changed.connect(_refresh)
	director.contributed.connect(_on_contributed)
	_frame.title = feast.display_name
	_header.text = (LINES.LINES.get(feast.id, {}) as Dictionary).get("table", feast.description)
	_voice.text = ""
	_voice.hide()
	_fill_list()
	open()
	_focused = 0
	for i in feast.asks.size():
		if director.can_give(feast, i) > 0:
			_focused = i
			break
	_menu.entry_button(_focused).grab_focus()
	_refresh()


# ---------------------------------------------------------------- building

func _build_body() -> void:
	_header = _label(UIPalette.WOOD, SMALL_FONT)
	_frame.add_content(_header)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 4)
	_menu = ListMenu.new()
	_menu.custom_minimum_size.x = LIST_WIDTH
	_menu.max_rows = 5
	_menu.entry_selected.connect(_on_entry_selected)
	_menu.entry_focused.connect(_on_entry_focused)
	columns.add_child(_menu)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = DETAIL_WIDTH
	detail.add_theme_constant_override("separation", 2)
	_ask_title = Label.new()
	_ask_title.theme_type_variation = &"HeaderLabel"
	detail.add_child(_ask_title)
	_ask_count = _label(UIPalette.INK, SMALL_FONT)
	detail.add_child(_ask_count)
	_slots = GridContainer.new()
	_slots.columns = SLOT_COLUMNS
	_slots.add_theme_constant_override("h_separation", 1)
	_slots.add_theme_constant_override("v_separation", 1)
	detail.add_child(_slots)
	columns.add_child(detail)
	_frame.add_content(columns)
	_reached = _label(UIPalette.MOSS, SMALL_FONT)
	_frame.add_content(_reached)
	_next = _label(UIPalette.INK_DISABLED, SMALL_FONT)
	_frame.add_content(_next)
	_voice = _label(UIPalette.RUST, SMALL_FONT)
	_frame.add_content(_voice)


func _label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = DETAIL_WIDTH
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _fill_list() -> void:
	var entries: Array[Dictionary] = []
	for i in festival.asks.size():
		entries.append({"text": festival.asks[i].text, "payload": i})
	entries.append({"text": "Give all I can", "payload": GIVE_ALL})
	_menu.set_entries(entries)


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	if festival == null:
		return
	for i in festival.asks.size():
		var ask := festival.asks[i]
		var done := director.given(festival, i)
		_menu.entry_button(i).text = "%s %d/%d" % [ask.text, done, ask.amount]
		_grey(_menu.entry_button(i), director.can_give(festival, i) <= 0)
	var any := range(festival.asks.size()).any(
			func(i: int) -> bool: return director.can_give(festival, i) > 0)
	_grey(_menu.entry_button(festival.asks.size()), not any)
	_show_ask()
	_show_tiers()


func _show_ask() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	if _focused < 0 or _focused >= festival.asks.size():
		_ask_title.text = "Everything"
		_ask_count.text = "Gives what you carry to every ask."
		return
	var ask := festival.asks[_focused]
	_ask_title.text = ask.text
	var left := ask.amount - director.given(festival, _focused)
	_ask_count.text = "Wanted %d more. You can give %d." % [left, director.can_give(festival, _focused)] \
			if left > 0 else "Enough given. Thank you!"
	for id in ask.ids():
		var slot := ItemSlot.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var have := Inventory.count(id)
		slot.set_item(id, have)
		slot.set_count_text(str(have), UIPalette.PARCHMENT_LIGHT if have > 0 else UIPalette.CRIMSON)
		slot.dimmed = have <= 0
		_slots.add_child(slot)


func _show_tiers() -> void:
	var total := director.total_given(festival)
	var index := festival.tier_index(total)
	var head := "Given %d of %d." % [total, festival.total_asked()]
	if index >= 0:
		var tier := festival.tiers[index]
		_reached.text = "%s Now: %s (%s)" % [head, tier.text, tier.describe()]
	else:
		_reached.text = head
	if index + 1 < festival.tiers.size():
		var next := festival.tiers[index + 1]
		_next.text = "At %d: %s (%s)" % [next.min_count, next.text, next.describe()]
	else:
		_next.text = "The best the feast can give. Rewards come when it ends."


func _grey(button: Button, greyed: bool) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		if greyed:
			button.add_theme_color_override(state, UIPalette.INK_DISABLED)
		else:
			button.remove_theme_color_override(state)


# ---------------------------------------------------------------- events

func _on_entry_focused(index: int) -> void:
	_focused = index
	_show_ask()


func _on_entry_selected(index: int) -> void:
	var given := director.contribute_all() if index == GIVE_ALL else director.contribute(index)
	if given <= 0:
		Toast.show_message(get_tree(), "Nothing to give for that")
	else:
		_gifts += 1
		_voice.text = director.reaction(festival, _gifts)
		_voice.visible = not _voice.text.is_empty()
	_refresh()


func _on_contributed(_festival_id: StringName, _ask: int, _amount: int) -> void:
	_refresh()


func _detach() -> void:
	if festival == null:
		return
	if Inventory.changed.is_connected(_refresh):
		Inventory.changed.disconnect(_refresh)
	if director.contributed.is_connected(_on_contributed):
		director.contributed.disconnect(_on_contributed)
	festival = null

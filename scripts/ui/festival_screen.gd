class_name FestivalScreen extends UIScreen
## Modal feast table for one FestivalData. Left: the asks with given/wanted counts and a
## "Give all I can" entry; right: the focused ask's accepted items with what the player
## holds; below: the reward tier reached and the next one, and a villager's reaction to
## the last gift. Accept gives; ui_cancel closes. FestivalDirector opens it (finds it in
## group FestivalScreen, or instances scenes/ui/festival_screen.tscn under the menus).

const SCREEN_GROUP := &"FestivalScreen"
const LINES := preload("res://data/dialogue_feasts.gd")
const FRAME_WIDTH := 270
const LIST_WIDTH := 140
const DETAIL_WIDTH := 112
const SLOT_COLUMNS := 5
const GIVE_ALL := -1

var director: FestivalDirector
var festival: FestivalData
var _frame: PanelFrame
var _header: Label
var _menu: ListMenu
var _detail: DetailPane
var _slots: GridContainer
var _reached: Label
var _next: Label
var _voice: Label
var _focused: int = 0
var _gifts: int = 0


func _ready() -> void:
	super()
	add_to_group(SCREEN_GROUP)
	_frame = build_modal(FRAME_WIDTH)
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
	var wide := FRAME_WIDTH - 16
	_header = UIText.label("", &"HintLabel", wide)
	_frame.add_content(_header)
	_detail = DetailPane.new(DETAIL_WIDTH)
	var held := VBoxContainer.new()
	held.add_child(_detail)
	_slots = GridContainer.new()
	_slots.columns = SLOT_COLUMNS
	_slots.add_theme_constant_override("h_separation", 1)
	_slots.add_theme_constant_override("v_separation", 1)
	held.add_child(_slots)
	var columns := ListDetail.new(LIST_WIDTH, held, 5)
	_menu = columns.menu
	_menu.entry_selected.connect(_on_entry_selected)
	_menu.entry_focused.connect(_on_entry_focused)
	_frame.add_content(columns)
	_reached = UIText.label("", &"GoodLabel", wide)
	_frame.add_content(_reached)
	_next = UIText.label("", &"HintLabel", wide)
	_frame.add_content(_next)
	_voice = UIText.label("", &"AccentLabel", wide)
	_frame.add_content(_voice)


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
		_menu.set_entry_greyed(i, director.can_give(festival, i) <= 0)
	var any := range(festival.asks.size()).any(
			func(i: int) -> bool: return director.can_give(festival, i) > 0)
	_menu.set_entry_greyed(festival.asks.size(), not any)
	_show_ask()
	_show_tiers()


func _show_ask() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	if _focused < 0 or _focused >= festival.asks.size():
		_detail.show_info("Everything", "Gives what you carry to every ask.")
		return
	var ask := festival.asks[_focused]
	var left := ask.amount - director.given(festival, _focused)
	_detail.show_info(ask.text, "",
			["Wanted %d more. You can give %d." % [left, director.can_give(festival, _focused)]
			if left > 0 else "Enough given. Thank you!"])
	for id in ask.ids():
		var slot := ItemSlot.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var have := Inventory.count(id)
		slot.set_item(id, have)
		slot.set_count_text(str(have), have <= 0)
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

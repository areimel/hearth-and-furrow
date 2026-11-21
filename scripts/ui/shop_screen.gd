class_name ShopScreen extends UIScreen
## Modal shop UI for one ShopData. Two tabs: BUY (the shop's wares in a ListMenu, with a
## detail pane) and SELL (an ItemGrid on the player's Inventory). Switch tabs with
## tool_backward / tool_forward (Q / E, shoulder buttons): ui_left/right belong to the
## SELL grid's focus navigation (a TabStrip reads the keys). Accept buys or sells one; Shift (or pad X) with accept
## sells the whole stack; ui_cancel closes. Instance scenes/ui/shop_screen.tscn once under
## the HUD; Shops finds it by group. Coins, stock and goods rules live in Economy/ShopDeals.

const SHOP_GROUP := &"ShopScreen"
const FRAME_WIDTH := 270
const LIST_WIDTH := 148
const GRID_COLUMNS := 8

enum Tab { BUY, SELL }

## The shop being shown (null while closed).
var shop: ShopData
## The visible tab.
var tab: Tab = Tab.BUY

var _frame: PanelFrame
var _strip: TabStrip
var _purse: Label
var _banner: Label
var _hints: KeyHints
var _buy_box: ListDetail
var _menu: ListMenu
var _buy_detail: DetailPane
var _sell_box: HBoxContainer
var _grid: ItemGrid
var _sell_detail: DetailPane
var _sell_index: int = 0
var _ware_id: StringName


func _ready() -> void:
	super()
	add_to_group(SHOP_GROUP)
	_frame = build_modal(FRAME_WIDTH)
	_build_body()
	closed.connect(_detach)


## Open the screen for the shop `shop_id`; false (and nothing shown) for an unknown id.
func open_for(shop_id: StringName) -> bool:
	if not Content.shops().any(func(s: ShopData) -> bool: return s.id == shop_id):
		return false
	_detach()
	shop = Content.shop(shop_id)
	Economy.coins_changed.connect(_on_state_changed)
	Inventory.changed.connect(_refresh)
	Inventory.capacity_changed.connect(_rebind_grid)
	_frame.title = shop.display_name
	_fill_wares()
	_rebind_grid(0)
	tab = Tab.BUY if not shop.wares.is_empty() else Tab.SELL
	_strip.visible = not shop.wares.is_empty() and shop.buys_anything()
	open()
	_show_tab()
	return true


## Switch to `new_tab` if the shop has that side (buy-only or sell-only shops do not).
func show_tab(new_tab: Tab) -> void:
	if (new_tab == Tab.BUY and not shop.wares.is_empty()) or (new_tab == Tab.SELL and shop.buys_anything()):
		tab = new_tab
		_show_tab()


# ---------------------------------------------------------------- building

func _build_body() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	_strip = TabStrip.new()
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.set_tabs(["Buy", "Sell"])
	_strip.tab_pressed.connect(func(index: int) -> void: show_tab(index as Tab))
	_strip.tab_stepped.connect(func(index: int) -> void: show_tab(index as Tab))
	top.add_child(_strip)
	_purse = UIText.label()
	top.add_child(_purse)
	_frame.add_content(top)
	_banner = UIText.label("Market day: better prices!", &"GoodLabel")
	_frame.add_content(_banner)
	_buy_detail = DetailPane.new(FRAME_WIDTH - LIST_WIDTH - 18)
	_buy_box = ListDetail.new(LIST_WIDTH, _buy_detail)
	_menu = _buy_box.menu
	_menu.entry_selected.connect(_on_ware_selected)
	_menu.entry_focused.connect(_show_ware)
	_frame.add_content(_buy_box)
	_build_sell_side()
	_hints = KeyHints.new()
	_frame.add_content(_hints)


func _build_sell_side() -> void:
	_sell_box = HBoxContainer.new()
	_sell_box.add_theme_constant_override("separation", 4)
	_grid = ItemGrid.new()
	_grid.columns = GRID_COLUMNS
	_grid.slot_activated.connect(_on_slot_activated)
	_grid.slot_focused.connect(_show_sale)
	_sell_box.add_child(_grid)
	_sell_detail = DetailPane.new(FRAME_WIDTH - 8 * 19 - 18)
	_sell_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_box.add_child(_sell_detail)
	_frame.add_content(_sell_box)


func _fill_wares() -> void:
	var entries: Array[Dictionary] = []
	for entry in shop.wares:
		entries.append({"text": "", "icon": ShopDeals.describe(entry)["icon"],
			"payload": entry["id"]})
	_menu.set_entries(entries)


func _rebind_grid(_capacity: int) -> void:
	_grid.bind_inventory(0, Inventory.size())
	_refresh()


# ---------------------------------------------------------------- refresh

func _show_tab() -> void:
	_buy_box.visible = tab == Tab.BUY
	_sell_box.visible = tab == Tab.SELL
	_strip.select(tab)
	_refresh()
	if tab == Tab.BUY:
		_menu.focus_first()
	else:
		_grid.slot_at(clampi(_sell_index, 0, _grid.slot_count() - 1)).grab_focus()


func _refresh() -> void:
	if shop == null:
		return
	_purse.text = UIText.coins(Economy.coins)
	_banner.visible = Calendar.is_market_day()
	_hints.set_hints(_hint_list())
	for i in shop.wares.size():
		var entry := shop.wares[i]
		var info := ShopDeals.describe(entry)
		var button := _menu.entry_button(i)
		var left := Economy.shop_stock_left(shop, entry)
		button.text = "%s  %s%s" % [info["name"], UIText.price(Economy.shop_buy_price(shop, entry)),
				"" if left < 0 else "  x%d" % left]
		button.icon = info["icon"]
		_menu.set_entry_greyed(i, not Economy.shop_block_reason(shop, entry).is_empty())
	for i in _grid.slot_count():
		var id := Inventory.slot_id(i)
		_grid.slot_at(i).dimmed = not id.is_empty() and Economy.shop_sell_price(shop, id) <= 0
	if not shop.wares.is_empty():
		_show_ware(_ware_id if not shop.ware(_ware_id).is_empty() else shop.wares[0]["id"])
	_show_sale(_sell_index)


func _hint_list() -> Array[Dictionary]:
	var hints: Array[Dictionary] = []
	if tab == Tab.BUY:
		hints.append({"action": &"ui_accept", "text": "Buy"})
	else:
		hints.append({"action": &"ui_accept", "text": "Sell one"})
		hints.append({"key": KEY_SHIFT, "button": JOY_BUTTON_X, "text": "Sell all"})
	hints.append({"action": &"ui_cancel", "text": "Close"})
	return hints


func _show_ware(entry_id: StringName) -> void:
	var entry := shop.ware(entry_id)
	if entry.is_empty():  # focus event from a button of the previous shop, not yet freed
		return
	_ware_id = entry_id
	var info := ShopDeals.describe(entry)
	var left := Economy.shop_stock_left(shop, entry)
	var facts: Array[String] = ["Price: " + UIText.coins(Economy.shop_buy_price(shop, entry))]
	if left >= 0:
		facts.append("In stock: %d" % left)
	_buy_detail.show_info(info["name"], info["desc"], facts, ShopDeals.needs(entry),
			Economy.shop_block_reason(shop, entry))


func _show_sale(index: int) -> void:
	_sell_index = index
	var id := Inventory.slot_id(index)
	if id.is_empty():
		_sell_detail.show_info("Empty", "", [])
		return
	var item := Content.item(id)
	var price := Economy.shop_sell_price(shop, id)
	if price <= 0:
		_sell_detail.show_info(item.display_name, item.description, [], {}, "Won't buy that")
		return
	var count := Inventory.slot_count(index)
	var facts: Array[String] = ["Pays %s each" % UIText.coins(price)]
	if count > 1:
		facts.append("Stack of %d: %s" % [count, UIText.coins(price * count)])
	_sell_detail.show_info(item.display_name, item.description, facts)


# ---------------------------------------------------------------- events

func _on_ware_selected(entry_id: StringName) -> void:
	var entry := shop.ware(entry_id)
	var info := ShopDeals.describe(entry)
	var price := Economy.shop_buy_price(shop, entry)
	var reason := Economy.shop_buy(shop.id, entry_id)
	if reason.is_empty():
		Toast.show_message(get_tree(), "Bought %s (-%s)" % [info["name"], UIText.price(price)], info["icon"])
	else:
		Toast.show_message(get_tree(), reason)
	_refresh()


func _on_slot_activated(index: int) -> void:
	var id := Inventory.slot_id(index)
	if id.is_empty():
		return
	var all := Input.is_key_pressed(KEY_SHIFT) or _pad_held(JOY_BUTTON_X)
	var amount := Inventory.slot_count(index) if all else 1
	var earned := Economy.shop_sell(shop.id, id, amount, index)
	var item := Content.item(id)
	if earned > 0:
		Toast.show_message(get_tree(), "Sold %d x %s (+%s)" % [amount, item.display_name, UIText.price(earned)],
				item.icon)
	else:
		Toast.show_message(get_tree(), "%s won't buy that" % Content.npc(shop.keeper).display_name)
	_refresh()


func _on_state_changed(_coins: int, _delta: int) -> void:
	_refresh()


func _pad_held(button: JoyButton) -> bool:
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, button):
			return true
	return false


func _detach() -> void:
	if shop == null:
		return
	Economy.coins_changed.disconnect(_on_state_changed)
	Inventory.changed.disconnect(_refresh)
	Inventory.capacity_changed.disconnect(_rebind_grid)
	shop = null

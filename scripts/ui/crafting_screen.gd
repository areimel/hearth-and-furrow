class_name CraftingScreen extends UIScreen
## Modal crafting UI for one Station. Left: its recipes (greyed when locked or lacking
## inputs); right: the focused recipe's detail; below: running jobs. Accept starts a
## job, ui_cancel closes. Opening collects waiting output first. Instance
## scenes/ui/crafting_screen.tscn once under the HUD; Workstations finds it by group.

const CRAFTING_GROUP := &"CraftingScreen"
const LIST_WIDTH := 104
const FRAME_WIDTH := 270

var station: Station
var _focused_recipe: StringName
var _menu: ListMenu
var _detail: CraftingDetail
var _jobs_label: Label
var _frame: PanelFrame
var _recipe_ids: Array[StringName] = []


func _ready() -> void:
	super()
	add_to_group(CRAFTING_GROUP)
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


## Open the screen for `target`. Waiting output is collected first (and toasted).
func open_for(target: Station) -> void:
	_detach()
	station = target
	station.changed.connect(_on_station_changed)
	station.collected.connect(_on_collected)
	GameClock.minute_passed.connect(_on_minute)
	Inventory.changed.connect(_refresh_state)
	_frame.title = station.display_name()
	if station.has_output():
		station.collect()
	_fill_list()
	open()
	_focus_best()
	_refresh_state()


# ---------------------------------------------------------------- building

func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 4)
	_menu = ListMenu.new()
	_menu.custom_minimum_size.x = LIST_WIDTH
	_menu.max_rows = 6
	_menu.entry_selected.connect(_on_entry_selected)
	_menu.entry_focused.connect(_on_entry_focused)
	columns.add_child(_menu)
	_detail = CraftingDetail.new()
	columns.add_child(_detail)
	_frame.add_content(columns)
	_jobs_label = Label.new()
	_jobs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_jobs_label.add_theme_font_size_override("font_size", 8)
	_frame.add_content(_jobs_label)


func _fill_list() -> void:
	var entries: Array[Dictionary] = []
	_recipe_ids.clear()
	for recipe in Content.recipes_for_station(station.station_id):
		var first_output: StringName = recipe.outputs.keys()[0] if not recipe.outputs.is_empty() else &""
		var icon: Texture2D = Content.item(first_output).icon if not first_output.is_empty() else null
		entries.append({"text": recipe.display_name, "icon": icon, "payload": recipe.id})
		_recipe_ids.append(recipe.id)
	_menu.set_entries(entries)


func _focus_best() -> void:
	if _recipe_ids.is_empty():
		return
	var index := 0
	for i in _recipe_ids.size():
		if station.can_start(_recipe_ids[i]):
			index = i
			break
	_menu.entry_button(index).grab_focus()
	_focused_recipe = _recipe_ids[index]


# ---------------------------------------------------------------- refresh

func _refresh_state() -> void:
	if station == null:
		return
	for i in _recipe_ids.size():
		_grey(_menu.entry_button(i), not _is_available(_recipe_ids[i]))
	_show_detail()
	_show_jobs()


func _show_detail() -> void:
	if _focused_recipe.is_empty():
		return
	var recipe := Content.recipe(_focused_recipe)
	_detail.show_recipe(recipe, _block_reason(recipe))


func _show_jobs() -> void:
	var lines: Array[String] = []
	for job in station.jobs():
		var name := Content.recipe(job["recipe"]).display_name
		var left: int = job["minutes_left"]
		lines.append("%s: %s" % [name, "until morning" if left < 0 else CraftingText.minutes_text(left) + " left"])
	var slots := station.data().slots if station.data() else 1
	var header := "Working (%d/%d)" % [station.job_count(), slots] if not lines.is_empty() else "Idle"
	_jobs_label.text = "\n".join([header] + lines)


func _is_available(recipe_id: StringName) -> bool:
	var recipe := Content.recipe(recipe_id)
	return Progress.has_flag(recipe.unlock_flag) and station.inputs_missing(recipe).is_empty()


func _block_reason(recipe: RecipeData) -> String:
	if not Progress.has_flag(recipe.unlock_flag):
		return "Not yet learned"
	if not station.inputs_missing(recipe).is_empty():
		return "Missing ingredients"
	if not station.has_free_slot():
		return "All slots busy"
	return ""


func _grey(button: Button, greyed: bool) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		if greyed:
			button.add_theme_color_override(state, UIPalette.INK_DISABLED)
		else:
			button.remove_theme_color_override(state)


# ---------------------------------------------------------------- events

func _on_entry_focused(recipe_id: StringName) -> void:
	_focused_recipe = recipe_id
	_show_detail()


func _on_entry_selected(recipe_id: StringName) -> void:
	var recipe := Content.recipe(recipe_id)
	if station.start_job(recipe_id):
		var icon: Texture2D = Content.item(recipe.outputs.keys()[0]).icon if not recipe.outputs.is_empty() else null
		Toast.show_message(get_tree(), "Started: " + recipe.display_name, icon)
	else:
		Toast.show_message(get_tree(), _block_reason(recipe))
	_refresh_state()


func _on_station_changed() -> void:
	if is_open and station.has_output():
		station.collect()
	_refresh_state()


func _on_minute(_hour: int, _minute: int) -> void:
	_show_jobs()


func _on_collected(items: Dictionary) -> void:
	var parts: Array[String] = []
	var icon: Texture2D = null
	for id: StringName in items:
		var item := Content.item(id)
		parts.append("%d x %s" % [items[id], item.display_name])
		icon = icon if icon else item.icon
	Toast.show_message(get_tree(), "Collected " + ", ".join(parts), icon)


func _detach() -> void:
	if station == null:
		return
	station.changed.disconnect(_on_station_changed)
	station.collected.disconnect(_on_collected)
	GameClock.minute_passed.disconnect(_on_minute)
	Inventory.changed.disconnect(_refresh_state)
	station = null

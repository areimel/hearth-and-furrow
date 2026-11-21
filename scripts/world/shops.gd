class_name Shops extends Node
## Feature root for the village shops. Add scenes/world/shops.tscn as a child of Level:
## it attaches a "Trade" dialogue option to each shopkeeper through the `Villagers` node
## (group `Villagers`, `register_option(npc_id, text, callback, condition)`), and opens
## the ShopScreen on request. Without a Villagers node it still works through open().

## Group of the shop screen (found, or created under the first CanvasLayer).
const SCREEN_GROUP := &"ShopScreen"
const SCREEN_SCENE := preload("res://scenes/ui/shop_screen.tscn")
const VILLAGERS_GROUP := &"Villagers"
## Text of the dialogue option attached to every keeper.
const TRADE_TEXT := "Trade"

var _screen: ShopScreen


func _ready() -> void:
	_attach_options.call_deferred(true)


## Open shop `shop_id` on the shop screen. False if the id is unknown or the shop is
## shut (festival days close the shops).
func open(shop_id: StringName) -> bool:
	if not is_open_today():
		Toast.show_message(get_tree(), "The shops are shut for the festival.")
		return false
	if _screen == null or not is_instance_valid(_screen):
		_screen = ScreenLocator.find_or_create(get_tree(), SCREEN_GROUP, SCREEN_SCENE,
				self) as ShopScreen
	return _screen.open_for(shop_id)


## False on a festival day whose FestivalData closes the shops.
func is_open_today() -> bool:
	var festival := Calendar.festival_today()
	return festival == null or not festival.shops_closed


func _attach_options(retry: bool) -> void:
	var villagers := get_tree().get_first_node_in_group(VILLAGERS_GROUP)
	if villagers == null or not villagers.has_method(&"register_option"):
		if retry:
			# Deferred, not awaited: an await would resume on a freed node in tests.
			_attach_options.call_deferred(false)
		return
	for shop in Content.shops():
		villagers.call(&"register_option", shop.keeper, TRADE_TEXT, open.bind(shop.id),
				is_open_today)

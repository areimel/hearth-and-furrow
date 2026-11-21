extends Node
## Throwaway demo for screenshots: the level with the Shops feature root. Use with the
## harness, e.g.
##   godot --path . res://tools/screenshot.tscn -- --scene res://tools/shop_demo.tscn \
##       --setup chandler_buy --size 1280x720 --name chandler_buy
## Setup steps: chandler_buy, chandler_sell, smith, miller (all open the shop screen).

var _level: Level
var _shops: Shops


func _ready() -> void:
	SaveManager.new_game()
	_level = load("res://scenes/levels/level.tscn").instantiate()
	add_child(_level)
	_shops = load("res://scenes/world/shops.tscn").instantiate()
	_level.add_child(_shops)
	var menus: Node = _level.get_node("Overlay/CanvasLayer/Menus")
	menus.add_child(load("res://scenes/ui/shop_screen.tscn").instantiate())
	menus.add_child(load("res://scenes/ui/kit/toasts.tscn").instantiate())
	Economy.coins = 350
	Inventory.add(&"cheese", 3)
	Inventory.add(&"fleece", 2)
	Inventory.add(&"log", 7)
	Inventory.add(&"wheat_sheaf", 12)
	Inventory.add(&"milk", 4)


func chandler_buy() -> void:
	_shops.open(&"chandler")


func chandler_sell() -> void:
	_shops.open(&"chandler")
	var screen := get_tree().get_first_node_in_group(&"ShopScreen") as ShopScreen
	screen.show_tab(ShopScreen.Tab.SELL)
	for i in Inventory.size():
		if Inventory.slot_id(i) == &"cheese":
			screen._grid.slot_at(i).grab_focus()


func smith() -> void:
	_shops.open(&"blacksmith")


func miller() -> void:
	Inventory.add(&"grain", 5)
	_shops.open(&"miller")




## Saturday: the market-day banner and bonus prices on the sell tab.
func market() -> void:
	GameClock.day_index = 5
	chandler_sell()

extends Node

const TILE_SIZE = 16
var FORECAST_RAIN: bool

# ======== Plants ========
const PLANT_DATA = {
	Enum.Seed.TOMATO: {
		'texture': "res://graphics/plants/tomato.png",
		'icon_texture': "res://graphics/icons/tomato.png",
		'name':'Tomato',
		'h_frames': 3,
		'grow_speed': 0.75,
		'death_max': 3,
		'reward': Enum.Item.TOMATO},
	Enum.Seed.CORN: {
		'texture': "res://graphics/plants/corn.png",
		'icon_texture': "res://graphics/icons/corn.png",
		'name':'Corn',
		'h_frames': 3,
		'grow_speed': 1.0,
		'death_max': 2,
		'reward': Enum.Item.CORN},
	Enum.Seed.PUMPKIN: {
		'texture': "res://graphics/plants/pumpkin.png",
		'icon_texture': "res://graphics/icons/pumpkin.png",
		'name':'Pumpkin',
		'h_frames': 3,
		'grow_speed': 0.25,
		'death_max': 3,
		'reward': Enum.Item.PUMPKIN},
	Enum.Seed.WHEAT: {
		'texture': "res://graphics/plants/wheat.png",
		'icon_texture': "res://graphics/icons/wheat.png",
		'name':'Wheat',
		'h_frames': 3,
		'grow_speed': 1.0,
		'death_max': 3,
		'reward': Enum.Item.WHEAT}}

const SEED_TEXTURES = {
	Enum.Seed.TOMATO: preload("res://graphics/icons/tomato.png"),
	Enum.Seed.CORN: preload("res://graphics/icons/corn.png"),
	Enum.Seed.PUMPKIN: preload("res://graphics/icons/pumpkin.png"),
	Enum.Seed.WHEAT: preload("res://graphics/icons/wheat.png")
	}
# ======== END Plants ========


# ======== Fish ========
const FISH_DATA = {
	Enum.Fish.GRAY: {
		'icon_texture': "res://graphics/icons/grayfish.png",
		'name': "Gray Fish",
		'catch_speed': 20,
		'lose_speed': 10,
		'start_progress': 30,
		'frequency': "Common",
		'color': Color.PALE_GREEN
	},
	Enum.Fish.SILVER: {
		'icon_texture': "res://graphics/icons/silverfish.png",
		'name': "Silver Fish",
		'catch_speed': 15,
		'lose_speed': 15,
		'start_progress': 30,
		'frequency': "Rare",
		'color': Color.MEDIUM_PURPLE
	},
	Enum.Fish.GOLD: {
		'icon_texture': "res://graphics/icons/goldfish.png",
		'name': "Gold Fish",
		'catch_speed': 10,
		'lose_speed': 20,
		'start_progress': 30,
		'frequency': "Legendary",
		'color': Color.GOLDENROD
	}
	}
# ======== END Fish ========


# ======== Placeables (build mode) ========
const MACHINE_SCENE = {
	Enum.Machine.DELETE: {"scene": preload("res://scenes/objects/placeable.tscn")}}

const MACHINE_PREVIEW_TEXTURES = {
	Enum.Machine.DELETE: {'texture': preload("res://graphics/icons/delete.png"), 'offset': Vector2i(-8, -8)}}

const MACHINE_TEXTURES = {
	Enum.Machine.DELETE: preload("res://graphics/icons/delete.png")}
# ======== END Placeables ========
	
	
# ======== Tools ========
const TOOL_TEXTURES = {
	Enum.Tool.AXE: preload("res://graphics/icons/axe.png"),
	Enum.Tool.HOE: preload("res://graphics/icons/hoe.png"),
	Enum.Tool.WATER: preload("res://graphics/icons/water.png"),
	Enum.Tool.SWORD: preload("res://graphics/icons/sword.png"),
	Enum.Tool.FISH: preload("res://graphics/icons/fish.png"),
	Enum.Tool.SEED: preload("res://graphics/icons/wheat.png")
	}

const TOOL_STATE_ANIMATIONS = {
	Enum.Tool.HOE: 'Hoe',
	Enum.Tool.AXE: 'Axe',
	Enum.Tool.WATER: 'Water',
	Enum.Tool.SWORD: 'Sword',
	Enum.Tool.FISH: 'Fish',
	Enum.Tool.SEED: 'Seed',
	}
# ======== END Tools ========
	

# ======== Trees ========
const APPLE_TREE_HEALTH = 4
# ======== END Trees ========


# ======== Player ========
const PLAYER_SPEED = 70.0
var TARGET_HIGHLIGHTER: bool = false
# ======== END Player ========


# ======== Items ========
var unlocked_machines: Array[Enum.Machine] = [Enum.Machine.DELETE]
# ======== END Items ========


# ======== Hint HUD ========
var ControllerConnected = false

# item textures
const TEXTURES = {
	Enum.Item.WOOD: preload("res://graphics/icons/wood.png"),
	Enum.Item.APPLE: preload("res://graphics/icons/apple.png"),
	Enum.Item.FISH: preload("res://graphics/icons/goldfish.png"),
	Enum.Item.CORN: preload("res://graphics/icons/corn.png"),
	Enum.Item.TOMATO: preload("res://graphics/icons/tomato.png"),
	Enum.Item.PUMPKIN: preload("res://graphics/icons/pumpkin.png"),
	Enum.Item.WHEAT: preload("res://graphics/icons/wheat.png")}


var ITEMS_AMOUNT = {
	Enum.Item.WOOD: 5,
	Enum.Item.APPLE: 5,
	Enum.Item.FISH: 5,
	Enum.Item.CORN: 5,
	Enum.Item.WHEAT: 5,
	Enum.Item.PUMPKIN: 5,
	Enum.Item.TOMATO: 5}


var SEED_TO_ITEM = {
	Enum.Seed.TOMATO: Enum.Item.TOMATO,
	Enum.Seed.CORN: Enum.Item.CORN,
	Enum.Seed.PUMPKIN: Enum.Item.PUMPKIN,
	Enum.Seed.WHEAT: Enum.Item.WHEAT
}


var KEYBOARD_KEYS = {
	Enum.KEYBOARD.CHANGE_HIGHLIGHT : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyH.png"),
	Enum.KEYBOARD.CHANGE_MODE : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyM.png"),
	Enum.KEYBOARD.CHANGE_TOOL : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyE.png"),
	Enum.KEYBOARD.CHANGE_SEED : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyC.png"),
	Enum.KEYBOARD.CHANGE_MACHINE : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyE.png"),
	Enum.KEYBOARD.ACTION :preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/Space.png"),
	Enum.KEYBOARD.CHANGE_DAY :preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Keyboard/KeyTab.png"),
}

var KEYBOARD_CONTROLLER = {
	Enum.KEYBOARD.CHANGE_HIGHLIGHT : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonPlusDown.png"),
	Enum.KEYBOARD.CHANGE_MODE : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonPlusLeft.png"),
	Enum.KEYBOARD.CHANGE_TOOL : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonRB.png"),
	Enum.KEYBOARD.CHANGE_SEED : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonRight.png"),
	Enum.KEYBOARD.CHANGE_MACHINE : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonRB.png"),
	Enum.KEYBOARD.ACTION : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonDown.png"),
	Enum.KEYBOARD.CHANGE_DAY : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Input/Gamepad/ButtonPlusUp.png"),
}

var MODE_TEXTURE = {
	Enum.State.DEFAULT : preload("res://graphics/characters/farming_mode.png"),
	Enum.State.FISHING : preload("res://graphics/characters/farming_mode.png"),
	Enum.State.BUILDING : preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Items/Tool/Hammer.png"),
	Enum.State.HOUSE : preload("res://graphics/characters/farming_mode.png")	
}

var KEYBOARD_TO_ICONS = {
	Enum.KEYBOARD.CHANGE_MODE: MODE_TEXTURE,
	Enum.KEYBOARD.CHANGE_TOOL: TOOL_TEXTURES,
	Enum.KEYBOARD.CHANGE_MACHINE: MACHINE_TEXTURES,	
	Enum.KEYBOARD.CHANGE_SEED: SEED_TEXTURES,
	Enum.KEYBOARD.ACTION: {0: preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Emote/emote21.png")},
	Enum.KEYBOARD.CHANGE_DAY: {0: preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Skill Icon/Meteo/Moon.png")},
	Enum.KEYBOARD.CHANGE_HIGHLIGHT: {0: preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/radio_unchecked.png"),
									 1: preload("res://graphics/Ninja Adventure - Asset Pack/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/radio_checked.png")},	
} 
# ======== END Hint HUD ========

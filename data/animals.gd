extends RefCounted
## Livestock rows. Keys: name, price (coins from the shepherd), product, amount,
## every (days between products), feed (item eaten daily), sprite.

const P := preload("res://data/paths.gd")

const ROWS: Dictionary = {
	&"cow": {name = "Cow", price = 1000, product = &"milk", amount = 1, every = 1,
		feed = &"straw", sprite = P.NA_ANIMALS + "Cow/SpriteSheetWhite.png"},
	&"sheep": {name = "Sheep", price = 600, product = &"fleece", amount = 1, every = 3,
		feed = &"straw", sprite = P.PLACEHOLDER + "animal_sheep.png"},
	&"chicken": {name = "Hen", price = 200, product = &"egg", amount = 1, every = 1,
		feed = &"grain", sprite = P.NA_ANIMALS + "Chicken/SpriteSheetBrown.png"},
}

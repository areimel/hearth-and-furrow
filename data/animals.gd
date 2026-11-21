extends RefCounted
## Livestock rows. Keys: name, price (coins from the shepherd), product, amount,
## every (days between products), feed (item eaten daily), verb (collect prompt, optional),
## feed_seasons (seasons the feed item is needed; grazing covers the rest), sprite.

const P := preload("res://data/paths.gd")

const WINTER: Array[int] = [G.Season.WINTER]

const ROWS: Dictionary = {
	&"cow": {name = "Cow", price = 600, product = &"milk", amount = 1, every = 1,
		feed = &"straw", verb = "Milk", feed_seasons = WINTER,
		sprite = P.NA_ANIMALS + "Cow/SpriteSheetWhite.png"},
	&"sheep": {name = "Sheep", price = 350, product = &"fleece", amount = 1, every = 3,
		feed = &"straw", verb = "Shear", feed_seasons = WINTER,
		sprite = P.PLACEHOLDER + "animal_sheep.png"},
	&"chicken": {name = "Hen", price = 80, product = &"egg", amount = 1, every = 1,
		feed = &"grain", feed_seasons = WINTER,
		sprite = P.NA_ANIMALS + "Chicken/SpriteSheetBrown.png"},
}

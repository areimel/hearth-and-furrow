class_name AnimalData extends Resource
## A livestock species. Animals never die; unfed or neglected they stop producing.

## Unique animal id, e.g. &"cow".
@export var id: StringName
@export var display_name: String
## Coins to buy one from the shepherd.
@export var price: int = 0
## Item produced (milk, fleece, egg).
@export var product_item: StringName
## Items produced each time output is ready.
@export var product_amount: int = 1
## Days between products (1 = daily).
@export var product_days: int = 1
## Item eaten once per day from the trough; unfed animals do not produce that day.
@export var feed_item: StringName
## Prompt verb for collecting the product ("Milk", "Shear"); empty = "Collect <item>".
@export var collect_verb: String = ""
## G.Season values in which grazing is not enough and the feed item is needed.
@export var feed_seasons: Array[int] = []
@export var sprite_path: String
## Loaded sprite sheet (placeholder if missing).
@export var sprite: Texture2D

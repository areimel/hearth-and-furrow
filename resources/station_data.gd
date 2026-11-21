class_name StationData extends Resource
## A crafting station type. One generic station scene renders any of these; behaviour
## comes from the recipes whose `station` is this id (Content.recipes_for_station()).

## Unique station id, e.g. &"quern".
@export var id: StringName
@export var display_name: String
@export var description: String
## item id -> count needed to build/place the station on the farm.
@export var build_cost: Dictionary[StringName, int] = {}
## How many jobs may run at once.
@export var slots: int = 1
@export var texture_path: String
## Loaded texture (placeholder if missing).
@export var texture: Texture2D

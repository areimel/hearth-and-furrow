class_name RecipeData extends Resource
## Turns input items into output items at a station over in-game time.

## Unique recipe id, e.g. &"mill_flour".
@export var id: StringName
@export var display_name: String
## StationData id where this recipe runs.
@export var station: StringName
## item id -> count consumed when the job starts.
@export var inputs: Dictionary[StringName, int] = {}
## item id -> count produced when the job finishes.
@export var outputs: Dictionary[StringName, int] = {}
## In-game minutes the job takes (ignored when overnight is true).
@export var minutes: int = 60
## Job finishes in the day-end pass (GameClock.day_ending) regardless of start time.
@export var overnight: bool = false
## Progress flag required to see/use the recipe; empty = known from the start.
@export var unlock_flag: StringName

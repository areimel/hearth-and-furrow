class_name CropData extends Resource
## One crop species. Crops never die: out of season or (garden) unwatered they pause.

## Unique crop id, e.g. &"wheat". Distinct namespace from item ids.
@export var id: StringName
@export var display_name: String
## G.CropKind: FIELD (rain-fed) or GARDEN (must be watered each day to grow).
@export var kind: int = G.CropKind.FIELD
## G.Season values in which the crop grows. Outside them it pauses.
@export var seasons: Array[int] = []
## Item planted to sow this crop.
@export var seed_item: StringName
## Item given when reaped with the sickle.
@export var yield_item: StringName
## Items per reap before weed/storm/blight penalties.
@export var yield_amount: int = 1
## Growing days from sowing to ripe.
@export var days_to_mature: int = 1
## Days to ripen again after reaping; 0 = the plant is removed when reaped.
@export var regrow_days: int = 0
## Ripe crop can be flattened by a storm (Balance.STORM_MAX_LOSS).
@export var storm_sensitive: bool = false
## Can catch blight (yield * Balance.BLIGHT_YIELD_FACTOR).
@export var blight_sensitive: bool = false
## Sprite sheet path: growth frames laid out horizontally, last frame = ripe.
@export var sprite_path: String
## Number of horizontal frames in the sprite sheet.
@export var sprite_frames: int = 3
## Loaded sprite sheet (placeholder if missing).
@export var sprite: Texture2D


func grows_in(season: int) -> bool:
	return season in seasons


## Sprite frame for a crop of `age` growing days (0 .. sprite_frames-1).
func frame_for_age(age: int) -> int:
	if days_to_mature <= 0:
		return sprite_frames - 1
	var t: float = clampf(float(age) / float(days_to_mature), 0.0, 1.0)
	return mini(int(t * float(sprite_frames - 1)), sprite_frames - 1)

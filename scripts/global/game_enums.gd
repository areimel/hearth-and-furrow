class_name G
## Shared enums for Hearth & Furrow systems. Const-only; never instantiate.
## Values are stored in saves as ints, so only ever APPEND new members.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

## Day index 0 (Lady Day, spring 1, year 1) is a MONDAY.
enum Weekday { MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY }

enum WeatherKind { CLEAR, RAIN, STORM }

## FIELD crops are rain-fed and never need watering; GARDEN crops must be watered to grow.
enum CropKind { FIELD, GARDEN }

## What the action button does when a tool item is selected. NONE = not a tool.
enum ToolKind { NONE, AXE, HOE, WATERING_CAN, SICKLE, FISHING_ROD }

## Broad item grouping. "Raw" categories (obtained in the world, not crafted):
## CROP, ANIMAL_PRODUCT, MATERIAL, FORAGE, FISH.
enum ItemCategory { TOOL, SEED, CROP, ANIMAL_PRODUCT, MATERIAL, FORAGE, FISH, INGREDIENT, GOOD, UPGRADE }

## Result of Relationships.gift().
enum GiftReaction { LOVED, LIKED, NEUTRAL, DISLIKED, ALREADY_GIFTED, NOT_GIFTABLE }

enum QuestState { INACTIVE, ACTIVE, COMPLETE }

const RAW_CATEGORIES: Array[int] = [
	ItemCategory.CROP, ItemCategory.ANIMAL_PRODUCT, ItemCategory.MATERIAL,
	ItemCategory.FORAGE, ItemCategory.FISH,
]

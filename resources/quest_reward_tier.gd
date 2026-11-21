class_name RewardTier extends Resource
## A feast reward tier: reached when at least `min_count` items were contributed.
## Only the highest tier reached pays out, so each tier lists its full reward set.

## Items contributed to reach this tier (0 = for coming at all).
@export var min_count: int = 0
## Player-facing label, e.g. "A fair share".
@export var text: String
@export var rewards: Array[QuestReward] = []


## Rewards as one line, e.g. "60 coins, Friendship with all".
func describe() -> String:
	var parts: Array[String] = []
	for reward in rewards:
		var part := reward.describe()
		if not part.is_empty():
			parts.append(part)
	return ", ".join(parts)

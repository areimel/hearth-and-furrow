class_name UIText extends RefCounted
## Shared wording for numbers shown to the player, so every screen formats them alike.


## "12 coins" / "1 coin".
static func coins(amount: int) -> String:
	return "%d coin%s" % [amount, "" if amount == 1 else "s"]


## "45 min", "2 h", "1 h 30"; "Instant" for 0.
static func minutes(amount: int) -> String:
	if amount <= 0:
		return "Instant"
	if amount < 60:
		return "%d min" % amount
	if amount % 60 == 0:
		return "%d h" % (amount / 60)
	return "%d h %02d" % [amount / 60, amount % 60]

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


## Compact "12c" for tight list rows and toasts; use coins() in sentences.
static func price(amount: int) -> String:
	return "%dc" % amount


## A themed Label: `variation` is a theme type variation (NoteLabel, HintLabel, WarnLabel...),
## wrapped at `wrap_width` pixels when that is above 0. The one way scripts make styled text.
static func label(text: String = "", variation: StringName = &"", wrap_width: int = 0) -> Label:
	var made := Label.new()
	made.text = text
	if variation != &"":
		made.theme_type_variation = variation
	if wrap_width > 0:
		made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		made.custom_minimum_size.x = wrap_width
	return made

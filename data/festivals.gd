extends RefCounted
## Feast rows. Dialogue for each feast lives in data/dialogue_feasts.gd under the same id.
## Keys:
##   name, desc, note (Almanack history), season (G.Season), day (1..28)
##   loc (place id; the feast table stands there), gather (place whose child markers named
##   `spots`* the villagers stand on; default loc), spots (marker prefix, default "spot_")
##   start, end (hours, end exclusive), shops_closed
##   announce (morning toast on the day), reminder (toast the day before)
##   asks: [{targets (accepted item ids), amount, text}] what the feast table hopes for
##   tiers: [{min (items contributed), text, rewards: [{kind, target, amount, text}]}],
##          lowest first; only the highest tier reached pays out, and only if the player
##          came (min 0 = for coming at all). friendship_all goes to everyone gathered.

const ROWS: Dictionary = {
	&"may_day": {name = "May Day", season = G.Season.SPRING, day = 20,
		loc = &"village_green", gather = &"feast_ground", spots = "spot_", start = 9, end = 18,
		desc = "The maypole goes up on the green. Bring greenery for the garlands.",
		note = "On May morning villagers went out to bring in the may, hawthorn and green "
			+ "boughs, to deck the maypole. Many parishes chose a lord and lady of the May.",
		announce = "Today is May Day. The village gathers on the green.",
		reminder = "Tomorrow is May Day. Gather greenery for the garlands.",
		asks = [
			{targets = [&"hazel_rod"], amount = 6, text = "Green boughs"},
			{targets = [&"reed"], amount = 6, text = "Rushes to strew"},
			{targets = [&"egg", &"milk", &"butter", &"cheese", &"bread", &"ale", &"apple",
				&"hazelnut", &"blackberry"], amount = 2, text = "A treat for the table"},
		],
		tiers = [
			{min = 0, text = "Joined the dancing",
				rewards = [{kind = &"friendship_all", amount = 20}]},
			{min = 4, text = "A bough or two",
				rewards = [{kind = &"friendship_all", amount = 40}, {kind = &"coins", amount = 30}]},
			{min = 9, text = "A fine garland",
				rewards = [{kind = &"friendship_all", amount = 60}, {kind = &"coins", amount = 50},
					{kind = &"item", target = &"flax_seed", amount = 4}]},
			{min = 14, text = "Lord of the May",
				rewards = [{kind = &"friendship_all", amount = 80}, {kind = &"coins", amount = 80},
					{kind = &"item", target = &"flax_seed", amount = 4},
					{kind = &"item", target = &"cabbage_seed", amount = 4}]},
		]},
	&"harvest_home": {name = "Harvest Home", season = G.Season.AUTUMN, day = 7,
		loc = &"village_green", gather = &"feast_ground", spots = "spot_", start = 15, end = 22,
		desc = "The last load is in. Everyone brings something to the harvest supper.",
		note = "When the last load was carried, the farmer gave a supper for all who had "
			+ "brought in the harvest. Harvest Home was among the ploughman's feasting days.",
		announce = "Today is Harvest Home. The village gathers on the green at three.",
		reminder = "Tomorrow is Harvest Home. Set by the best of the year's work.",
		asks = [
			{targets = [&"wheat_sheaf"], amount = 6, text = "Wheat sheaves"},
			{targets = [&"bread"], amount = 2, text = "Loaves of bread"},
			{targets = [&"ale"], amount = 2, text = "Jugs of ale"},
			{targets = [&"cheese"], amount = 1, text = "A cheese"},
		],
		tiers = [
			{min = 0, text = "Sat at the supper",
				rewards = [{kind = &"friendship_all", amount = 20}]},
			{min = 3, text = "A fair share",
				rewards = [{kind = &"friendship_all", amount = 40}, {kind = &"coins", amount = 60}]},
			{min = 7, text = "A full basket",
				rewards = [{kind = &"friendship_all", amount = 60}, {kind = &"coins", amount = 120}]},
			{min = 11, text = "Lord of the Harvest",
				rewards = [{kind = &"friendship_all", amount = 80}, {kind = &"coins", amount = 200},
					{kind = &"item", target = &"linen_sack", amount = 1}]},
		]},
}

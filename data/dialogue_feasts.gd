extends RefCounted
## Feast dialogue, keyed by festival id (rows in data/festivals.gd). Pools:
##   host           npc id who speaks for the village (reminder, closing)
##   opt_greet      dialogue option every gathered villager offers during the feast
##   greet          {npc id: [lines]} what each says to it (one line is picked per day)
##   thanks         lines a villager at the table says when something is contributed
##   opt_eve, eve   the host's option and lines the day before
##   table          header line on the feast table screen
##   closing        the host's lines when the feast ends

const LINES: Dictionary = {
	&"may_day": {
		"host": &"reeve",
		"opt_greet": "A merry May to you!",
		"greet": {
			&"reeve": ["God give you a merry May! We have chosen our lord and lady. Mind you dance.",
				"The pole went up at dawn. Straight as a die, and no one fell off it this year."],
			&"chandler": ["I was up before light bringing in the may. Hawthorn on every door!",
				"Ribbons at a penny the yard, and I sold the lot by nine."],
			&"blacksmith": ["No forge today. Even an anvil wants a holiday.",
				"They asked me to dance. I said the bellows had my wind."],
			&"alewife": ["May ale, fresh tapped! The churchwardens take a penny a cup for the church.",
				"Drink, dance, and drink again. That is the order of the day."],
			&"miller": ["The wheel rests today. Ribbons on my hat and, for once, no flour.",
				"I danced with the lady of the May. My feet will not forgive me."],
			&"shepherd": ["Lambs are weaned and the young ones are dancing. I watch. Old knees.",
				"Sixty Mays I have seen. They are all merry, and this one more than most."],
		},
		"thanks": ["That will look fine on the garland!", "Green and fresh. Well gathered!",
			"Hang it high, by the ribbons.", "The may is in, and you brought it!"],
		"opt_eve": "Any news, reeve?",
		"eve": ["Tomorrow is May Day. The whole parish will be on the green from nine.",
			"Bring green boughs and rushes if you can. Hazel will do for the garlands."],
		"table": "Bring in the may: help deck the garlands.",
		"closing": ["The garlands are hung and the pipes have stopped. A good May, neighbour.",
			"Off to your bed. The fields will want you in the morning."],
	},
	&"harvest_home": {
		"host": &"reeve",
		"opt_greet": "A good harvest home!",
		"greet": {
			&"reeve": ["The last load is in. Eat, drink, and thank God for it.",
				"A fair harvest, and every sheaf counted. Sit, eat."],
			&"chandler": ["A harvest supper! I lit every candle I had left.",
				"Mind the goose, it is hot. I carved it myself."],
			&"blacksmith": ["I put an edge on every sickle in the parish this month. Tonight my arm rests.",
				"Good bread, good ale. A smith asks no more."],
			&"alewife": ["I brewed a week for this. Drink deep, it will not keep.",
				"Harvest ale, strong and sweet. Do not tell the reeve how strong."],
			&"miller": ["Full sacks at the mill and a full table here. A good year.",
				"Every grain of it ground fair. Ask anyone. Well, ask me."],
			&"shepherd": ["Harvest Home. The flock is fat and so am I, after this.",
				"I remember a wet harvest when I was a boy. Not this one. This one's golden."],
		},
		"thanks": ["That will grace the table!", "Now that is a year's good work.",
			"Set it by the goose, where all can see.", "The harvest is home, and yours with it!"],
		"opt_eve": "Any news, reeve?",
		"eve": ["Tomorrow is Harvest Home. Supper on the green from three in the afternoon.",
			"Bring what you can of the year's work: sheaves, a loaf, ale, a cheese."],
		"table": "Bring the harvest home: lay the supper table.",
		"closing": ["That is Harvest Home. The barns are full and so are we.",
			"Get you home to bed, neighbour, and God keep you through the winter."],
	},
}

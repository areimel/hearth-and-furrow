extends RefCounted
## Quest dialogue, keyed by quest id (rows in data/quests.gd). Every pool is an Array of
## lines said in order by the quest's giver. Pools:
##   intro          auto-started quests: said when the quest begins
##   steps          sequential quests: steps[i] is said when step i is done (the hand-off)
##   hints          sequential quests: hints[i] reminds what step i asks
##   offer          errands: said when the player accepts
##   progress       errands: chatter while the errand is under way
##   out_of_season  said instead of progress (and after the offer) while none of the
##                  quest's crops grows this season: when to come back, what to buy
##   complete       said on hand-in
##   perk / perk_short   the daily favour: granted / cannot (missing the exchange)
## Option texts (optional, else QuestGiver's defaults): opt_offer, opt_ready, opt_progress.

const LINES: Dictionary = {
	&"prologue": {
		"opt_progress": "What next, reeve?",
		"opt_ready": "All is done, reeve.",
		"intro": [
			"Good morrow, and welcome. Thomas Ashby, reeve. The priory has let you this holding from Lady Day.",
			"The house leaks and the ground is gone to weed, but it is yours to make good.",
			"You have seed wheat in your pack. Take the hoe, break a few strips of ground and sow four.",
		],
		"steps": [
			["Straight furrows, too. Wheat is a field crop: the rain waters it, not you.",
				"Now the garden. Sow a cabbage and water it from the pail; garden crops want a can each day."],
			["Good. Your cabbage will not grow a whit unless it is watered every day it stands.",
				"That is enough for one day. Go to your bed. Crops grow while you sleep."],
			["A new morning on your own land. The wheat wants eight days, the cabbage six if you keep it wet.",
				"When something is ripe, cut it with the sickle. Meanwhile, go down and meet the village."],
			["Your first harvest! Now see what it is worth. Thresh a wheat sheaf on the floor for grain."],
			["Grain and straw. Keep the straw; beasts eat it. Now grind the grain at the quern."],
			["Flour of your own growing. Bread is close now, but for that you need barm. Ask about.",
				"Before you go further, make yourself known. A tenant who keeps apart fares badly."],
			["The village knows your face now. Come and find me, I have something for you."],
		],
		"hints": [
			"Hoe a few strips and sow four of your seed wheat.",
			"Sow a cabbage and water it with the pail.",
			"Get you to bed. The day turns while you sleep.",
			"Wait for something to ripen, then reap it with the sickle.",
			"Thresh a wheat sheaf on the threshing floor.",
			"Grind your grain to flour at the quern.",
			"Go and talk to the neighbours. Four of us, at least.",
		],
		"complete": [
			"You have tilled, sown, reaped, threshed and ground. That is the year in small.",
			"Here: a little coin, and seed barley and linseed for the weeks ahead.",
			"Ned at the mill, Margery at the alehouse and Joan the chandler all want a hand. Go and ask them.",
		],
	},
	&"errand_miller_wheat": {
		"offer": [
			"Flour is all very well, but I should like to see what it becomes in your hands.",
			"Bake me a loaf. Flour and barm in a bread oven. Margery sells barm, or brew and keep your own.",
		],
		"progress": [
			"A loaf, neighbour. Flour, a spoon of barm, and a hot oven. Margery has the barm.",
		],
		"out_of_season": [
			"No wheat stands in winter. Sow seed wheat from Lady Day, or buy a sack of my flour meanwhile.",
		],
		"complete": [
			"Now that is a loaf. Raised high and baked through. You will make a baker yet.",
			"From now on bring me your grain and I shall grind it at fair measure. No thumb on the scale.",
		],
		"perk": ["Three measures of grain, two of flour. Fair measure, as promised."],
		"perk_short": ["Bring me three measures of grain and I shall grind them for you."],
	},
	&"errand_alewife_barley": {
		"offer": [
			"You want to learn the brewing? Then grow me barley. Seed barley, sown in spring or summer.",
			"Malt it overnight on the floor, brew it overnight in the vat. Bring me two jugs of your own.",
		],
		"progress": [
			"Barley, malt, then the vat. Two nights of waiting, and two jugs for me.",
			"Do not hurry the malt. Hurried ale is sour ale.",
		],
		"out_of_season": [
			"Barley is sown in spring and summer, my dear. Come back after Lady Day with seed barley.",
		],
		"complete": [
			"Let me taste. Mm. Sweet, clean, and not a hint of sourness. You have the knack.",
			"The froth off my vats is barm. Come by any day and I shall spare you some for your bread.",
		],
		"perk": ["Here, fresh from this morning's brew. Raise a good loaf with it."],
		"perk_short": ["Barm I have, my dear. Make room in your pack first."],
	},
	&"errand_chandler_linen": {
		"offer": [
			"The priory wants linen and I have more orders than hands. Could you weave me a bolt?",
			"Sow linseed in the garden and keep it watered. Ret the flax, spin it and weave it.",
		],
		"progress": [
			"Ret the flax in the tub overnight, spin the fibre on the distaff, then to the loom.",
			"Four lengths of thread make a bolt. Slow work, but it pays.",
		],
		"out_of_season": [
			"Flax is a spring and summer crop. Sow linseed when the year turns, and keep it watered.",
		],
		"complete": [
			"Fine, even weave. The prior's cellarer will be glad of it.",
			"Take your pay, and this sack I sewed from the last bolt. It will carry a good deal more.",
		],
	},
}

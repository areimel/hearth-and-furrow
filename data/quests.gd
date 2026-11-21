extends RefCounted
## Quest rows. Dialogue for each quest lives in data/dialogue_quests.gd under the same id.
## Keys:
##   title, desc, giver (npc id), requires (quest ids), note (Almanack history)
##   conditions: [{kind, target, targets, amount, text}] (kinds: QuestCondition constants)
##   rewards: [{kind, target, amount, text}] (kinds: QuestReward constants)
##   sequential (conditions are steps done in order), auto (starts by itself)
##   chain (data/recipes.gd CHAINS key it teaches), crops (crop ids its harvest needs)
##   perk: {text, gives {item: n}, takes {item: n}} daily favour once complete
## Probe keys (QuestCondition.PROBE, registered by QuestGiver): "sown.<crop id>" crops of
## that kind standing in the field, "watered.<crop id>" those on watered soil.

const ROWS: Dictionary = {
	&"prologue": {title = "A Holding of One's Own", giver = &"reeve", auto = true,
		sequential = true,
		desc = "You have taken the tenancy of a run-down holding on the priory's land. "
			+ "Thomas Ashby, the reeve, will see you settled.",
		note = "Lady Day, 25 March, opened the farming year and the legal one: rents fell "
			+ "due and new tenancies began. Much land was held of religious houses.",
		conditions = [
			{kind = &"probe", target = &"sown.wheat", amount = 4,
				text = "Till the soil and sow 4 seed wheat"},
			{kind = &"probe", target = &"watered.cabbage", amount = 1,
				text = "Sow a cabbage and water it"},
			{kind = &"days", amount = 1, text = "Sleep, and see a new day in"},
			{kind = &"counter", targets = [&"harvested.wheat_sheaf", &"harvested.cabbage"],
				amount = 1, text = "Reap a ripe crop with the sickle"},
			{kind = &"counter", target = &"crafted.grain", amount = 1,
				text = "Thresh a wheat sheaf for grain"},
			{kind = &"counter", target = &"crafted.flour", amount = 1,
				text = "Grind grain to flour at the quern"},
			{kind = &"met", amount = 4, text = "Meet the village: talk to 4 neighbours"},
		],
		rewards = [{kind = &"coins", amount = 50}, {kind = &"item", target = &"barley_seed",
			amount = 6}, {kind = &"item", target = &"flax_seed", amount = 4},
			{kind = &"friendship", target = &"reeve", amount = 50},
			{kind = &"flag", target = &"prologue_done"}]},
	&"errand_miller_wheat": {title = "A Loaf for the Miller", giver = &"miller",
		requires = [&"prologue"], chain = &"bread", crops = [&"wheat"],
		desc = "Ned Miller wants to see what your flour makes. Bake a loaf from flour and "
			+ "barm in the bread oven and bring it to him.",
		note = "Tenants had to grind at the lord's mill and pay the miller a toll, the "
			+ "multure, in grain. Bread was raised with barm, the froth of brewing ale.",
		conditions = [{kind = &"deliver_item", target = &"bread", amount = 1,
			text = "Bring Ned Miller a loaf"}],
		rewards = [{kind = &"coins", amount = 60},
			{kind = &"friendship", target = &"miller", amount = 100},
			{kind = &"flag", target = &"miller_fair_measure", text = "Fair measure at the mill"}],
		perk = {text = "Grind my grain, Ned?", takes = {&"grain": 3}, gives = {&"flour": 2}}},
	&"errand_alewife_barley": {title = "Malt and Mash", giver = &"alewife",
		requires = [&"prologue"], chain = &"ale", crops = [&"barley"],
		desc = "Margery Brewster will teach you to brew if you can grow the barley. Malt it, "
			+ "brew it, and bring her two jugs of your ale.",
		note = "English ale was brewed from malt without hops, soured within days, and was "
			+ "often brewed by women. Hopped beer, brought by Flemish brewers, was only beginning.",
		conditions = [{kind = &"counter", target = &"crafted.ale", amount = 2,
			text = "Brew 2 ale of your own"},
			{kind = &"deliver_item", target = &"ale", amount = 2, text = "Bring Margery 2 ale"}],
		rewards = [{kind = &"friendship", target = &"alewife", amount = 100},
			{kind = &"coins", amount = 40},
			{kind = &"flag", target = &"alewife_barm_share", text = "Barm from Margery daily"}],
		perk = {text = "Any barm to spare?", gives = {&"barm": 1}}},
	&"errand_chandler_linen": {title = "A Bolt of Linen", giver = &"chandler",
		requires = [&"prologue"], chain = &"linen", crops = [&"flax"],
		desc = "Joan Webbe has an order of linen for the priory and too few hands. Grow "
			+ "flax, ret it, spin it and weave her a bolt.",
		note = "Flax was pulled in summer and retted, soaked until the stems rotted, so the "
			+ "fibre could be beaten free, spun and woven into linen.",
		conditions = [{kind = &"deliver_item", target = &"linen", amount = 1,
			text = "Bring Joan Webbe a bolt of linen"}],
		rewards = [{kind = &"coins", amount = 120}, {kind = &"item", target = &"linen_sack",
			amount = 1}, {kind = &"friendship", target = &"chandler", amount = 100}]},
}

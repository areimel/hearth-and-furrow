extends RefCounted
## Quest rows (minimal; the quest agent fleshes these out).
## Keys: title, desc, giver (npc id), requires (quest ids),
## conditions: [{kind, target, amount, text}] (kinds: QuestCondition constants),
## rewards: [{kind, target, amount}] (kinds: QuestReward constants).

const ROWS: Dictionary = {
	&"prologue": {title = "A New Tenant", giver = &"reeve",
		desc = "Present yourself to the reeve and take up the holding.",
		conditions = [{kind = &"talk_to", target = &"reeve", text = "Speak with the reeve"}],
		rewards = [{kind = &"coins", amount = 50}, {kind = &"flag", target = &"prologue_done"}]},
	&"errand_miller_wheat": {title = "Grist for the Mill", giver = &"miller",
		requires = [&"prologue"], desc = "The miller is short of wheat.",
		conditions = [{kind = &"deliver_item", target = &"wheat_sheaf", amount = 5,
			text = "Bring the miller 5 wheat sheaves"}],
		rewards = [{kind = &"coins", amount = 80}, {kind = &"friendship", target = &"miller",
			amount = 100}]},
	&"errand_alewife_barley": {title = "Barley for the Brew", giver = &"alewife",
		requires = [&"prologue"], desc = "Margery needs barley before market day.",
		conditions = [{kind = &"deliver_item", target = &"barley", amount = 6,
			text = "Bring the alewife 6 barley"}],
		rewards = [{kind = &"item", target = &"barm", amount = 3},
			{kind = &"friendship", target = &"alewife", amount = 100}]},
	&"errand_chandler_linen": {title = "A Bolt of Linen", giver = &"chandler",
		requires = [&"prologue"], desc = "Joan wants linen for the priory.",
		conditions = [{kind = &"deliver_item", target = &"linen", amount = 1,
			text = "Bring the chandler a bolt of linen"}],
		rewards = [{kind = &"coins", amount = 200}, {kind = &"friendship", target = &"chandler",
			amount = 100}]},
}

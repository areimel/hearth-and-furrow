extends RefCounted
## Almanack notes for the production chains (keys of data/recipes.gd CHAINS): one or two
## plain sentences of history each. Quest and feast notes live on their own rows
## (QuestData.note, FestivalData.note).

const CHAINS: Dictionary = {
	&"bread": "Wheat made the finest loaf; most households ate bread of rye, barley or "
		+ "maslin, a mixed grain. Grain was threshed with a flail on the barn floor.",
	&"dairy": "Butter and cheese were the work of the farm's women. Hard cheese kept "
		+ "through the winter; butter was salted down to last.",
	&"ale": "Malting steeps barley until it sprouts, then dries it, turning its starch to "
		+ "sugar. The froth of the brew, barm, raised the household's bread.",
	&"linen": "Flax was pulled, retted in water until the stems rotted, beaten to free the "
		+ "fibre, then spun on the distaff and woven on the loom.",
}

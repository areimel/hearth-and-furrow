extends RefCounted
## Thomas Ashby, the reeve. Elected by the tenants to run the field work; the village's
## guide to how the farm works. Pool keys are documented in data/dialogue.gd.

const LINES: Dictionary = {
	"greet_low": [
		"Good morrow. You are the new tenant, I take it. Ashby, reeve of this parish.",
		"Mind the hedges and the neighbours, and we shall get along.",
		"A fresh hand on the old holding. Come to me when you want advice.",
	],
	"greet_mid": [
		"Good morrow, neighbour. The parish speaks well of your work.",
		"Ah, there you are. I was hoping you would pass by the green.",
		"You keep your furrows straight. That is half of good farming.",
	],
	"greet_high": [
		"My friend! The day goes better for the sight of you.",
		"Sit a while, if you can spare it. Little is gained by hurrying.",
		"I have held this office eleven years, and never had a tenant I trusted more.",
	],
	"spring": [
		"Lady Day has come and gone. Sow while the soil is soft.",
		"Spring is for wheat, barley and peas. Do not wait for the swallows.",
	],
	"summer": [
		"The weeds grow faster than the corn in summer. Keep after them.",
		"Flax and cabbage thrive in the warm months. Water them well.",
	],
	"autumn": [
		"Harvest is the whole year's wages. Bring it in before the weather turns.",
		"Michaelmas rent is coming. Have your coin counted ahead.",
	],
	"winter": [
		"Little grows in winter. Mend your tools and your fences.",
		"A quiet season. Good for baking, brewing and thinking.",
	],
	"rain": [
		"A wet day. Do not trouble the field crops; the rain will water them.",
		"Rain on the open field is a gift. Garden beds still want the can, though.",
	],
	"market": [
		"Market day, and prices run high. Bring your goods to the cross.",
		"Saturday: the stalls are up and the buyers are generous. Sell well.",
	],
	"loved": [
		"A fine gift! You honour me. I shall not forget it.",
		"Now that is a kindness, and no mistake. Thank you.",
	],
	"liked": [
		"Why, thank you. That will not go to waste.",
		"A thoughtful gift. The parish is lucky to have you.",
	],
	"neutral": [
		"Kind of you. I shall find a use for it.",
		"Well, you need not have, but I thank you.",
	],
	"disliked": [
		"Hm. I am sure you meant well.",
		"Ah. Not quite to my taste, but I take the thought.",
	],
	"already": [
		"You have been generous enough for one day. Come tomorrow.",
	],
	"lore": [
		"Field crops are rain-fed: wheat, barley, peas and beans need no can, only weather.",
		"Garden crops, flax and cabbage, must be watered by hand. Fill the can at the stream.",
		"Weeds steal yield. Clear them, or lose a quarter of the harvest for each.",
		"Reap with the sickle, not the hoe. Cut at the ripe sheaf and mind the stalk.",
		"Four chains feed a village: bread, dairy, ale and linen. Learn one, then the next.",
		"Wheat to grain, grain to flour, flour to bread. Each step has its own station.",
		"Barley is malted overnight, then brewed. Ale and barm both come of it.",
		"Flax is retted, spun and woven. Slow work, but linen sells dear.",
	],
}

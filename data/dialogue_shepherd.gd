extends RefCounted
## Old Wat, the shepherd: weather lore (forecast_* lines hint tomorrow's real weather),
## sheep, and the dairy.

const LINES: Dictionary = {
	"greet_low": [
		"Mornin'. Wat. Sheep are my business. Do not frighten them.",
		"Hm. A new face. The ewes seem to like you, which is something.",
		"Quiet up here, as I like it. But you may stay a minute.",
	],
	"greet_mid": [
		"Well met, neighbour. The flock knows your step now.",
		"Good morrow. Sit by me. They do not mind.",
		"I have watched you work. You have patience. Rare, that.",
	],
	"greet_high": [
		"My friend. There is an old man glad of your company.",
		"I told the ewes you were coming. They looked pleased. I think.",
		"You are the nearest thing to family on this hill. I mean it.",
	],
	"spring": [
		"Lambing is the heart of my year. Little sleep, much joy.",
		"Spring grass is rich. The ewes give good milk.",
	],
	"summer": [
		"Shearing time. A good fleece is worth more than gold, near enough.",
		"Hot days on the hill. I rest in the hazel shade at noon.",
	],
	"autumn": [
		"The flock comes down from the hill. I count them twice.",
		"Nuts are thick in the hazels. Gather them before the squirrels.",
	],
	"winter": [
		"Cold on the hill, warm in the hut. I fetch the ewes in by dark.",
		"Frost makes the grass crisp. The sheep complain, loudly.",
	],
	"rain": [
		"Rain's upon us. The hut roof leaks, but only in one place.",
		"Wet fleece smells worse than anything. I stay in.",
	],
	"market": [
		"Market day. I bring cheese and wool down to the cross, once a week.",
		"Saturday: busy and loud. I prefer the hill.",
	],
	"forecast_clear": [
		"Red sky at night, shepherd's delight. Tomorrow will be fair, mark me.",
		"My knee is quiet and the swallows fly high. A dry day follows.",
		"The sheep graze on and do not huddle. Fair weather ahead, I reckon.",
	],
	"forecast_rain": [
		"The sheep are huddling and my knee aches. Rain by morning, I would wager.",
		"Swallows fly low, and the air smells of wet stone. Rain tomorrow.",
		"Cloud at dusk, and the wind has turned. You shall want your hat.",
	],
	"forecast_storm": [
		"Hear that? Sheep bleating at nothing. A storm is brewing, lad. Shelter your crops.",
		"The sky is bruised and my bones are loud. A storm tomorrow, I tell you.",
		"Birds have gone quiet and the cattle lie down. Storm, and a bad one.",
	],
	"loved": [
		"Well, I never. That is exactly what an old man wants. Thank you.",
		"Ha! You know me. This will not last the night.",
	],
	"liked": [
		"That is kind. I shall enjoy it on the hill.",
		"Why, thank you. A fine thing.",
	],
	"neutral": [
		"Hm. Aye. Thank you.",
		"Kind of you. The dog will like it.",
	],
	"disliked": [
		"Ale gives me a head like a ram. But thank you.",
		"Not for me. Still, the thought is welcome.",
	],
	"already": [
		"You have been generous today. Save it for tomorrow.",
	],
	"lore": [
		"Sheep give fleece in summer, milk in spring. Cows give milk all year.",
		"Feed your animals each day or they will not give. It is a simple bargain.",
		"Cheese presses overnight. Do not rush it, or it crumbles.",
		"Butter wants a churn and a strong arm. Milk goes in, butter comes out.",
		"Wool is the wealth of England. Remember that when you meet a sheep.",
		"A shepherd's coat is a woollen coat, and a woollen coat is a warm thing.",
	],
}

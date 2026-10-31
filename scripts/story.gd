extends RefCounted
## Apocrypha of the pilgrimage: a shade who waits in each land, and a leaf of Brelm's own journal hidden nearby.
## These are not scripture. They are what the Church calls the Hermit's Margins.

const SHADES := {
	"prologue": {
		"name": "A Silent Cleric, unhooded",
		"lines": [
			"You were the quietest of us, Brelm. We thought that meant you were the most content.",
			"We keep the silence because it is asked of us. You keep it because you are listening for something.",
			"If you go, go without hope of returning to tell us. That is the only way anyone has ever gone.",
		],
	},
	"cliffs": {
		"name": "A pilgrim who ate",
		"lines": [
			"I took one. Only one. It tasted of the morning I left home.",
			"Speeb did not punish me. That is the worst of it. He only looked, and I saw myself as he saw me.",
			"Fast, hermit. The hunger passes. The looking does not.",
		],
	},
	"ruins": {
		"name": "The last mason of the Fallen Kings",
		"lines": [
			"We built the towers to be seen from far away. We never asked who would be looking.",
			"Every king carved his name higher than the last. The rain has taken all of them at the same pace.",
			"Carve your warnings low, where a child can read them.",
		],
	},
	"wastes": {
		"name": "A stranger with empty hands",
		"lines": [
			"You beg like a man who has never had to. That is good. Keep the shame; it is honest.",
			"The grain does not care who plants it. Nor, I think, does Speeb. He cares only that it is planted.",
			"Share the alms. The field remembers the hand that was open.",
		],
	},
	"heights": {
		"name": "One who climbed and was cast down",
		"lines": [
			"I reached the summit once. I carried every grievance up with me, and I thought I had earned the view.",
			"Speebyeet does not hate you. It only returns you to the valley you never left.",
			"There is another on the stair, hermit. A hooded one. He climbs where you climbed, a day ahead, and writes.",
		],
	},
	"fields": {
		"name": "A woman who forgot her name",
		"lines": [
			"Do I know you? I think I knew someone like you, before the grass.",
			"The pawprints are faint, but they are always there. It is we who are faint.",
			"Someone came this way before you and read your name aloud from a book. I forgot it at once. Forgive me.",
		],
	},
	"caves": {
		"name": "A seeker who chose the crown",
		"lines": [
			"I went toward the gold light. It was so warm. It knew my name before I spoke it.",
			"The visions do not lie, hermit. They show you exactly what you want. That is the snare.",
			"The dark way promised me nothing. I could not bear it. I hope you can.",
		],
	},
	"hollow": {
		"name": "A sleeper, half-woken",
		"lines": [
			"Rest a while. The moss is soft. Nothing here asks anything of you.",
			"I lay down for a moment. I think it was a moment. My beard says otherwise.",
			"The hooded one slept here a hundred years, with a pen in his hand. When he woke he wrote faster.",
		],
	},
	"stone": {
		"name": "The keeper of the seal",
		"lines": [
			"Nine hundred have knelt here. Most stood up too soon, certain they had heard something.",
			"The Runespeeb does not speak to the still. It speaks through them, after.",
			"Two kneel at the seal tonight. You, and the one who is always a day ahead of you. Only one of you is breathing.",
		],
	},
	"lake": {
		"name": "A fisherman of the Silent Lake",
		"lines": [
			"I have cast my line here forty years and caught nothing. It is the best fishing in the world.",
			"Tread softly. The lake keeps the reflection of every footfall, and it will not forgive the loud ones.",
			"The lake shows two reflections when you pass. Do not look for the second. He is looking for you.",
		],
	},
}

const LEAVES := {
	"prologue": ["The First Leaf", "I laid down the mantle tonight. It weighed less than I feared and more than I can say. Let it be written that I did not leave in anger, only in hunger."],
	"cliffs": ["The Second Leaf", "Day four of the fast. The cravings speak in my mother's voice now. I answer none of them, and I am ashamed of how much I want to."],
	"ruins": ["The Third Leaf", "I found my own name scratched into a fallen tower, in a hand that was not mine. Whoever carved it was very sure of himself. I hope I never am."],
	"wastes": ["The Fourth Leaf", "A stranger gave me half his bread and would not say his name. I think the Speebchef was not in the meal at all, but in the halving."],
	"heights": ["The Fifth Leaf", "(The hand changes here. Smaller. Steadier. Not his.) Tomorrow he will climb the Heights and be cast down. He will rise. He always rises. I have written it so many times the ink knows the way."],
	"fields": ["The Sixth Leaf", "(The steady hand.) For seven days he will be no one, and he will find it restful. I envy him that. I have not been no one for a very long time. I have been Velm."],
	"caves": ["The Seventh Leaf", "(The steady hand.) He will choose the dark way. They always do, the ones who reach the caves. I will be waiting past the door. I will tell him the truth, and he will not believe it, because I did not."],
	"hollow": ["The Eighth Leaf", "(The steady hand, pressing harder now.) He will nearly stay in the Hollow. I did stay, once, for a hundred years. That is how I came to be ahead of him. Comfort is a road that goes in a circle."],
	"stone": ["The Ninth Leaf", "(Two hands now, one over the other, as though he took the pen and I did not let go.) He knelt until his knees forgot him. I knelt beside him the whole night. He did not see me. He will."],
	"lake": ["The Tenth Leaf", "(His hand alone, at last.) I read every page Velm wrote for me. I know how the Forgotten Cave ends. I am going anyway, to see whether a man can walk past the last written line."],
}

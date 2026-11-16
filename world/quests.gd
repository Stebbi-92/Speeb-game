class_name WQuests
extends Node
## The work of the waste: the beacons, the stories of its people, and the daily labour of keeping alive.
## The host keeps the record; every pilgrim of a fellowship shares it, and shares its rewards.

const MAX_ACTIVE := 6
const OFFERS_PER := 3

var w
var quests := {}
var offers := {}
var next_id := 1
var tracked := "main"
var _sent := {}
var nests := {}
var finds := {}

## The beacon road. Each step: t (reach, talk, kindle, count), and what is said.
const MAIN := [
	{"t": "reach", "at": "cinderwick", "text": "There is smoke to the <dir:S:cinderwick:start>. Find shelter before nightfall."},
	{"t": "talk", "who": "maud", "text": "Speak with the elder of Cinderwick.",
		"ask": "I was cast out. I have nowhere else to go.",
		"say": "Then you are one of us. Everyone here was thrown away by somebody.\n\nListen. When I was a girl there were nine fires on the high places, tended by the Order, and the night did not come within sight of them. One by one they went dark. Now it comes everywhere.\n\nThere is a dead beacon on the ridge to the west. I have kept one jar of the old oil for forty years, waiting for someone foolish enough to carry it there. Take it. Pour it in the bowl, and keep the flame alive until it holds. Do not leave it, whatever comes.",
		"give": [["beacon_oil", 1]]},
	{"t": "kindle", "beacon": 0, "text": "Kindle the Beacon of Restraint, <dir:B:0:cinderwick> of Cinderwick, and keep the flame until it holds."},
	{"t": "talk", "who": "maud", "text": "Return to Maud.",
		"ask": "The beacon burns.",
		"say": "I saw it from the wall. I wept, and I am not ashamed of it.\n\nThere is no more of the old oil. But the Lantern Well still draws lamp oil from the deep, and Benedek the oilwright knows the measure his father used for the Order. Go to the Well, <dir:S:lanternwell:cinderwick> of here. Ask him to teach you."},
	{"t": "talk", "who": "benedek", "text": "Find Benedek the oilwright at the Lantern Well.",
		"ask": "Maud sent me. I need beacon oil.",
		"say": "So the ridge fire was you. I wondered who had been fool enough.\n\nThe measure is this: two of lamp oil, ten of salt to cleanse it, four of ash-bloom to make it burn white. Render it slowly, at a proper bench, with a fire close by. Here. Take what I have made, and learn to make the rest yourself. There are eight more bowls out there, and I am too old to carry anything up a hill.",
		"give": [["beacon_oil", 1]], "flag": "oilcraft"},
	{"t": "count", "n": 4, "text": "Kindle more of the dead beacons. Render beacon oil at a workbench from lamp oil, salt and ash-bloom."},
	{"t": "talk", "who": "ione", "text": "Something about the beacons is wrong. The gravekeeper of Mourner's Rest listens to the dead. Ask her.",
		"ask": "The beacons were made to burn forever. Why did they go out?",
		"say": "I asked the dead the same thing, the night your third fire was lit. They were very quiet for a long time.\n\nThen they told me. The beacons did not fail. They were put out, by hand, one by one, by living people who walked up to them with sand and wet sacking. The dead say the hands came from Gallowmere, on the dry lake to the <dir:S:gallowmere:mourners>.\n\nGo carefully. People who will put out a light are people who have made a bargain with the dark."},
	{"t": "talk", "who": "corvin", "text": "Go to Gallowmere, on the dry lake far to the <dir:S:gallowmere:cinderwick>, and speak with its warden.",
		"ask": "You put out the beacons.",
		"say": "Yes. I did. My father did. His father before him.\n\nYou think the night comes from nowhere. It comes up out of a mouth in the earth, <dir:B:8:gallowmere> of here, where the ninth beacon stood. When the ninth was lit, the mouth was quiet. Then it swallowed the beacon whole, tower and bowl and keepers, and it began to speak.\n\nIt asked for the other eight. It said: put them out, and I will leave Gallowmere standing. So we did. And we are standing. Do you understand? Every fire you light, it will want back. Light all eight, and it will have to come up and take them itself. Perhaps then you can do what we could not."},
	{"t": "count", "n": 8, "text": "Kindle all eight beacons that still stand. The ninth was swallowed; the mouth will have to answer."},
	{"t": "talk", "who": "corvin", "text": "Eight fires burn. Return to the warden of Gallowmere.",
		"ask": "Eight are burning. What now?",
		"say": "Now it is angry. I have not heard it this loud since I was a boy.\n\nThe ninth bowl stands at the lip of the mouth, <dir:B:8:gallowmere> of here, choked with earth. Pour oil into it and it will take, and the thing below will come up to put it out. If you keep that flame, it will have to go back down, and stay down.\n\nTake this. It is the last oil Gallowmere hid from the dark. I never had the courage to use it. Gallowmere will stand with you on the lip. That is the least we owe.",
		"give": [["beacon_oil", 2]]},
	{"t": "kindle", "beacon": 8, "text": "Kindle the Beacon of Stillness at the lip of the mouth, and keep it while the thing below comes up to put it out."},
	{"t": "talk", "who": "maud", "text": "It is done. Return to Cinderwick.",
		"ask": "The ninth burns. The mouth is quiet.",
		"say": "I know. The whole camp came out to look. You can see it from here, a white thread in the <dir:B:8:cinderwick>, like the one I remember.\n\nThe nights will still come. The waste is still the waste. Forms will still walk out of the dark where the fires do not reach. But they will not come for everything, and they will not come forever.\n\nThe waste is not saved, survivor. It is kept. And now there is someone to keep it."},
]

## The people's own stories. They are told once.
const STORIES := {
	"wagon": {"title": "The Gully Wagon", "giver": "tobin", "at": "cinderwick",
		"pitch": "There is a wagon down in the gully <dir:R:tobin_wagon:cinderwick> of here. I knew the driver. Will you go and look?",
		"steps": [
			{"t": "reach", "ruin": "tobin_wagon", "text": "Find the wagon in the gully, <dir:R:tobin_wagon:cinderwick> of Cinderwick."},
			{"t": "recover", "crate": "tobin_wagon_0", "item": "keepsake", "text": "Search the wagon for anything of the driver's."},
			{"t": "talk", "who": "tobin", "text": "Bring what you found to Tobin.", "ask": "I found these in the wagon. Prayer beads.",
				"say": "Hers. She counted them every night on the road. Forty-one beads, one for every year she drove.\n\nI will put them with the salt. It keeps things. Thank you. Here, take this. It was hers too, and she would want it used.", "take": ["keepsake", 1]},
		], "reward": {"salt": 40, "items": [["hatchet", 1]], "rep": 2}},
	"piet": {"title": "Piet's Jar", "giver": "ysolde", "at": "kiln",
		"pitch": "My brother Piet went out <dir:R:piet_camp:kiln> of here, toward a dead beacon. He never came back. I cannot make his jar until I know.",
		"steps": [
			{"t": "reach", "ruin": "piet_camp", "text": "Find Piet's last camp, <dir:R:piet_camp:kiln> of the Quiet Kiln."},
			{"t": "nest", "ruin": "piet_camp", "text": "Something has nested in the camp. Burn it out."},
			{"t": "recover", "crate": "piet_camp_0", "item": "piet_ring", "text": "Search the camp for anything of Piet's."},
			{"t": "talk", "who": "ysolde", "text": "Bring Piet's ring to Ysolde.", "ask": "I found this at his camp. He did not suffer long, I think.",
				"say": "His ring. He wore it on his thumb because his hands were too big for anything else.\n\nI will make his jar tonight. Red clay, his favourite. I will put the ring inside it, and write his name, and then he will be at the Kiln with all the others, and I can stop looking at the door.\n\nThank you.", "take": ["piet_ring", 1]},
		], "reward": {"salt": 60, "items": [["salve", 2]], "rep": 3}},
	"seal": {"title": "The Inward Seal", "giver": "ione", "at": "mourners",
		"pitch": "There is a vault in the hills where the Order put its dead. The dead in it are not quiet. Something was sealed in from the inside.",
		"steps": [
			{"t": "reach", "ruin": "sealed_vault", "text": "Find the Vault of the Inward Seal, <dir:R:sealed_vault:mourners> of Mourner's Rest."},
			{"t": "kill", "ruin": "sealed_vault", "n": 8, "text": "Undo the forms that keep the vault."},
			{"t": "recover", "crate": "sealed_vault_1", "item": "order_seal", "text": "Force the iron chest within the vault (it wants a pry bar)."},
			{"t": "talk", "who": "ione", "text": "Bring the seal to Ione.", "ask": "This was pressed into the door from the inside.",
				"say": "The Silent Clerics who sealed themselves in. I had heard it, but not believed it.\n\nWhen the beacons began to die, some of the Order did not run. They walled themselves in with their dead and kept silence until the end, so that the dark would find nothing to speak to. The seal says: we did not answer.\n\nKeep the oil I give you. Light something with it. That is the only answer worth giving.", "take": ["order_seal", 1]},
		], "reward": {"salt": 50, "items": [["beacon_oil", 1]], "rep": 3}},
	"archive": {"title": "The Archive Tower", "giver": "hesk_marro", "at": "hesk",
		"pitch": "The Order kept its records in a tower <dir:R:order_tower:hesk> of the Crossing. The ledgers would be worth a great deal to me. And to you.",
		"steps": [
			{"t": "reach", "ruin": "order_tower", "text": "Find the Archive Tower, <dir:R:order_tower:hesk> of Saint Hesk's Crossing."},
			{"t": "recover", "crate": "order_tower_0", "item": "keepsake", "text": "Search the tower for the Order's ledgers."},
			{"t": "talk", "who": "hesk_marro", "text": "Bring the ledgers to Marro.", "ask": "Your ledgers.",
				"say": "Hm. Accounts of oil carried, salt paid, and keepers fed, beacon by beacon. And here: a map of where each bowl stood, drawn by someone who had walked to every one.\n\nCopy it. You will want it more than I will. The rest I will sell to someone who misses the past.", "take": ["keepsake", 1], "reveal": "beacons"},
		], "reward": {"salt": 80, "items": [["coin", 4]], "rep": 2}},
	"caravans": {"title": "The Salt-Pan Caravans", "giver": "wren", "at": "cinderwick",
		"pitch": "The caravans <dir:R:salt_caravans:cinderwick> of the camp died in one night. Forms roost in the wagons now. They come down at dusk and test our wall.",
		"steps": [
			{"t": "kill", "ruin": "salt_caravans", "n": 10, "text": "Undo the forms roosting in the Salt-Pan Caravans, <dir:R:salt_caravans:cinderwick> of Cinderwick."},
			{"t": "talk", "who": "wren", "text": "Tell Wren it is done.", "ask": "The caravans are clear.",
				"say": "Good. I will not thank you; we are past that. Take these. You will need them more than I will, tonight."},
		], "reward": {"salt": 30, "items": [["shells", 40], ["bandage", 2]], "rep": 2}},
	"well": {"title": "What Turns at the Bottom", "giver": "benedek", "at": "lanternwell", "after": "oilcraft",
		"pitch": "The well is low. If I am to keep making oil for your fires, I need ash-bloom, and a great deal of it.",
		"steps": [
			{"t": "gather", "item": "herb", "n": 10, "who": "benedek", "text": "Bring Benedek ten ash-bloom.", "ask": "Ash-bloom, as you asked.",
				"say": "Good. Good. Here: two measures of beacon oil, fresh rendered. And do not ask me what I heard turning at the bottom of the well last night. I do not know, and I would rather not."},
		], "reward": {"salt": 20, "items": [["beacon_oil", 2]], "rep": 2}},
	# The town quest lines: each tale opens the next when it is done (after: done_<tale>)
	"ferry1": {"title": "The Last Crossing", "giver": "ash_lena", "at": "gallowmere",
		"pitch": "Before the lake died, my husband rowed people out to the isles. His boat went down off Hrafnsey, <dir:R:wreck_hrafn_0:gallowmere> of here, across the sea. His log was aboard.",
		"steps": [
			{"t": "recover", "crate": "wreck_hrafn_0", "item": "ferry_log", "text": "Find the ferryman's wreck on the shore of Hrafnsey, <dir:R:wreck_hrafn_0:gallowmere> across the sea, and search it."},
			{"t": "talk", "who": "ash_lena", "text": "Bring the log to Lena at Gallowmere.", "ask": "His log. It was dry, under the seat.",
				"say": "His hand. Every crossing, every name, every fare. He wrote down the weather too, like it mattered to anyone.\n\nThe last page is not a crossing. It says: the chapel on the fen rings by itself at night. Someone must take the bell away, or it will call them all. Then nothing.", "take": ["ferry_log", 1]},
		], "reward": {"salt": 60, "items": [["cloth", 6], ["wood", 20]], "rep": 2}},
	"ferry2": {"title": "The Bell on the Fen", "giver": "ash_lena", "at": "gallowmere", "after": "done_ferry1",
		"pitch": "He wrote that the Drowned Chapel rings by itself, and that the bell calls the dead up out of the water. Will you go and take it down?",
		"steps": [
			{"t": "kill", "ruin": "isle_fen", "n": 8, "text": "Undo the drowned that keep the chapel on the Sunk Fen, <dir:R:isle_fen:gallowmere> across the sea."},
			{"t": "recover", "crate": "isle_fen_0", "item": "chapel_bell", "text": "Search the Drowned Chapel for its bell."},
			{"t": "talk", "who": "ash_lena", "text": "Bring the bell to Lena.", "ask": "The bell. It did not ring once on the way back.",
				"say": "Good. Then it is only a bell now.\n\nI will hang it at the edge of the dry lake, where the jetty was. If it rings, I will know it is only the wind.\n\nThere is one more page. He saw lights on the iron isle, and a door that opened with a key. He never went in. I would like to know what was there.", "take": ["chapel_bell", 1]},
		], "reward": {"salt": 80, "items": [["bandage", 3]], "rep": 3}},
	"ferry3": {"title": "What the Ferryman Saw", "giver": "ash_lena", "at": "gallowmere", "after": "done_ferry2",
		"pitch": "The iron isle, Cogwright, <dir:R:isle_cog:gallowmere> across the sea. He saw a lit door there. Find out what is behind it.",
		"steps": [
			{"t": "reach", "ruin": "isle_cog", "text": "Find the Engine Vault on Cogwright, <dir:R:isle_cog:gallowmere> across the sea."},
			{"t": "kill", "ruin": "isle_cog", "n": 10, "text": "Clear the Engine Vault of what keeps it."},
			{"t": "recover", "crate": "isle_cog_1", "item": "engine_key", "text": "Force the iron chest in the vault (it wants a pry bar)."},
			{"t": "talk", "who": "ash_lena", "text": "Tell Lena what you found.", "ask": "Engines, still turning. Nobody tends them. This key locked them.",
				"say": "Engines. He thought it was a church.\n\nKeep the key. Keep the boat too, and use it. He would have liked that someone still crosses.", "take": ["engine_key", 1]},
		], "reward": {"salt": 150, "items": [["coin", 6]], "rep": 4}},
	"olives": {"title": "Salt for Olives", "giver": "orla", "at": "hesk",
		"pitch": "When I was a girl, ships came from Kalaja with olives. One of them never made it in. It lies on Kalaja's shore, <dir:R:wreck_kala_0:hesk> of here, across the sea.",
		"steps": [
			{"t": "recover", "crate": "wreck_kala_0", "item": "olive_cask", "text": "Search the wreck on Kalaja's shore, <dir:R:wreck_kala_0:hesk> across the sea."},
			{"t": "talk", "who": "orla", "text": "Bring the cask to Orla at the Crossing.", "ask": "One cask, still sealed.",
				"say": "Sealed with pitch, and stamped with the keep's mark. My father paid three salt a cask for these.\n\nThe keep sold them to keep its garrison fed. I wonder who it was feeding all those years, after the ships stopped.", "take": ["olive_cask", 1]},
		], "reward": {"salt": 70, "items": [["stew", 2]], "rep": 2}},
	"keep": {"title": "The Garrison of the Old Keep", "giver": "orla", "at": "hesk", "after": "done_olives",
		"pitch": "The Old Keep on Kalaja had a garrison waiting for an enemy that never came. Go and see who is still standing watch.",
		"steps": [
			{"t": "reach", "ruin": "isle_kala", "text": "Find the Old Keep on Kalaja, <dir:R:isle_kala:hesk> across the sea."},
			{"t": "kill", "ruin": "isle_kala", "n": 10, "text": "Relieve the Old Keep's watch. They will not stand down."},
			{"t": "recover", "crate": "isle_kala_1", "item": "keep_roll", "text": "Search the keep for its muster roll."},
			{"t": "talk", "who": "orla", "text": "Bring the roll to Orla.", "ask": "They were all present. Every day, for sixty years.",
				"say": "Sixty years at their posts, and the enemy was the night all along. It came from behind them.\n\nI will sell copies of this roll at the Crossing. People should know their names.", "take": ["keep_roll", 1]},
		], "reward": {"salt": 120, "items": [["coin", 4]], "rep": 3}},
	"seairon": {"title": "Iron from the Sea", "giver": "hal", "at": "kiln",
		"pitch": "My forge is starving. There is good iron in the wrecks off Cogwright, <dir:R:wreck_cog_1:kiln> across the sea. Ship iron rusts only on the skin.",
		"steps": [
			{"t": "recover", "crate": "wreck_cog_1", "item": "sea_iron", "text": "Search the wreck off Cogwright, <dir:R:wreck_cog_1:kiln> across the sea, for its iron."},
			{"t": "talk", "who": "hal", "text": "Bring the sea iron to Old Hal.", "ask": "Ship iron, as you asked.",
				"say": "Look at that. Rust on the skin and sound underneath, like I said.\n\nThis will make a good blade, or a better hinge. I will give you one of the first things I make with it.", "take": ["sea_iron", 1]},
		], "reward": {"salt": 60, "items": [["scrap", 20], ["prybar", 1]], "rep": 2}},
	"saga": {"title": "Names on the Stones", "giver": "ione", "at": "mourners", "after": "done_seal",
		"pitch": "The dead tell me there are stones on Hrafnsey with names cut into them. Names nobody has said in a hundred years. Bring me one.",
		"steps": [
			{"t": "reach", "ruin": "isle_hrafn", "text": "Find the Saga Stones on Hrafnsey, <dir:R:isle_hrafn:mourners> across the sea."},
			{"t": "kill", "ruin": "isle_hrafn", "n": 8, "text": "Undo what keeps the stones."},
			{"t": "recover", "crate": "isle_hrafn_0", "item": "saga_rubbing", "text": "Search by the stones for something to take the names on."},
			{"t": "talk", "who": "ione", "text": "Bring the names to Ione.", "ask": "Charcoal on cloth. These were cut into the tallest stone.",
				"say": "I will read them out tonight, one at a time, slowly. The dead like to hear the old names. It reminds them there were people before the night, and there will be people after it.", "take": ["saga_rubbing", 1]},
		], "reward": {"salt": 90, "items": [["beacon_oil", 1]], "rep": 3}},
	"moss": {"title": "The Fen Cure", "giver": "tamsin", "at": "saltreach",
		"pitch": "A wound that will not close is closing too many of my patients. There is a moss on the Sunk Fen, <dir:R:wreck_fen_0:saltreach> across the sea. The old books swear by it.",
		"steps": [
			{"t": "recover", "crate": "wreck_fen_0", "item": "fen_moss", "text": "Search the wreck on the Sunk Fen's shore, <dir:R:wreck_fen_0:saltreach> across the sea, where the moss grows thick."},
			{"t": "talk", "who": "tamsin", "text": "Bring the moss to Tamsin at Saltreach.", "ask": "Fen moss, damp still.",
				"say": "That is it. Grey-green, and it smells of nothing at all.\n\nI can make a dressing of it that holds better than anything we have. Take some. And if you ever see more of it, bring it.", "take": ["fen_moss", 1]},
		], "reward": {"salt": 50, "items": [["salve", 3], ["bandage", 3]], "rep": 2}},
	"lens": {"title": "A Lamp Across the Water", "giver": "aud", "at": "lastlight",
		"pitch": "The Old Keep on Kalaja had a lamp room. Its lens could throw light ten miles over water. Mine is cracked, and the night is getting closer.",
		"steps": [
			{"t": "recover", "crate": "isle_kala_0", "item": "lamp_lens", "text": "Search the Old Keep on Kalaja, <dir:R:isle_kala:lastlight> across the sea, for its lamp lens."},
			{"t": "talk", "who": "aud", "text": "Bring the lens to Aud at Lastlight.", "ask": "The lens. Not a scratch on it.",
				"say": "Look at it. Hold it to the sun and it throws a spot you could not look at.\n\nTonight the lamp will be seen from the sea. If anyone is still out there, they will know where the shore is.", "take": ["lamp_lens", 1]},
		], "reward": {"salt": 100, "items": [["oil", 4]], "rep": 3}},
	"coal": {"title": "The Coal Ship", "giver": "gorm", "at": "emberhollow",
		"pitch": "My grandfather's coal ship went down off Cogwright. There was a chart aboard showing where the good seam was. With it I could keep these fires lit for a generation.",
		"steps": [
			{"t": "recover", "crate": "wreck_cog_0", "item": "coal_chart", "text": "Search the wreck off Cogwright, <dir:R:wreck_cog_0:emberhollow> across the sea, for the coal chart."},
			{"t": "talk", "who": "gorm", "text": "Bring the chart to Gorm at Emberhollow.", "ask": "The chart. Coal, it says, here.",
				"say": "On Cogwright itself. So that is what fed the engines.\n\nI will send men when the sea is calm. You have done the hollow a great service, and it will not forget.", "take": ["coal_chart", 1]},
		], "reward": {"salt": 90, "items": [["coin", 3], ["torch", 4]], "rep": 3}},
}

const KEEPSAKES := ["a child's carved cat", "her mother's prayer beads", "the bell from our chapel", "a box of letters", "my father's knife", "a painted icon of Speeb", "the deed to our well", "his spectacles"]
const LOST := ["Anselm", "Brigid", "Coll", "Dagny", "Edda", "Fenn", "Gisla", "Hamo", "Ilse", "Jory", "Kester", "Lysa"]
const KIN := ["son", "daughter", "brother", "sister", "husband", "wife", "father", "apprentice"]


func main_stage() -> int:
	return int(quests.main.stage) if quests.has("main") else 0


func start_new() -> void:
	quests["main"] = {"id": "main", "title": "The Dead Beacons", "giver": "maud", "main": true, "steps": MAIN, "stage": 0, "have": 0, "state": "active", "reward": {}}


# ------------------------------------------------------------------ the record

func to_data() -> Dictionary:
	return {"quests": quests, "offers": offers, "next": next_id}


func from_data(d: Dictionary) -> void:
	quests = d.get("quests", {})
	offers = d.get("offers", {})
	next_id = int(d.get("next", 1))
	if not quests.has("main"):
		start_new()
	quests.main.steps = MAIN
	for qid in quests:
		_place_things(qid)
	refresh_hud()


func step_of(q: Dictionary) -> Dictionary:
	var st: Array = q.steps
	var i := int(q.stage)
	return st[i] if i < st.size() else {}


func active() -> Array:
	var out: Array = []
	for qid in quests:
		if quests[qid].state == "active":
			out.append(quests[qid])
	out.sort_custom(func(a, b): return a.get("main", false) and not b.get("main", false))
	return out


## Where the current step of a quest wants you to go.
func target_of(q: Dictionary):
	var s := step_of(q)
	if s.is_empty():
		return null
	match s.t:
		"reach":
			if s.has("at"):
				return w.gpos(WPlaces.spos(s.at))
			if s.has("ruin"):
				return _ruin_pos(s.ruin)
			return s.get("pos")
		"talk", "gather", "deliver":
			var who: String = s.who
			return w.people[who].pos if w.people.has(who) else null
		"kill", "nest", "recover", "find":
			if s.has("ruin"):
				return _ruin_pos(s.ruin)
			if s.has("crate"):
				return w.crates[s.crate].pos if w.crates.has(s.crate) else null
			return s.get("pos")
		"kindle":
			return w.beacon_nodes[int(s.beacon)].pos
		"count":
			var best = null
			var bd := INF
			for i in 8:
				if not i in w.lit:
					var d: float = w.beacon_nodes[i].pos.distance_to(w.player.global_position)
					if d < bd:
						bd = d
						best = w.beacon_nodes[i].pos
			return best
		"watch":
			return w.gpos(WPlaces.spos(s.at))
	return null


func _ruin_pos(id: String):
	for r in w.ruins:
		if r.id == id:
			return r.pos
	return null


func step_text(q: Dictionary) -> String:
	var s := step_of(q)
	if s.is_empty():
		return ""
	var t: String = WPlaces.words(s.text)
	match s.t:
		"kill", "watch":
			t += "   %d / %d" % [int(q.have), int(s.n)]
		"count":
			t += "   %d / %d" % [w.lit.size(), int(s.n)]
		"gather":
			t += "   %d / %d" % [mini(w.inv.count(s.item), int(s.n)), int(s.n)]
	return t


func refresh_hud() -> void:
	if not w or not w.hud:
		return
	if not quests.has(tracked) or quests[tracked].state != "active":
		tracked = "main" if quests.has("main") and quests.main.state == "active" else ""
		if tracked == "" and not active().is_empty():
			tracked = active()[0].id
	if tracked == "":
		w.hud.set_objective("")
		return
	var q: Dictionary = quests[tracked]
	var line := "%s\n%s" % [q.title, step_text(q)]
	# How far, and which way
	var t = target_of(q)
	if t is Vector3 and w.player:
		var me: Vector3 = w.player.global_position
		var d := Vector2(t.x - me.x, t.z - me.z).length()
		if d > 15.0:
			line += "\n%d m %s" % [int(d), WPlaces.dir_word(Vector2(me.x, me.z), Vector2(t.x, t.z))]
	var others := active().size() - 1
	if others > 0:
		line += "\n+%d more in the journal [%s]" % [others, Game.key_text("journal")]
	w.hud.set_objective(line)
	_check_recover()


# ------------------------------------------------------------------ what happens in the waste

func on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"kill":
			if not Net.authority():
				return
			var p: Vector3 = data.pos
			for q in active():
				var s := step_of(q)
				if s.t == "kill":
					var c = target_of(q)
					if c != null and p.distance_to(c) < 70.0:
						_progress(q.id, 1, int(s.n))
				elif s.t == "watch" and w.night:
					if Vector2(p.x, p.z).distance_to(WPlaces.spos(s.at)) < 90.0:
						_progress(q.id, 1, int(s.n))
		"move":
			var p: Vector3 = data.pos
			for q in active():
				var s := step_of(q)
				if s.t == "reach":
					var c = target_of(q)
					var r := 40.0 if s.has("at") else 25.0
					if c != null and Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < r:
						ask_advance(q.id)
		"lit":
			if not Net.authority():
				return
			for q in active():
				var s := step_of(q)
				if (s.t == "kindle" and int(s.beacon) == int(data.beacon)) or (s.t == "count" and w.lit.size() >= int(s.n)):
					advance(q.id, int(q.stage))
		"dawn":
			if not Net.authority():
				return
			for q in active():
				var s := step_of(q)
				if s.t == "watch" and int(q.have) >= int(s.n):
					advance(q.id, int(q.stage))
	refresh_hud()


func _progress(qid: String, n: int, need: int) -> void:
	var q: Dictionary = quests[qid]
	q.have = int(q.have) + n
	if int(q.have) >= need and step_of(q).t != "watch":
		advance(qid, int(q.stage))
	else:
		w.shared("_w_quest", [qid, q])


## Recovered things are counted the moment they are in someone's pack.
func _check_recover() -> void:
	for q in active():
		var s := step_of(q)
		if s.t == "recover" and w.inv.count(s.item) > 0:
			ask_advance(q.id)


func ask_advance(qid: String) -> void:
	if not quests.has(qid):
		return
	var key := "%s:%d" % [qid, int(quests[qid].stage)]
	if _sent.has(key) and Time.get_ticks_msec() - int(_sent[key]) < 3000:
		return
	_sent[key] = Time.get_ticks_msec()
	w.shared("_rq_qadvance", [qid, int(quests[qid].stage)])


## The host moves a quest on by one step, if it is still at the step the asker saw.
func advance(qid: String, stage: int) -> void:
	if not Net.authority() or not quests.has(qid):
		return
	var q: Dictionary = quests[qid]
	if int(q.stage) != stage or q.state != "active":
		return
	var s := step_of(q)
	q.stage = stage + 1
	q.have = 0
	if s.has("flag"):
		w.flags[s.flag] = true
	if int(q.stage) >= q.steps.size():
		q.state = "done"
	w.shared("_w_quest", [qid, q])
	w.shared("_w_qstep", [qid, stage])


## Everyone hears a step completed, and is given what it gives.
func step_done(qid: String, stage: int) -> void:
	if not quests.has(qid):
		return
	var q: Dictionary = quests[qid]
	var st: Array = q.steps
	if stage >= st.size():
		return
	var s: Dictionary = st[stage]
	if s.has("flag"):
		w.flags[s.flag] = true
	if s.has("give"):
		w.give(s.give)
	if s.get("reveal", "") == "beacons":
		for bp in WPlaces.beacon_points():
			w.reveal_place(bp, 60.0)
		w.hud.notify("The beacons are marked on your map.")
	if q.state == "done":
		_finish(q)
	else:
		var nxt := step_of(q)
		if not nxt.is_empty() and (q.id == tracked or q.get("main", false)):
			w.hud.notify("%s\n%s" % [q.title, WPlaces.words(nxt.text)])
		_place_things(qid)
	refresh_hud()


func _finish(q: Dictionary) -> void:
	if q.has("story"):
		w.flags["done_" + str(q.story)] = true
	w.sfx("choir", -6)
	var r: Dictionary = q.get("reward", {})
	var items: Array = []
	if int(r.get("salt", 0)) > 0:
		items.append(["salt", int(r.salt)])
	for it in r.get("items", []):
		items.append(it)
	w.give(items)
	var at: String = q.get("at", "")
	if at != "" and int(r.get("rep", 0)) > 0:
		w.rep[at] = int(w.rep.get(at, 0)) + int(r.rep)
	if q.get("main", false):
		w.hud.say("The Dead Beacons is complete. The waste goes on, and so do you.", 6.0)
	else:
		w.hud.notify("Done: %s" % q.title)
	_clear_things(q.id)


# ------------------------------------------------------------------ the people's work, offered fresh each dawn

func refresh_offers() -> void:
	if not Net.authority():
		return
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	for k in WPlaces.SETTLEMENTS:
		var list: Array = offers.get(k, [])
		# Old offers fade if not taken
		list = list.filter(func(o): return rr.randf() < 0.5)
		while list.size() < OFFERS_PER:
			list.append(_make_offer(k, rr))
		offers[k] = list
	# Stories open when their teller is ready
	for sid in STORIES:
		var st: Dictionary = STORIES[sid]
		if quests.has("story_" + sid):
			continue
		if st.has("after") and not w.flags.has(st.after):
			continue
		var list: Array = offers[st.at]
		var has := false
		for o in list:
			if o.get("story", "") == sid:
				has = true
		if not has:
			list.append(_story_offer(sid))
	w.shared("_w_offers", [offers])


func _story_offer(sid: String) -> Dictionary:
	var st: Dictionary = STORIES[sid]
	return {"id": "story_" + sid, "story": sid, "title": st.title, "giver": st.giver, "at": st.at, "pitch": st.pitch,
		"steps": st.steps, "reward": st.reward, "stage": 0, "have": 0, "state": "offered"}


func _make_offer(k: String, rr: RandomNumberGenerator) -> Dictionary:
	var givers: Array = []
	for pid in WPlaces.PEOPLE:
		if WPlaces.PEOPLE[pid].at == k:
			givers.append(pid)
	var giver: String = givers[rr.randi() % givers.size()]
	var gname: String = WPlaces.PEOPLE[giver].name
	var home: Vector2 = WPlaces.spos(k)
	var ruin: Dictionary = _ruin_near(home, 120.0, 520.0, rr)
	var kinds := ["gather", "gather", "hunt", "recover", "deliver", "scout", "nest", "watch", "find"]
	var kind: String = kinds[rr.randi() % kinds.size()]
	var o := {"id": "", "giver": giver, "at": k, "stage": 0, "have": 0, "state": "offered", "kind": kind}
	var salt := 20
	var back := {"t": "talk", "who": giver, "text": "Return to %s at %s." % [gname, WPlaces.SETTLEMENTS[k].name]}
	match kind:
		"gather":
			var opts := [["wood", 15, 30], ["stone", 15, 30], ["scrap", 6, 12], ["salt", 30, 60], ["cloth", 6, 12], ["herb", 5, 10], ["bone", 8, 16]]
			var g: Array = opts[rr.randi() % opts.size()]
			var n := rr.randi_range(g[1], g[2])
			var nm := Items.iname(g[0])
			o.title = "%s for %s" % [nm, WPlaces.SETTLEMENTS[k].name]
			o.pitch = ["We are short of %s, and the nights are long. Bring me %d, and I will make it worth your trouble." % [nm.to_lower(), n],
				"I need %d %s before the week is out. I will not ask where you find it." % [n, nm.to_lower()],
				"The wall needs mending and the stores are bare. %d %s would see us through." % [n, nm.to_lower()]][rr.randi() % 3]
			o.steps = [{"t": "gather", "item": g[0], "n": n, "who": giver, "text": "Bring %d %s to %s." % [n, nm, gname], "ask": "Here is the %s you asked for." % nm.to_lower(),
				"say": "Good. That will keep us another while."}]
			salt = int(Items.info(g[0]).value * n * 1.6) + 10
		"hunt":
			var n := rr.randi_range(6, 12)
			o.title = "The Forms at %s" % ruin.name
			o.pitch = "Forms have been gathering at %s. They come closer every night. Undo %d of them there, before they come all the way." % [ruin.name, n]
			o.steps = [{"t": "kill", "ruin": ruin.id, "n": n, "text": "Undo %d forms at %s." % [n, ruin.name]}, back.merged({"ask": "%s is quiet, for now." % ruin.name, "say": "For now is all any of us get. Thank you."})]
			salt = 25 + n * 3
		"recover":
			var thing: String = KEEPSAKES[rr.randi() % KEEPSAKES.size()]
			o.title = "Something Left at %s" % ruin.name
			o.pitch = "We left %s behind at %s, the night we ran. It is foolish to want it. I want it." % [thing, ruin.name]
			o.steps = [{"t": "recover", "crate": "%s_0" % ruin.id, "item": "keepsake", "text": "Search %s for %s." % [ruin.name, thing]},
				back.merged({"ask": "I found it. %s." % thing.capitalize(), "say": "You found it. I did not think anyone would go. Here, take this, and my thanks.", "take": ["keepsake", 1]})]
			salt = 35
		"deliver":
			var others: Array = []
			for pid in WPlaces.PEOPLE:
				if WPlaces.PEOPLE[pid].at != k:
					others.append(pid)
			var to: String = others[rr.randi() % others.size()]
			var tp: Dictionary = WPlaces.PEOPLE[to]
			var item := "letter" if rr.randf() < 0.5 else "goods"
			o.title = "Carried to %s" % WPlaces.SETTLEMENTS[tp.at].name
			o.pitch = "This must reach %s at %s. I cannot leave the camp, and there is no one else I trust on the road." % [tp.name, WPlaces.SETTLEMENTS[tp.at].name]
			o.steps = [{"t": "deliver", "item": item, "who": to, "text": "Carry the %s to %s at %s." % [Items.iname(item).to_lower(), tp.name, WPlaces.SETTLEMENTS[tp.at].name],
				"ask": "%s sent this, from %s." % [gname, WPlaces.SETTLEMENTS[k].name], "say": "From %s? I had thought them dead. Thank you for carrying it. Take this for the road." % gname, "take": [item, 1]}]
			o.hands = [[item, 1]]
			salt = 20 + int(home.distance_to(WPlaces.spos(tp.at)) / 20.0)
		"scout":
			var far: Dictionary = _ruin_near(home, 300.0, 800.0, rr)
			o.title = "A Look at %s" % far.name
			o.pitch = "No one has come back from %s in a month. Go and look upon it. Tell me if anyone is left." % far.name
			o.steps = [{"t": "reach", "ruin": far.id, "text": "Go and look upon %s." % far.name},
				back.merged({"ask": "I have been to %s." % far.name, "say": "And? No. Do not tell me. I can see it in your face. Here, for your trouble."})]
			salt = 20 + int(home.distance_to(Vector2(far.pos.x, far.pos.z)) / 15.0)
			o.rid = far.id
		"nest":
			o.title = "A Nest at %s" % ruin.name
			o.pitch = "Something is swelling at %s, a nest of the lesser forms. If it is left, it will burst. Burn it out." % ruin.name
			o.steps = [{"t": "nest", "ruin": ruin.id, "text": "Destroy the nest at %s." % ruin.name},
				back.merged({"ask": "The nest at %s is burned." % ruin.name, "say": "Then we will sleep tonight, some of us. Thank you."})]
			salt = 45
		"watch":
			var n := rr.randi_range(8, 14)
			o.title = "The Wall of %s" % WPlaces.SETTLEMENTS[k].name
			o.pitch = "Stand the wall with us tonight. We are too few. Undo %d of the forms that come for %s, and see us to the dawn." % [n, WPlaces.SETTLEMENTS[k].name]
			o.steps = [{"t": "watch", "at": k, "n": n, "text": "Keep %s through the night: undo %d forms within sight of it." % [WPlaces.SETTLEMENTS[k].name, n]},
				back.merged({"ask": "We kept the wall.", "say": "We did. I have not slept so well in a month as I did after the dawn. Take this."})]
			salt = 30 + n * 3
		"find":
			var nm: String = LOST[rr.randi() % LOST.size()]
			var kin: String = KIN[rr.randi() % KIN.size()]
			o.title = "Finding %s" % nm
			o.pitch = "My %s, %s, went to %s to scavenge and has not come back. Please. Find them." % [kin, nm, ruin.name]
			o.steps = [{"t": "find", "ruin": ruin.id, "name": nm, "text": "Find %s at %s." % [nm, ruin.name]},
				back.merged({"ask": "%s is alive. They are coming home." % nm, "say": "Alive. Alive. I have nothing worth what you have done. Take what I have."})]
			salt = 40
	o.reward = {"salt": salt, "items": _bonus(rr), "rep": 1}
	return o


func _bonus(rr: RandomNumberGenerator) -> Array:
	var pool := [["shells", 20], ["bandage", 2], ["meat", 3], ["oil", 1], ["cloth", 4], ["scrap", 4], ["salve", 1], ["coin", 2]]
	var out: Array = [pool[rr.randi() % pool.size()]]
	if rr.randf() < 0.35:
		out.append(pool[rr.randi() % pool.size()])
	return out


func _ruin_near(home: Vector2, rmin: float, rmax: float, rr: RandomNumberGenerator) -> Dictionary:
	var c: Array = []
	for r in w.ruins:
		var d := home.distance_to(Vector2(r.pos.x, r.pos.z))
		if d > rmin and d < rmax and not WPlaces.NAMED_RUINS.has(r.id):
			c.append(r)
	if c.is_empty():
		return w.ruins[rr.randi() % w.ruins.size()]
	return c[rr.randi() % c.size()]


func offers_from(pid: String) -> Array:
	var out: Array = []
	var k: String = WPlaces.PEOPLE[pid].at
	for o in offers.get(k, []):
		if o.giver == pid:
			out.append(o)
	return out


func accept(o: Dictionary) -> void:
	w.shared("_rq_accept", [Net.me(), o.at, o.id if o.id != "" else o.title])


func _find_offer(k: String, key: String) -> int:
	var list: Array = offers.get(k, [])
	for i in list.size():
		var o: Dictionary = list[i]
		if o.id == key or (o.id == "" and o.title == key):
			return i
	return -1


func rq_accept(by: int, k: String, key: String) -> void:
	if not Net.authority():
		return
	var i := _find_offer(k, key)
	if i < 0:
		return
	var side := 0
	for q in active():
		if not q.get("main", false):
			side += 1
	if side >= MAX_ACTIVE:
		Net.call_peer(by, "_w_note", ["You carry too much work already. Finish something first."])
		return
	var o: Dictionary = offers[k][i]
	offers[k].remove_at(i)
	var qid: String = o.id if o.id != "" else "q%d" % next_id
	next_id += 1
	o.id = qid
	o.state = "active"
	quests[qid] = o
	w.shared("_w_offers", [offers])
	w.shared("_w_quest", [qid, o])
	if o.has("hands"):
		Net.call_peer(by, "_w_give", [o.hands])
	# Quests belong to the whole fellowship: everyone hears of it and follows it
	w.shared("_w_taken", [by, qid])


func _place_things(qid: String) -> void:
	var q: Dictionary = quests[qid]
	if q.state != "active":
		_clear_things(qid)
		return
	var s := step_of(q)
	if s.is_empty():
		return
	if s.t == "nest" and not nests.has(qid):
		var c = target_of(q)
		if c != null:
			nests[qid] = w.make_nest(qid, c + Vector3(3, 0, 2))
	if s.t == "find" and not finds.has(qid):
		var c = target_of(q)
		if c != null:
			finds[qid] = w.make_lost(qid, c + Vector3(-2, 0, 3), s.name)
	if s.t != "nest" and nests.has(qid):
		if is_instance_valid(nests[qid]):
			nests[qid].queue_free()
		nests.erase(qid)
	if s.t != "find" and finds.has(qid):
		if is_instance_valid(finds[qid]):
			finds[qid].queue_free()
		finds.erase(qid)


func _clear_things(qid: String) -> void:
	for d in [nests, finds]:
		if d.has(qid):
			if is_instance_valid(d[qid]):
				d[qid].queue_free()
			d.erase(qid)


## A crate opened for a quest holds what the quest is looking for.
func cache_items(crate_id: String) -> Array:
	var out: Array = []
	for q in active():
		var s := step_of(q)
		if s.t == "recover" and s.crate == crate_id and not q.get("cached_%d" % int(q.stage), false):
			q["cached_%d" % int(q.stage)] = true
			out.append([s.item, 1])
	return out


## What a person may say about the work at hand: [label, callable].
func talk_options(pid: String) -> Array:
	var out: Array = []
	for q in active():
		var s := step_of(q)
		if s.is_empty() or not s.has("who") or s.who != pid:
			continue
		match s.t:
			"talk":
				var take: Array = s.get("take", [])
				if take.is_empty() or w.inv.count(take[0]) >= int(take[1]):
					out.append([WPlaces.words(s.ask), _turn_in.bind(q.id, int(q.stage), s)])
			"gather":
				if w.inv.count(s.item) >= int(s.n):
					out.append([WPlaces.words(s.ask), _turn_in.bind(q.id, int(q.stage), s)])
			"deliver":
				if w.inv.count(s.item) > 0:
					out.append([WPlaces.words(s.ask), _turn_in.bind(q.id, int(q.stage), s)])
	return out


func _turn_in(qid: String, stage: int, s: Dictionary) -> String:
	match s.t:
		"gather":
			w.inv.take(s.item, int(s.n))
		_:
			var take: Array = s.get("take", [])
			if not take.is_empty():
				w.inv.take(take[0], int(take[1]))
			elif s.t == "deliver":
				w.inv.take(s.item, 1)
	w.shared("_rq_qadvance", [qid, stage])
	return WPlaces.words(s.get("say", ""))

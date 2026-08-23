# data/events/events_human.gd
# Random world events for the Human faction.
# Each entry is a Dictionary with keys:
#   id        - unique string identifier
#   tier      - "S+", "S", "A", "B", "C", "D", or "F"
#               S+/S: villager gain or loss; D/F: trivial flavour
#   title     - short event name (shown in card + modal header)
#   body      - flavour paragraph shown in the modal
#   icon      - emoji / symbol for the notification card
#   effects   - Dictionary of what applying the event does:
#       resources  - {gold, food, wood, stone, science}  (can be negative)
#       pop_max    - int delta applied to population cap (can be negative)
#       pop_kill   - int number of living units to remove immediately (S/S+ only)
#       pop_gain   - int number of population units to add immediately (S/S+ only)
#   choices   - Array of {label, effects} — at least one "OK/Accept" choice.
#               If a choice has its own effects dict they STACK on top of base effects.
#               Leave effects null/empty to apply no additional change.
#
# Tier spawn weights (approximate %) — higher tier = rarer:
#   S+: 2   S: 5   A: 10   B: 15   C: 23   D: 25   F: 20

extends RefCounted

# ── Tier weight map (used by get_random_event_weighted) ─────────────────────
const TIER_WEIGHTS: Dictionary = {
	"S+": 2,
	"S":  5,
	"A":  10,
	"B":  15,
	"C":  23,
	"D":  25,
	"F":  20,
}

const EVENTS: Array = [

	# ════════════════════════════════════════════════════════════
	# F  TIER — trivial, nothing really happened today
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_f1",
		"tier": "F",
		"title": "A Quiet Day",
		"body": "The sun rose, the sun set. Nothing of note disturbed the settlement. The townsfolk went about their business in blissful routine.",
		"icon": "☁",
		"effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Noted.", "effects": null}
		]
	},
	{
		"id": "event_human_f2",
		"tier": "F",
		"title": "Stray Dog Adopted",
		"body": "A friendly stray wandered into the marketplace and was promptly adopted by the blacksmith's apprentice. The town is briefly charmed.",
		"icon": "🐕",
		"effects": {"resources": {"gold": 0, "food": -2, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Aww. (Food -2)", "effects": null}
		]
	},
	{
		"id": "event_human_f3",
		"tier": "F",
		"title": "Minor Street Squabble",
		"body": "Two merchants argued loudly outside the inn for most of the afternoon. A guard had to intervene. Productivity dropped slightly.",
		"icon": "🗣",
		"effects": {"resources": {"gold": -5, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Move Along (Gold -5)", "effects": null}
		]
	},
	{
		"id": "event_human_f4",
		"tier": "F",
		"title": "Idle Gossip",
		"body": "Rumours spread through the tavern about a distant kingdom's troubles. The townsfolk are briefly distracted, but spirits are high.",
		"icon": "💬",
		"effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 2}, "pop_max": 0},
		"choices": [
			{"label": "Let Them Talk (Science +2)", "effects": null}
		]
	},

	# ════════════════════════════════════════════════════════════
	# D  TIER — minor, a noticeable but unremarkable consequence
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_d1",
		"tier": "D",
		"title": "Timber Windfall",
		"body": "A storm topples a section of the nearby forest. The felled trees are easy to collect — a sudden bounty of lumber for your workers.",
		"icon": "🌲",
		"effects": {"resources": {"gold": 0, "food": 0, "wood": 120, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Gather the Wood (Wood +120)", "effects": null}
		]
	},
	{
		"id": "event_human_d2",
		"tier": "D",
		"title": "Passing Trader",
		"body": "A small caravan passes through town and purchases surplus goods. It's not a large deal, but the coffers are a little heavier.",
		"icon": "🛒",
		"effects": {"resources": {"gold": 25, "food": -10, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Sell Surplus (Gold +25, Food -10)", "effects": null},
			{"label": "Decline", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_d3",
		"tier": "D",
		"title": "Cracked Cobblestones",
		"body": "The main road through the settlement has cracked badly after recent rains. Repairs are unavoidable if carts are to pass freely.",
		"icon": "🪨",
		"effects": {"resources": {"gold": -15, "food": 0, "wood": 0, "stone": -20, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Repair the Road (Gold -15, Stone -20)", "effects": null},
			{"label": "Leave It For Now", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_d4",
		"tier": "D",
		"title": "Bee Swarm in the Granary",
		"body": "A large swarm of bees has taken residence in the upper granary. Removing them costs some food stores but yields a little honey gold.",
		"icon": "🐝",
		"effects": {"resources": {"gold": 10, "food": -30, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Smoke Them Out (Gold +10, Food -30)", "effects": null},
			{"label": "Leave Them Be", "effects": {"resources": {"gold": 0, "food": -5, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# C  TIER — moderate, a clear but manageable event
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_c1",
		"tier": "C",
		"title": "Bumper Harvest",
		"body": "Favorable weather has blessed the fields. The harvest this season is plentiful, filling the granaries to the brim.",
		"icon": "🌾",
		"effects": {"resources": {"gold": 0, "food": 150, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Celebrate! (Food +150)", "effects": null}
		]
	},
	{
		"id": "event_human_c2",
		"tier": "C",
		"title": "Wandering Scholar",
		"body": "A learned scholar passes through, offering lectures to your townsfolk. Knowledge spreads quickly through the community.",
		"icon": "📚",
		"effects": {"resources": {"gold": -20, "food": 0, "wood": 0, "stone": 0, "science": 60}, "pop_max": 0},
		"choices": [
			{"label": "Invite Him In (Science +60, Gold -20)", "effects": null},
			{"label": "Let Him Pass", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 10}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_c3",
		"tier": "C",
		"title": "Abandoned Mine",
		"body": "Scouts report an abandoned mine shaft on the edge of your territory. It is risky, but the stone inside could be valuable.",
		"icon": "⛏",
		"effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 100, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Send Workers (Stone +100)", "effects": null},
			{"label": "Too Dangerous", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 5}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_c4",
		"tier": "C",
		"title": "Minor Fire at the Mill",
		"body": "A lantern was knocked over in the lumber mill, starting a small blaze. Workers scrambled to contain it, losing a portion of the stored timber.",
		"icon": "🔥",
		"effects": {"resources": {"gold": 0, "food": 0, "wood": -80, "stone": -10, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Rebuild Quickly (Wood -80, Stone -10)", "effects": null},
			{"label": "Salvage What Remains", "effects": {"resources": {"gold": 0, "food": 0, "wood": -40, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_c5",
		"tier": "C",
		"title": "Travelling Minstrels",
		"body": "A troupe of colourful minstrels passes through. Their performances lift spirits and leave the townsfolk inspired to work harder.",
		"icon": "🎵",
		"effects": {"resources": {"gold": -10, "food": 10, "wood": 0, "stone": 0, "science": 20}, "pop_max": 0},
		"choices": [
			{"label": "Host Them (Science +20, Food +10, Gold -10)", "effects": null},
			{"label": "Send Them Onward", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# B  TIER — significant, a real decision with meaningful stakes
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_b1",
		"tier": "B",
		"title": "The Merchant Arrives",
		"body": "A traveling merchant sets up a stall near the town gate. He offers to trade a modest sum of gold for local goods, briefly boosting the town's stores.",
		"icon": "💰",
		"effects": {"resources": {"gold": 80, "food": -20, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Trade (Gold +80, Food -20)", "effects": null},
			{"label": "Send Him Away", "effects": {"resources": {"gold": 0, "food": 20, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_b2",
		"tier": "B",
		"title": "Wandering Settlers",
		"body": "A group of wandering settlers passes by and asks to join your settlement. Extra hands mean extra mouths, but the workforce grows.",
		"icon": "🏘",
		"effects": {"resources": {"gold": 0, "food": -40, "wood": 0, "stone": 0, "science": 0}, "pop_max": 5},
		"choices": [
			{"label": "Welcome Them (Pop +5, Food -40)", "effects": null},
			{"label": "Turn Them Away", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_b3",
		"tier": "B",
		"title": "Plague Scare",
		"body": "A sickness spreads through the lower quarters. Several families flee before it can take hold, shrinking the population slightly.",
		"icon": "☠",
		"effects": {"resources": {"gold": -30, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -3},
		"choices": [
			{"label": "Quarantine (Pop Cap -3, Gold -30)", "effects": null},
			{"label": "Ignore It", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -6}}
		]
	},
	{
		"id": "event_human_b4",
		"tier": "B",
		"title": "Festival Season",
		"body": "The townsfolk propose a festival to boost morale. It will cost some food and gold, but the people will be energised and families may grow.",
		"icon": "🎉",
		"effects": {"resources": {"gold": -50, "food": -60, "wood": 0, "stone": 0, "science": 0}, "pop_max": 2},
		"choices": [
			{"label": "Hold the Festival (Pop +2, Gold -50, Food -60)", "effects": null},
			{"label": "Cancel", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_b5",
		"tier": "B",
		"title": "Flood Warning",
		"body": "Heavy rains upstream threaten to flood the lower farms. Reinforcing the banks now will save the harvest but drain the stone reserves.",
		"icon": "🌊",
		"effects": {"resources": {"gold": 0, "food": -100, "wood": -40, "stone": -60, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Reinforce the Banks (Food -100, Wood -40, Stone -60)", "effects": null},
			{"label": "Risk It", "effects": {"resources": {"gold": 0, "food": -200, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# A  TIER — major, high stakes resource or pop-cap swings
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_a1",
		"tier": "A",
		"title": "Noble's Patronage",
		"body": "A wealthy noble has heard tales of your growing settlement and wishes to invest. Their patronage will fill the coffers and advance research considerably.",
		"icon": "👑",
		"effects": {"resources": {"gold": 200, "food": 0, "wood": 0, "stone": 0, "science": 80}, "pop_max": 0},
		"choices": [
			{"label": "Accept Their Patronage (Gold +200, Science +80)", "effects": null},
			{"label": "Politely Decline", "effects": {"resources": {"gold": 20, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_a2",
		"tier": "A",
		"title": "Crop Blight",
		"body": "A mysterious blight has swept through the farmlands overnight. Entire fields are ruined. The population cap must shrink as families can no longer be sustained.",
		"icon": "🌿",
		"effects": {"resources": {"gold": 0, "food": -300, "wood": 0, "stone": 0, "science": 0}, "pop_max": -4},
		"choices": [
			{"label": "Ration Stores (Food -300, Pop Cap -4)", "effects": null},
			{"label": "Buy Emergency Food (Gold -120, Food -150, Pop Cap -2)", "effects": {"resources": {"gold": -120, "food": 150, "wood": 0, "stone": 0, "science": 0}, "pop_max": 2}}
		]
	},
	{
		"id": "event_human_a3",
		"tier": "A",
		"title": "Earthquake Tremors",
		"body": "The ground shook before dawn. Buildings cracked and stone reserves were buried under collapsed walls. Recovery efforts will take considerable resources.",
		"icon": "🌋",
		"effects": {"resources": {"gold": -80, "food": 0, "wood": -100, "stone": -200, "science": 0}, "pop_max": -2},
		"choices": [
			{"label": "Begin Repairs (Gold -80, Wood -100, Stone -200, Pop Cap -2)", "effects": null},
			{"label": "Prioritise Survivors (Gold -40, Pop Cap -4)", "effects": {"resources": {"gold": -40, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -2}}
		]
	},
	{
		"id": "event_human_a4",
		"tier": "A",
		"title": "Foreign Dignitary",
		"body": "An ambassador from a distant realm has arrived seeking an alliance. Hosting them is costly but the exchange of knowledge is unparalleled.",
		"icon": "🤝",
		"effects": {"resources": {"gold": -100, "food": -80, "wood": 0, "stone": 0, "science": 180}, "pop_max": 0},
		"choices": [
			{"label": "Host the Delegation (Science +180, Gold -100, Food -80)", "effects": null},
			{"label": "Brief Meeting Only (Science +40, Gold -20)", "effects": {"resources": {"gold": -20, "food": 0, "wood": 0, "stone": 0, "science": 40}, "pop_max": 0}}
		]
	},
	{
		"id": "event_human_a5",
		"tier": "A",
		"title": "Bandit Ambush",
		"body": "Bandits raided an outlying supply convoy. Resources were plundered and the escort barely made it back. The town is shaken.",
		"icon": "⚔",
		"effects": {"resources": {"gold": -120, "food": -80, "wood": -60, "stone": 0, "science": 0}, "pop_max": -2},
		"choices": [
			{"label": "Accept the Losses (Gold -120, Food -80, Wood -60, Pop Cap -2)", "effects": null},
			{"label": "Send a Punitive Party (Gold -60, chance to recover supplies)", "effects": {"resources": {"gold": 40, "food": 40, "wood": 30, "stone": 0, "science": 0}, "pop_max": 0}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# S  TIER — villagers gained or lost; life-altering for town
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_s1",
		"tier": "S",
		"title": "The Great Sickness",
		"body": "A virulent fever sweeps through the settlement. Despite the healers' best efforts, several townsfolk succumb. The town is in mourning.",
		"icon": "💀",
		"effects": {"resources": {"gold": -60, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -5, "pop_kill": 3},
		"choices": [
			{"label": "Quarantine & Treat (Pop -3, Pop Cap -5, Gold -60)", "effects": null},
			{"label": "Flee the District (Pop -6, Pop Cap -8)", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -3, "pop_kill": 3}}
		]
	},
	{
		"id": "event_human_s2",
		"tier": "S",
		"title": "Mass Migration",
		"body": "Word of your thriving settlement has spread far. A great wave of refugees and hopeful settlers arrives at the gates, seeking a new home.",
		"icon": "🚶",
		"effects": {"resources": {"gold": 0, "food": -150, "wood": -60, "stone": 0, "science": 0}, "pop_max": 10, "pop_gain": 6},
		"choices": [
			{"label": "Open the Gates (+6 people, Pop Cap +10, Food -150, Wood -60)", "effects": null},
			{"label": "Accept Only Some (+3 people, Pop Cap +5, Food -80)", "effects": {"resources": {"gold": 0, "food": -80, "wood": 0, "stone": 0, "science": 0}, "pop_max": 5, "pop_gain": 3}}
		]
	},
	{
		"id": "event_human_s3",
		"tier": "S",
		"title": "City of Refuge",
		"body": "A neighbouring settlement was destroyed and its survivors came to you for shelter. Taking them in is a heavy burden but grows your population considerably.",
		"icon": "🏚",
		"effects": {"resources": {"gold": 0, "food": -200, "wood": -80, "stone": -40, "science": 0}, "pop_max": 8, "pop_gain": 5},
		"choices": [
			{"label": "Shelter Them All (+5 people, Pop Cap +8, heavy resources)", "effects": null},
			{"label": "Offer Limited Aid (+2 people, Pop Cap +3, modest resources)", "effects": {"resources": {"gold": 0, "food": -80, "wood": -30, "stone": 0, "science": 0}, "pop_max": 3, "pop_gain": 2}}
		]
	},
	{
		"id": "event_human_s4",
		"tier": "S",
		"title": "Siege Aftermath",
		"body": "A skirmish at the settlement's edge left buildings damaged and lives lost. The survivors are resilient, but the town is smaller than it was at dawn.",
		"icon": "🛡",
		"effects": {"resources": {"gold": -100, "food": -80, "wood": -100, "stone": -80, "science": 0}, "pop_max": -6, "pop_kill": 4},
		"choices": [
			{"label": "Rebuild (Pop -4, Pop Cap -6, heavy resource cost)", "effects": null},
			{"label": "Abandon the Outer Walls (Pop -6, Pop Cap -8, less resource loss)", "effects": {"resources": {"gold": -40, "food": -40, "wood": -40, "stone": 0, "science": 0}, "pop_max": -2, "pop_kill": 2}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# S+ TIER — catastrophic or miraculous; reshapes the town
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_sp1",
		"tier": "S+",
		"title": "The Plague",
		"body": "A devastating plague tears through every quarter of the settlement. There is no stopping it — only managing the losses. The cries of the dying echo through the streets.",
		"icon": "☣",
		"effects": {"resources": {"gold": -150, "food": -200, "wood": 0, "stone": 0, "science": 0}, "pop_max": -12, "pop_kill": 8},
		"choices": [
			{"label": "Fight It With Everything (Pop -8, Pop Cap -12, Gold -150, Food -200)", "effects": null},
			{"label": "Sacrifice the Outer Quarters (Pop -12, Pop Cap -15, save resources)", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": -3, "pop_kill": 4}}
		]
	},
	{
		"id": "event_human_sp2",
		"tier": "S+",
		"title": "Golden Age",
		"body": "The stars align, the harvest is legendary, scholars flock to your halls, and a great lord pledges their fortune to your cause. A new era dawns for your people.",
		"icon": "✨",
		"effects": {"resources": {"gold": 400, "food": 400, "wood": 200, "stone": 200, "science": 200}, "pop_max": 15, "pop_gain": 10},
		"choices": [
			{"label": "Embrace the Golden Age (+10 people, all resources +400/200, Pop Cap +15)", "effects": null}
		]
	},
	{
		"id": "event_human_sp3",
		"tier": "S+",
		"title": "Dragon Sighting",
		"body": "A young dragon circled the settlement for hours before landing outside the walls. Whether it seeks tribute or simply rests is unclear, but terror has gripped the town.",
		"icon": "🐉",
		"effects": {"resources": {"gold": -200, "food": -150, "wood": -150, "stone": -100, "science": 0}, "pop_max": -8, "pop_kill": 5},
		"choices": [
			{"label": "Offer Tribute (Pop -5, Pop Cap -8, massive resource drain)", "effects": null},
			{"label": "Drive It Away (Pop -8, Pop Cap -10, minor resource loss)", "effects": {"resources": {"gold": -60, "food": -60, "wood": -60, "stone": 0, "science": 0}, "pop_max": -2, "pop_kill": 3}}
		]
	},
	{
		"id": "event_human_sp4",
		"tier": "S+",
		"title": "The Great Migration",
		"body": "An entire neighbouring nation is on the move — and they are heading here. Thousands arrive over the span of a day, overwhelming your capacity but swelling your strength enormously.",
		"icon": "🌍",
		"effects": {"resources": {"gold": 0, "food": -500, "wood": -200, "stone": -150, "science": 50}, "pop_max": 20, "pop_gain": 15},
		"choices": [
			{"label": "Accept All (+15 people, Pop Cap +20, enormous cost)", "effects": null},
			{"label": "Absorb Only the Skilled (+8 people, Pop Cap +12, half cost)", "effects": {"resources": {"gold": 0, "food": -250, "wood": -100, "stone": -75, "science": 30}, "pop_max": 12, "pop_gain": 8}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# A  TIER — marauder event
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_a9",
		"tier": "A",
		"category": "military",
		"title": "Marauder Scouts Spotted",
		"body": "Riders report a large warband setting up camp on the outskirts. You may pay tribute to delay them — or let them dig in. Either way, they are watching.",
		"icon": "🏕",
		"effects": {"resources": {"gold": -150, "food": -100, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0},
		"choices": [
			{"label": "Pay Tribute (Gold -150, Food -100 — they withdraw for now)", "effects": {"resources": {"gold": -150, "food": -100, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0}},
			{"label": "Let Them Camp (a marauder barracks spawns on the map)", "effects": {"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0, "spawn_wave": true}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# S  TIER — unavoidable marauder event
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_s5",
		"tier": "S",
		"category": "military",
		"title": "The War Party Descends",
		"body": "A disciplined enemy war party has crossed the border and erected a fortified barracks on your doorstep. There is no sending them away — only preparing for what comes next.",
		"icon": "⚔",
		"effects": {"resources": {"gold": -80, "food": -60, "wood": -80, "stone": -60, "science": 0}, "pop_max": 0, "spawn_wave": true},
		"choices": [
			{"label": "Fortify the Walls (resource cost, barracks spawns)", "effects": null},
			{"label": "Arm the People (Gold -120, barracks spawns)", "effects": {"resources": {"gold": -120, "food": 0, "wood": 0, "stone": 0, "science": 0}, "pop_max": 0, "spawn_wave": true}}
		]
	},

	# ════════════════════════════════════════════════════════════
	# S+ TIER — secret encoded event
	# ════════════════════════════════════════════════════════════
	{
		"id": "event_human_sp5",
		"tier": "S+",
		"category": "divine_light",
		"title": "Μονινγ τηρουγη τηε συν",
		"body": "Μονινγ τηρουγη τηε συν? Ωελλ δονε βυτ ψουρ ιουρνεψ ις νοτ ονερ ψετ.",
		"icon": "☉",
		"effects": {"resources": {"gold": 300, "food": 300, "wood": 300, "stone": 300, "science": 300}, "pop_max": 10, "pop_gain_pct": 30.0},
		"choices": [
			{"label": "Ωελλ δονε. Τηε πατη γοες ον.", "effects": null}
		]
	},
]

# ── Helpers ──────────────────────────────────────────────────────────────────

static func get_random_event(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Uniform random pick (legacy / debug). Use get_random_event_weighted for gameplay."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)

static func get_random_event_weighted(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Weighted random pick — rarer tiers appear far less often than common ones."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# Build a flat weighted pool (reference by index to avoid huge duplicated arrays)
	var pool: Array = []
	for i in EVENTS.size():
		var tier: String = EVENTS[i].get("tier", "C")
		var weight: int = TIER_WEIGHTS.get(tier, 10)
		for _w in range(weight):
			pool.append(i)
	if pool.is_empty():
		return {}
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	return EVENTS[idx].duplicate(true)

static func get_event_by_id(id: String) -> Dictionary:
	for ev in EVENTS:
		if ev["id"] == id:
			return ev.duplicate(true)
	return {}

static func get_tier_label(tier: String) -> String:
	"""Human-readable tier label with colour hint for UI."""
	match tier:
		"S+": return "[S+] LEGENDARY"
		"S":  return "[S] EPIC"
		"A":  return "[A] MAJOR"
		"B":  return "[B] NOTABLE"
		"C":  return "[C] MODERATE"
		"D":  return "[D] MINOR"
		"F":  return "[F] TRIVIAL"
		_:    return tier

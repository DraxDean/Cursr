# data/events/events_human.gd
# Random world events for the Human faction.
# Each entry is a Dictionary with keys:
#   id        - unique string identifier
#   tier      - "S+", "S", "A", "B", "C", "D", or "F"
#   title     - short event name (shown in card + modal header)
#   body      - flavour paragraph shown in the modal
#   icon      - emoji / symbol for the notification card
#   effects   - Dictionary of what applying the event does:
#       resources     - {gold, food, wood, stone, science}  (can be negative)
#       pop_kill      - int, remove this many living units immediately
#       pop_gain      - int, add this many new units immediately
#       pop_kill_pct  - float %, remove ceil(pop * pct/100) units (min 1)
#       pop_gain_pct  - float %, add   ceil(pop * pct/100) units (min 1)
#   choices   - Array of {label, effects} -- at least one "OK/Accept" choice.
#               Choice effects REPLACE base effects when non-null.
#
# Tier spawn weights (approximate %) -- higher tier = rarer:
#   S+: 2   S: 5   A: 10   B: 15   C: 23   D: 25   F: 20

extends RefCounted

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

	# F TIER
	{
		"id": "event_human_f1", "tier": "F",
		"title": "A Quiet Day",
		"body": "The sun rose, the sun set. Nothing of note disturbed the settlement.",
		"icon": "☁",
		"effects": {"resources": {}},
		"choices": [{"label": "Noted.", "effects": null}]
	},
	{
		"id": "event_human_f2", "tier": "F",
		"title": "Stray Dog Adopted",
		"body": "A friendly stray wandered into the marketplace and was adopted by the blacksmith's apprentice.",
		"icon": "🐕",
		"effects": {"resources": {"food": -2}},
		"choices": [{"label": "Aww. (Food -2)", "effects": null}]
	},
	{
		"id": "event_human_f3", "tier": "F",
		"title": "Minor Street Squabble",
		"body": "Two merchants argued outside the inn. A guard had to intervene. Productivity dropped slightly.",
		"icon": "🗣",
		"effects": {"resources": {"gold": -5}},
		"choices": [{"label": "Move Along (Gold -5)", "effects": null}]
	},
	{
		"id": "event_human_f4", "tier": "F",
		"title": "Idle Gossip",
		"body": "Rumours spread through the tavern about a distant kingdom. Spirits are high.",
		"icon": "💬",
		"effects": {"resources": {"science": 2}},
		"choices": [{"label": "Let Them Talk (Science +2)", "effects": null}]
	},

	# D TIER
	{
		"id": "event_human_d1", "tier": "D",
		"title": "Timber Windfall",
		"body": "A storm topples a section of the nearby forest. The felled trees are easy to collect.",
		"icon": "🌲",
		"effects": {"resources": {"wood": 120}},
		"choices": [{"label": "Gather the Wood (Wood +120)", "effects": null}]
	},
	{
		"id": "event_human_d2", "tier": "D",
		"title": "Passing Trader",
		"body": "A small caravan passes through and purchases surplus goods.",
		"icon": "🛒",
		"effects": {"resources": {"gold": 25, "food": -10}},
		"choices": [
			{"label": "Sell Surplus (Gold +25, Food -10)", "effects": null},
			{"label": "Decline", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_d3", "tier": "D",
		"title": "Cracked Cobblestones",
		"body": "The main road has cracked badly after recent rains.",
		"icon": "🪨",
		"effects": {"resources": {"gold": -15, "stone": -20}},
		"choices": [
			{"label": "Repair the Road (Gold -15, Stone -20)", "effects": null},
			{"label": "Leave It For Now", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_d4", "tier": "D",
		"title": "Bee Swarm in the Granary",
		"body": "A large swarm of bees has taken residence in the upper granary.",
		"icon": "🐝",
		"effects": {"resources": {"gold": 10, "food": -30}},
		"choices": [
			{"label": "Smoke Them Out (Gold +10, Food -30)", "effects": null},
			{"label": "Leave Them Be", "effects": {"resources": {"food": -5}}}
		]
	},

	# C TIER
	{
		"id": "event_human_c1", "tier": "C",
		"title": "Bumper Harvest",
		"body": "Favorable weather has blessed the fields. The harvest this season is plentiful.",
		"icon": "🌾",
		"effects": {"resources": {"food": 150}},
		"choices": [{"label": "Celebrate! (Food +150)", "effects": null}]
	},
	{
		"id": "event_human_c2", "tier": "C",
		"title": "Wandering Scholar",
		"body": "A learned scholar passes through, offering lectures to your townsfolk.",
		"icon": "📚",
		"effects": {"resources": {"gold": -20, "science": 60}},
		"choices": [
			{"label": "Invite Him In (Science +60, Gold -20)", "effects": null},
			{"label": "Let Him Pass", "effects": {"resources": {"science": 10}}}
		]
	},
	{
		"id": "event_human_c3", "tier": "C",
		"title": "Abandoned Mine",
		"body": "Scouts report an abandoned mine shaft on the edge of your territory.",
		"icon": "⛏",
		"effects": {"resources": {"stone": 100}},
		"choices": [
			{"label": "Send Workers (Stone +100)", "effects": null},
			{"label": "Too Dangerous", "effects": {"resources": {"science": 5}}}
		]
	},
	{
		"id": "event_human_c4", "tier": "C",
		"title": "Minor Fire at the Mill",
		"body": "A lantern was knocked over in the lumber mill, starting a small blaze.",
		"icon": "🔥",
		"effects": {"resources": {"wood": -80, "stone": -10}},
		"choices": [
			{"label": "Rebuild Quickly (Wood -80, Stone -10)", "effects": null},
			{"label": "Salvage What Remains", "effects": {"resources": {"wood": -40}}}
		]
	},
	{
		"id": "event_human_c5", "tier": "C",
		"title": "Travelling Minstrels",
		"body": "A troupe of colourful minstrels passes through, lifting spirits.",
		"icon": "🎵",
		"effects": {"resources": {"gold": -10, "food": 10, "science": 20}},
		"choices": [
			{"label": "Host Them (Science +20, Food +10, Gold -10)", "effects": null},
			{"label": "Send Them Onward", "effects": {"resources": {}}}
		]
	},

	# B TIER -- flat small pop changes (3-5 units max)
	{
		"id": "event_human_b1", "tier": "B",
		"title": "The Merchant Arrives",
		"body": "A traveling merchant sets up a stall near the town gate.",
		"icon": "💰",
		"effects": {"resources": {"gold": 80, "food": -20}},
		"choices": [
			{"label": "Trade (Gold +80, Food -20)", "effects": null},
			{"label": "Send Him Away", "effects": {"resources": {"food": 20}}}
		]
	},
	{
		"id": "event_human_b2", "tier": "B",
		"title": "Wandering Settlers",
		"body": "A group of wandering settlers asks to join your settlement. Extra hands mean extra mouths.",
		"icon": "🏘",
		"effects": {"resources": {"food": -40}, "pop_gain": 3},
		"choices": [
			{"label": "Welcome Them (+3 Villagers, Food -40)", "effects": null},
			{"label": "Turn Them Away", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_b3", "tier": "B",
		"title": "Plague Scare",
		"body": "A sickness spreads through the lower quarters. Several families flee before it can take hold.",
		"icon": "☠",
		"effects": {"resources": {"gold": -30}, "pop_kill": 2},
		"choices": [
			{"label": "Quarantine (-2 Villagers, Gold -30)", "effects": null},
			{"label": "Ignore It", "effects": {"resources": {}, "pop_kill": 4}}
		]
	},
	{
		"id": "event_human_b4", "tier": "B",
		"title": "Festival Season",
		"body": "The townsfolk propose a festival. It costs some food and gold but families grow.",
		"icon": "🎉",
		"effects": {"resources": {"gold": -50, "food": -60}, "pop_gain": 2},
		"choices": [
			{"label": "Hold the Festival (+2 Villagers, Gold -50, Food -60)", "effects": null},
			{"label": "Cancel", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_b5", "tier": "B",
		"title": "Flood Warning",
		"body": "Heavy rains upstream threaten to flood the lower farms.",
		"icon": "🌊",
		"effects": {"resources": {"food": -100, "wood": -40, "stone": -60}},
		"choices": [
			{"label": "Reinforce the Banks (Food -100, Wood -40, Stone -60)", "effects": null},
			{"label": "Risk It", "effects": {"resources": {"food": -200}}}
		]
	},

	# A TIER -- percentage-based pop swings (~8-15%)
	{
		"id": "event_human_a1", "tier": "A",
		"title": "Noble's Patronage",
		"body": "A wealthy noble wishes to invest in your settlement.",
		"icon": "👑",
		"effects": {"resources": {"gold": 200, "science": 80}},
		"choices": [
			{"label": "Accept Their Patronage (Gold +200, Science +80)", "effects": null},
			{"label": "Politely Decline", "effects": {"resources": {"gold": 20}}}
		]
	},
	{
		"id": "event_human_a2", "tier": "A",
		"title": "Crop Blight",
		"body": "A mysterious blight sweeps through the farmlands. Entire fields are ruined. Families begin to leave.",
		"icon": "🌿",
		"effects": {"resources": {"food": -300}, "pop_kill_pct": 15.0},
		"choices": [
			{"label": "Ration Stores (Food -300, ~15% Pop Loss)", "effects": null},
			{"label": "Buy Emergency Food (Gold -120, ~8% Pop Loss)", "effects": {"resources": {"gold": -120, "food": 150}, "pop_kill_pct": 8.0}}
		]
	},
	{
		"id": "event_human_a3", "tier": "A",
		"title": "Earthquake Tremors",
		"body": "The ground shook before dawn. Buildings cracked and the injured are many.",
		"icon": "🌋",
		"effects": {"resources": {"gold": -80, "wood": -100, "stone": -200}, "pop_kill_pct": 10.0},
		"choices": [
			{"label": "Begin Repairs (heavy resource cost, ~10% Pop Loss)", "effects": null},
			{"label": "Prioritise Survivors (Gold -40, ~8% Pop Loss)", "effects": {"resources": {"gold": -40}, "pop_kill_pct": 8.0}}
		]
	},
	{
		"id": "event_human_a4", "tier": "A",
		"title": "Foreign Dignitary",
		"body": "An ambassador from a distant realm seeks an alliance. The exchange of knowledge is unparalleled.",
		"icon": "🤝",
		"effects": {"resources": {"gold": -100, "food": -80, "science": 180}},
		"choices": [
			{"label": "Host the Delegation (Science +180, Gold -100, Food -80)", "effects": null},
			{"label": "Brief Meeting Only (Science +40, Gold -20)", "effects": {"resources": {"gold": -20, "science": 40}}}
		]
	},
	{
		"id": "event_human_a5", "tier": "A",
		"title": "Bandit Ambush",
		"body": "Bandits raided an outlying supply convoy. Resources were plundered and several settlers were lost.",
		"icon": "⚔",
		"effects": {"resources": {"gold": -120, "food": -80, "wood": -60}, "pop_kill_pct": 10.0},
		"choices": [
			{"label": "Accept the Losses (resource drain, ~10% Pop Loss)", "effects": null},
			{"label": "Send a Punitive Party (recover resources, ~5% Pop Loss)", "effects": {"resources": {"gold": 40, "food": 40, "wood": 30}, "pop_kill_pct": 5.0}}
		]
	},
	{
		"id": "event_human_a9", "tier": "A",
		"category": "military",
		"title": "Marauder Scouts Spotted",
		"body": "Riders report a large warband setting up camp on the outskirts. You may pay tribute to delay them.",
		"icon": "🏕",
		"effects": {"resources": {"gold": -150, "food": -100}},
		"choices": [
			{"label": "Pay Tribute (Gold -150, Food -100 -- they withdraw for now)", "effects": {"resources": {"gold": -150, "food": -100}}},
			{"label": "Let Them Camp (a marauder barracks spawns on the map)", "effects": {"resources": {}, "spawn_wave": true}}
		]
	},

	# S TIER -- percentage-based pop swings (~12-30%)
	{
		"id": "event_human_s1", "tier": "S",
		"title": "The Great Sickness",
		"body": "A virulent fever sweeps through the settlement. Despite healers' best efforts, many townsfolk succumb.",
		"icon": "💀",
		"effects": {"resources": {"gold": -60}, "pop_kill_pct": 20.0},
		"choices": [
			{"label": "Quarantine & Treat (Gold -60, ~20% Pop Loss)", "effects": null},
			{"label": "Flee the District (~30% Pop Loss, save gold)", "effects": {"resources": {}, "pop_kill_pct": 30.0}}
		]
	},
	{
		"id": "event_human_s2", "tier": "S",
		"title": "Mass Migration",
		"body": "Word of your thriving settlement has spread. A great wave of hopeful settlers arrives at the gates.",
		"icon": "🚶",
		"effects": {"resources": {"food": -150, "wood": -60}, "pop_gain_pct": 25.0},
		"choices": [
			{"label": "Open the Gates (~25% Pop Gain, Food -150, Wood -60)", "effects": null},
			{"label": "Accept Only Some (~12% Pop Gain, Food -80)", "effects": {"resources": {"food": -80}, "pop_gain_pct": 12.0}}
		]
	},
	{
		"id": "event_human_s3", "tier": "S",
		"title": "City of Refuge",
		"body": "A neighbouring settlement was destroyed. Its survivors came to you for shelter.",
		"icon": "🏚",
		"effects": {"resources": {"food": -200, "wood": -80, "stone": -40}, "pop_gain_pct": 20.0},
		"choices": [
			{"label": "Shelter Them All (~20% Pop Gain, heavy resources)", "effects": null},
			{"label": "Offer Limited Aid (~10% Pop Gain, modest resources)", "effects": {"resources": {"food": -80, "wood": -30}, "pop_gain_pct": 10.0}}
		]
	},
	{
		"id": "event_human_s4", "tier": "S",
		"title": "Siege Aftermath",
		"body": "A skirmish at the settlement's edge left buildings damaged and lives lost.",
		"icon": "🛡",
		"effects": {"resources": {"gold": -100, "food": -80, "wood": -100, "stone": -80}, "pop_kill_pct": 25.0},
		"choices": [
			{"label": "Rebuild (~25% Pop Loss, heavy resource cost)", "effects": null},
			{"label": "Abandon the Outer Walls (~15% Pop Loss, less resource loss)", "effects": {"resources": {"gold": -40, "food": -40, "wood": -40}, "pop_kill_pct": 15.0}}
		]
	},
	{
		"id": "event_human_s5", "tier": "S",
		"category": "military",
		"title": "The War Party Descends",
		"body": "A disciplined enemy war party has erected a fortified barracks on your doorstep. There is no sending them away.",
		"icon": "⚔",
		"effects": {"resources": {"gold": -80, "food": -60, "wood": -80, "stone": -60}, "spawn_wave": true},
		"choices": [
			{"label": "Fortify the Walls (resource cost, barracks spawns)", "effects": null},
			{"label": "Arm the People (Gold -120, barracks spawns)", "effects": {"resources": {"gold": -120}, "spawn_wave": true}}
		]
	},

	# S+ TIER -- percentage-based pop swings (~25-40%)
	{
		"id": "event_human_sp1", "tier": "S+",
		"title": "The Plague",
		"body": "A devastating plague tears through every quarter of the settlement. There is no stopping it -- only managing the losses.",
		"icon": "☣",
		"effects": {"resources": {"gold": -150, "food": -200}, "pop_kill_pct": 30.0},
		"choices": [
			{"label": "Fight It With Everything (Gold -150, Food -200, ~30% Pop Loss)", "effects": null},
			{"label": "Sacrifice the Outer Quarters (~40% Pop Loss, save resources)", "effects": {"resources": {}, "pop_kill_pct": 40.0}}
		]
	},
	{
		"id": "event_human_sp2", "tier": "S+",
		"title": "Golden Age",
		"body": "The stars align, the harvest is legendary, scholars flock to your halls, and a great lord pledges their fortune. A new era dawns.",
		"icon": "✨",
		"effects": {"resources": {"gold": 400, "food": 400, "wood": 200, "stone": 200, "science": 200}, "pop_gain_pct": 35.0},
		"choices": [
			{"label": "Embrace the Golden Age (~35% Pop Gain, all resources surge)", "effects": null}
		]
	},
	{
		"id": "event_human_sp3", "tier": "S+",
		"title": "Dragon Sighting",
		"body": "A young dragon circled the settlement for hours before landing outside the walls. Terror has gripped the town -- people are fleeing.",
		"icon": "🐉",
		"effects": {"resources": {"gold": -200, "food": -150, "wood": -150, "stone": -100}, "pop_kill_pct": 25.0},
		"choices": [
			{"label": "Offer Tribute (massive resource drain, ~25% Pop Loss)", "effects": null},
			{"label": "Drive It Away (minor resource loss, ~30% Pop Loss)", "effects": {"resources": {"gold": -60, "food": -60, "wood": -60}, "pop_kill_pct": 30.0}}
		]
	},
	{
		"id": "event_human_sp4", "tier": "S+",
		"title": "The Great Migration",
		"body": "An entire neighbouring nation is on the move -- heading here. Thousands arrive over a day, swelling your strength enormously.",
		"icon": "🌍",
		"effects": {"resources": {"food": -500, "wood": -200, "stone": -150, "science": 50}, "pop_gain_pct": 40.0},
		"choices": [
			{"label": "Accept All (~40% Pop Gain, enormous cost)", "effects": null},
			{"label": "Absorb Only the Skilled (~20% Pop Gain, half cost)", "effects": {"resources": {"food": -250, "wood": -100, "stone": -75, "science": 30}, "pop_gain_pct": 20.0}}
		]
	},
	{
		"id": "event_human_sp5", "tier": "S+",
		"category": "divine_light",
		"title": "Μονινγ τηρουγη τηε συν",
		"body": "Μονινγ τηρουγη τηε συν? Ωελλ δονε βυτ ψουρ ιουρνεψ ις νοτ ονερ ψετ.",
		"icon": "☉",
		"effects": {"resources": {"gold": 300, "food": 300, "wood": 300, "stone": 300, "science": 300}, "pop_gain_pct": 30.0},
		"choices": [
			{"label": "Ωελλ δονε. Τηε πατη γοες ον.", "effects": null}
		]
	},
]

# Helpers

static func get_random_event(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Uniform random pick (legacy / debug). Use get_random_event_weighted for gameplay."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)

static func get_random_event_weighted(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Weighted random pick -- rarer tiers appear far less often than common ones."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
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
	"""Human-readable tier label."""
	match tier:
		"S+": return "[S+] LEGENDARY"
		"S":  return "[S] EPIC"
		"A":  return "[A] MAJOR"
		"B":  return "[B] NOTABLE"
		"C":  return "[C] MODERATE"
		"D":  return "[D] MINOR"
		"F":  return "[F] TRIVIAL"
		_:    return tier

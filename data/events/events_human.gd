# data/events/events_human.gd
# Random world events for the Human faction.
# Curated to 14 events (2 per tier) -- each hand-picked to be distinct and to matter.
# Actual deaths (pop_kill/pop_kill_pct) are reserved for the catastrophic F tier only;
# lesser bad/unlucky tiers instead nudge the player's ongoing birth_rate_delta down,
# and several good-tier events raise it instead of granting instant villagers.
# NOTHING happens until the player picks a choice -- there is no shared "base" effect,
# so every choice below is fully self-contained with its own "effects" dict.
# Each entry is a Dictionary with keys:
#   id        - unique string identifier
#   tier      - "S+", "S", "A", "B", "C", "D", or "F" -- a SENTIMENT scale, not rarity:
#               F = worst/most harmful ... S+ = best/most beneficial. Maps directly onto
#               the 1-20 End Day dice roll (see get_tier_for_roll): low rolls are bad
#               (red), the middle is neutral (grey), high rolls are good (gold).
#   title     - short event name (shown in card + modal header)
#   body      - flavour paragraph shown in the modal
#   icon      - emoji / symbol for the notification card
#   choices   - Array of {label, effects} -- at least one choice, each with its own
#               "effects" Dictionary (never null/shared) describing what it does:
#       resources       - {gold, food, wood, stone, science}  (can be negative)
#       pop_kill        - int, remove this many living units immediately (F tier only)
#       pop_gain        - int, add this many new units immediately
#       pop_kill_pct    - float %, remove ceil(pop * pct/100) units (min 1) (F tier only)
#       pop_gain_pct    - float %, add   ceil(pop * pct/100) units (min 1)
#       birth_rate_delta - float, permanently adds/subtracts from the player's ongoing
#                          daily population growth rate (e.g. -0.01 = -1.0 percentage points)
#
# Tier selection weights (approximate %):
#   F: 15   D: 15   C: 15   B: 10   A: 20   S: 15   S+: 10

extends RefCounted

const TIER_WEIGHTS: Dictionary = {
	"S+": 10,
	"S":  15,
	"A":  20,
	"B":  10,
	"C":  15,
	"D":  15,
	"F":  15,
}

const EVENTS: Array = [

	# F TIER -- catastrophic (roll 1-3, red). Actual deaths only ever happen here.
	{
		"id": "event_human_sp1", "tier": "F",
		"title": "The Plague",
		"body": "A devastating plague tears through every quarter of the settlement. There is no stopping it -- only managing the losses.",
		"icon": "☣",
		"choices": [
			{"label": "Fight It With Everything (Gold -150, Food -200, ~30% Pop Loss)", "effects": {"resources": {"gold": -150, "food": -200}, "pop_kill_pct": 30.0}},
			{"label": "Sacrifice the Outer Quarters (~40% Pop Loss, save resources)", "effects": {"resources": {}, "pop_kill_pct": 40.0}}
		]
	},
	{
		"id": "event_human_sp3", "tier": "F",
		"title": "Dragon Sighting",
		"body": "A young dragon circled the settlement for hours before landing outside the walls. Terror has gripped the town -- people are fleeing.",
		"icon": "🐉",
		"choices": [
			{"label": "Offer Tribute (massive resource drain, ~25% Pop Loss)", "effects": {"resources": {"gold": -200, "food": -150, "wood": -150, "stone": -100}, "pop_kill_pct": 25.0}},
			{"label": "Drive It Away (minor resource loss, ~30% Pop Loss)", "effects": {"resources": {"gold": -60, "food": -60, "wood": -60}, "pop_kill_pct": 30.0}}
		]
	},

	# D TIER -- bad (roll 4-6, orange). Setbacks dampen the birth rate rather than killing anyone.
	{
		"id": "event_human_a2", "tier": "D",
		"title": "Crop Blight",
		"body": "A mysterious blight sweeps through the farmlands. Entire fields are ruined. Families delay having children until the harvest recovers.",
		"icon": "🌿",
		"choices": [
			{"label": "Ration Stores (Food -300, Birth Rate -1.0%)", "effects": {"resources": {"food": -300}, "birth_rate_delta": -0.010}},
			{"label": "Buy Emergency Food (Gold -150, Food +100, Birth Rate -0.5%)", "effects": {"resources": {"gold": -150, "food": 100}, "birth_rate_delta": -0.005}}
		]
	},
	{
		"id": "event_human_a9", "tier": "D",
		"category": "military",
		"title": "Marauder Scouts Spotted",
		"body": "Riders report a large warband setting up camp on the outskirts. You may pay tribute to delay them.",
		"icon": "🏕",
		"choices": [
			{"label": "Pay Tribute (Gold -150, Food -100 -- they withdraw for now)", "effects": {"resources": {"gold": -150, "food": -100}}},
			{"label": "Let Them Camp (a marauder barracks spawns on the map)", "effects": {"resources": {}, "spawn_wave": true}}
		]
	},

	# C TIER -- unlucky (roll 7-9, yellow)
	{
		"id": "event_human_d3", "tier": "C",
		"title": "Cracked Cobblestones",
		"body": "The main road has cracked badly after recent rains.",
		"icon": "🪨",
		"choices": [
			{"label": "Repair the Road (Gold -15, Stone -20)", "effects": {"resources": {"gold": -15, "stone": -20}}},
			{"label": "Leave It For Now", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_c4", "tier": "C",
		"title": "Minor Fire at the Mill",
		"body": "A lantern was knocked over in the lumber mill, starting a small blaze.",
		"icon": "🔥",
		"choices": [
			{"label": "Rebuild Quickly (Wood -80, Stone -10)", "effects": {"resources": {"wood": -80, "stone": -10}}},
			{"label": "Salvage What Remains (Wood -40)", "effects": {"resources": {"wood": -40}}}
		]
	},

	# B TIER -- neutral (roll 10-11, grey)
	{
		"id": "event_human_f1", "tier": "B",
		"title": "A Quiet Day",
		"body": "The sun rose, the sun set. Nothing of note disturbed the settlement.",
		"icon": "☁",
		"choices": [
			{"label": "Noted.", "effects": {"resources": {}}}
		]
	},
	{
		"id": "event_human_pet1", "tier": "B",
		"title": "A Stray Companion",
		"body": "A friendly animal has taken a liking to your settlement and won't leave. Will you take it in?",
		"icon": "🐾",
		"choices": [
			{"label": "Adopt the Dog (Food -2)", "effects": {"resources": {"food": -2}, "add_pet": "dog"}},
			{"label": "Adopt the Cat (Food -2)", "effects": {"resources": {"food": -2}, "add_pet": "cat"}},
			{"label": "Turn It Away", "effects": {"resources": {}}}
		]
	},

	# A TIER -- favourable (roll 12-15, light green)
	{
		"id": "event_human_windfall1", "tier": "A",
		"title": "Natural Windfall",
		"body": "Scouts report a stroke of luck nearby -- the land is offering something useful for the taking.",
		"icon": "🎁",
		"choices": [
			{"label": "Gather Timber (Wood +120)", "effects": {"resources": {"wood": 120}}},
			{"label": "Harvest the Fields (Food +150)", "effects": {"resources": {"food": 150}}},
			{"label": "Mine the Deposit (Stone +100)", "effects": {"resources": {"stone": 100}}}
		]
	},
	{
		"id": "event_human_b1", "tier": "A",
		"title": "The Merchant Arrives",
		"body": "A traveling merchant sets up a stall near the town gate.",
		"icon": "💰",
		"choices": [
			{"label": "Trade Freely (Gold +80, Food -20)", "effects": {"resources": {"gold": 80, "food": -20}}},
			{"label": "Negotiate a Smaller Deal (Gold +35, Food -5)", "effects": {"resources": {"gold": 35, "food": -5}}},
			{"label": "Send Him Away (Food +20)", "effects": {"resources": {"food": 20}}}
		]
	},

	# S TIER -- fortunate (roll 16-18, green)
	{
		"id": "event_human_a1", "tier": "S",
		"title": "Noble's Patronage",
		"body": "A wealthy noble wishes to invest in your settlement.",
		"icon": "👑",
		"choices": [
			{"label": "Accept Their Patronage (Gold +200, Science +80)", "effects": {"resources": {"gold": 200, "science": 80}}},
			{"label": "Politely Decline (Gold +20)", "effects": {"resources": {"gold": 20}}}
		]
	},
	{
		"id": "event_human_b4", "tier": "S",
		"title": "Festival Season",
		"body": "The townsfolk propose a festival. It costs some food and gold, but couples are inspired to start families, raising the birth rate for a while.",
		"icon": "🎉",
		"choices": [
			{"label": "Hold the Festival (Gold -50, Food -60, Birth Rate +1.0%)", "effects": {"resources": {"gold": -50, "food": -60}, "birth_rate_delta": 0.010}},
			{"label": "Cancel", "effects": {"resources": {}}}
		]
	},

	# S+ TIER -- blessed / best (roll 19-20, gold)
	{
		"id": "event_human_sp2", "tier": "S+",
		"title": "Golden Age",
		"body": "The stars align, the harvest is legendary, scholars flock to your halls, and a great lord pledges their fortune. A new era dawns.",
		"icon": "✨",
		"choices": [
			{"label": "Embrace the Golden Age (~35% Pop Gain, all resources surge)", "effects": {"resources": {"gold": 400, "food": 400, "wood": 200, "stone": 200, "science": 200}, "pop_gain_pct": 35.0}},
			{"label": "Invest in the Future (Birth Rate +1.5%, smaller resource surge)", "effects": {"resources": {"gold": 150, "food": 150, "wood": 150, "stone": 150, "science": 150}, "birth_rate_delta": 0.015}}
		]
	},
	{
		"id": "event_human_sp4", "tier": "S+",
		"title": "The Great Migration",
		"body": "An entire neighbouring nation is on the move -- heading here. Thousands arrive over a day, swelling your strength enormously.",
		"icon": "🌍",
		"choices": [
			{"label": "Accept All (~40% Pop Gain, enormous cost)", "effects": {"resources": {"food": -500, "wood": -200, "stone": -150, "science": 50}, "pop_gain_pct": 40.0}},
			{"label": "Absorb Only the Skilled (~20% Pop Gain, half cost)", "effects": {"resources": {"food": -250, "wood": -100, "stone": -75, "science": 30}, "pop_gain_pct": 20.0}}
		]
	},
]

# Helpers

static func get_random_event(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Uniform random pick (legacy / debug). Use get_event_for_roll for gameplay."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)

static func get_random_event_weighted(rng: RandomNumberGenerator = null) -> Dictionary:
	"""Weighted random pick, ignoring the dice roll (legacy / debug only).
	Rarer tiers appear far less often than common ones. Use get_event_for_roll for gameplay."""
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

static func get_events_by_tier(tier: String) -> Array:
	"""All events tagged with a given sentiment tier."""
	var result: Array = []
	for ev in EVENTS:
		if ev.get("tier", "C") == tier:
			result.append(ev)
	return result

static func get_event_for_roll(roll: int, rng: RandomNumberGenerator = null) -> Dictionary:
	"""The End Day dice roll drives which tier fires — pick a random event from that tier
	(see get_tier_for_roll for the roll-to-tier mapping)."""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var tier: String = get_tier_for_roll(roll)
	var pool: Array = get_events_by_tier(tier)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)

static func get_event_by_id(id: String) -> Dictionary:
	for ev in EVENTS:
		if ev["id"] == id:
			return ev.duplicate(true)
	return {}

static func get_tier_label(tier: String) -> String:
	"""Human-readable tier label."""
	match tier:
		"S+": return "[S+] BLESSED"
		"S":  return "[S] FORTUNATE"
		"A":  return "[A] FAVOURABLE"
		"B":  return "[B] NEUTRAL"
		"C":  return "[C] UNLUCKY"
		"D":  return "[D] BAD"
		"F":  return "[F] CATASTROPHIC"
		_:    return tier

static func get_tier_color(tier: String) -> Color:
	"""Shared tier color palette — used by the encyclopedia and the End Day dice roll.
	Runs red (worst) -> orange -> yellow -> grey (neutral) -> green -> gold (best)."""
	match tier:
		"F":  return Color(0.90, 0.15, 0.15)   # red — catastrophic
		"D":  return Color(0.90, 0.50, 0.10)   # orange — bad
		"C":  return Color(0.90, 0.80, 0.15)   # yellow — unlucky
		"B":  return Color(0.60, 0.60, 0.60)   # grey — neutral
		"A":  return Color(0.55, 0.85, 0.45)   # light green — favourable
		"S":  return Color(0.20, 0.75, 0.35)   # green — fortunate
		"S+": return Color(1.00, 0.85, 0.20)   # gold — blessed / best
		_:    return Color(0.60, 0.60, 0.60)

# d20 ranges: F1-3 (red) D4-6 (orange) C7-9 (yellow) B10-11 (grey, neutral middle)
# A12-15 (light green) S16-18 (green) S+19-20 (gold, best). Placeholder mapping —
# the actual day's event will drive this roll directly later.
static func get_tier_for_roll(roll: int) -> String:
	if roll >= 19: return "S+"
	if roll >= 16: return "S"
	if roll >= 12: return "A"
	if roll >= 10: return "B"
	if roll >= 7:  return "C"
	if roll >= 4:  return "D"
	return "F"

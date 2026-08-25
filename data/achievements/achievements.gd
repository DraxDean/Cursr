# data/achievements/achievements.gd
# Static achievement definitions. Each entry has:
#   id       - unique string key (used in save file)
#   icon     - emoji / symbol displayed in UI
#   title    - short display name
#   desc     - flavour description of the requirement
#   category - grouping label
extends Object

const ACHIEVEMENTS: Array = [
	# ── Demo (console testable) ───────────────────────────────────────────────
	{
		"id":       "demo_achievement",
		"icon":     "🧪",
		"title":    "Lab Rat",
		"desc":     "Triggered via the debug console with 'demo achievement'.",
		"category": "Debug",
	},

	# ── Survival ─────────────────────────────────────────────────────────────
	{
		"id":       "survive_50_days",
		"icon":     "🌅",
		"title":    "First Season",
		"desc":     "Survive for 50 days.",
		"category": "Survival",
	},
	{
		"id":       "survive_100_days",
		"icon":     "📅",
		"title":    "A Century of Days",
		"desc":     "Survive for 100 days without your Town Centre being destroyed.",
		"category": "Survival",
	},

	# ── Military ─────────────────────────────────────────────────────────────
	{
		"id":       "destroy_camp",
		"icon":     "⚔",
		"title":    "Camp Clearer",
		"desc":     "Destroy an enemy marauder barracks.",
		"category": "Military",
	},
	{
		"id":       "destroy_3_camps",
		"icon":     "🏹",
		"title":    "Warlord",
		"desc":     "Destroy 3 enemy marauder barracks.",
		"category": "Military",
	},

	# ── Research ─────────────────────────────────────────────────────────────
	{
		"id":       "research_any",
		"icon":     "🔬",
		"title":    "Enlightened",
		"desc":     "Unlock any technology for the first time.",
		"category": "Research",
	},
	{
		"id":       "research_all",
		"icon":     "🧠",
		"title":    "Master of Knowledge",
		"desc":     "Unlock all available technologies at least once.",
		"category": "Research",
	},

	# ── Construction ─────────────────────────────────────────────────────────
	{
		"id":       "build_wonder",
		"icon":     "🏛",
		"title":    "Wonder of the World",
		"desc":     "Construct a Wonder building.",
		"category": "Construction",
	},
	{
		"id":       "build_5_houses",
		"icon":     "🏠",
		"title":    "Housing Boom",
		"desc":     "Build 5 Houses.",
		"category": "Construction",
	},

	# ── Workforce: Lumber ─────────────────────────────────────────────────────
	{
		"id":       "lumber_workforce",
		"icon":     "🌲",
		"title":    "Timber Baron",
		"desc":     "Assign 25 lumberjack workers across 5 or more Lumberjack buildings.",
		"category": "Workforce",
	},

	# ── Workforce: Stone ─────────────────────────────────────────────────────
	{
		"id":       "stone_workforce",
		"icon":     "⛏",
		"title":    "Master Quarrier",
		"desc":     "Assign 25 stoneworkers across 5 or more Stoneworker buildings.",
		"category": "Workforce",
	},

	# ── Workforce: Fish ───────────────────────────────────────────────────────
	{
		"id":       "fish_workforce",
		"icon":     "🐟",
		"title":    "Fleet Admiral",
		"desc":     "Assign 25 fishers across 5 or more Fishing Huts.",
		"category": "Workforce",
	},

	# ── Workforce: Farm ───────────────────────────────────────────────────────
	{
		"id":       "farm_workforce",
		"icon":     "🌾",
		"title":    "Agricultural Empire",
		"desc":     "Assign 25 farmers across 5 or more Farmhouses.",
		"category": "Workforce",
	},

	# ── Population ────────────────────────────────────────────────────────────
	{
		"id":       "pop_25",
		"icon":     "👥",
		"title":    "Growing Town",
		"desc":     "Reach a population of 25 citizens.",
		"category": "Population",
	},
	{
		"id":       "pop_50",
		"icon":     "🏙",
		"title":    "Bustling City",
		"desc":     "Reach a population of 50 citizens.",
		"category": "Population",
	},
]

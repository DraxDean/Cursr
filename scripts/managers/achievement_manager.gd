# scripts/managers/achievement_manager.gd
# Global autoload — persists achievement unlocks across all save files.
# Save location: user://achievements.json (separate from game saves)
extends Node

const SAVE_PATH := "user://achievements.json"

signal achievement_unlocked(id: String, title: String, icon: String)

# All achievement definitions live here — no external script dependencies
const ACHIEVEMENTS: Array = [
	{"id": "demo_achievement",  "icon": "🧪", "title": "Lab Rat",             "desc": "Triggered via the debug console with ''demo achievement''.",                         "category": "Debug"},
	{"id": "survive_50_days",   "icon": "🌅", "title": "First Season",        "desc": "Survive for 50 days.",                                                              "category": "Survival"},
	{"id": "survive_100_days",  "icon": "📅", "title": "A Century of Days",   "desc": "Survive for 100 days without your Town Centre being destroyed.",                    "category": "Survival"},
	{"id": "destroy_camp",      "icon": "⚔",  "title": "Camp Clearer",        "desc": "Destroy an enemy marauder barracks.",                                               "category": "Military"},
	{"id": "destroy_3_camps",   "icon": "🏹", "title": "Warlord",             "desc": "Destroy 3 enemy marauder barracks.",                                                "category": "Military"},
	{"id": "research_any",      "icon": "🔬", "title": "Enlightened",         "desc": "Unlock any technology for the first time.",                                         "category": "Research"},
	{"id": "research_all",      "icon": "🧠", "title": "Master of Knowledge", "desc": "Unlock all available technologies at least once.",                                  "category": "Research"},
	{"id": "build_wonder",      "icon": "🏛",  "title": "Wonder of the World", "desc": "Construct a Wonder building.",                                                     "category": "Construction"},
	{"id": "build_5_houses",    "icon": "🏠", "title": "Housing Boom",        "desc": "Build 5 Houses.",                                                                   "category": "Construction"},
	{"id": "lumber_workforce",  "icon": "🌲", "title": "Timber Baron",        "desc": "Assign 25 lumberjack workers across 5 or more Lumberjack buildings.",              "category": "Workforce"},
	{"id": "stone_workforce",   "icon": "⛏",  "title": "Master Quarrier",     "desc": "Assign 25 stoneworkers across 5 or more Stoneworker buildings.",                  "category": "Workforce"},
	{"id": "fish_workforce",    "icon": "🐟", "title": "Fleet Admiral",       "desc": "Assign 25 fishers across 5 or more Fishing Huts.",                                 "category": "Workforce"},
	{"id": "farm_workforce",    "icon": "🌾", "title": "Agricultural Empire", "desc": "Assign 25 farmers across 5 or more Farmhouses.",                                   "category": "Workforce"},
	{"id": "pop_25",            "icon": "👥", "title": "Growing Town",        "desc": "Reach a population of 25 citizens.",                                                "category": "Population"},
	{"id": "pop_50",            "icon": "🏙",  "title": "Bustling City",       "desc": "Reach a population of 50 citizens.",                                               "category": "Population"},
]

# id -> { "unlocked_at": "YYYY-MM-DD HH:MM:SS" }
var _unlocked: Dictionary = {}

func _ready() -> void:
	_load_achievements()

# -- Public API ----------------------------------------------------------------

func unlock(id: String) -> bool:
	if _unlocked.has(id):
		return false
	var now := Time.get_datetime_string_from_system(false, true)
	_unlocked[id] = {"unlocked_at": now}
	_save_achievements()
	for ach in ACHIEVEMENTS:
		if ach["id"] == id:
			achievement_unlocked.emit(id, ach["title"], ach["icon"])
			DebugConfig.dprint("achievements", ["Achievement unlocked: [%s] %s" % [id, ach["title"]]])
			return true
	achievement_unlocked.emit(id, id, "🏆")
	return true

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)

func get_unlock_time(id: String) -> String:
	return _unlocked.get(id, {}).get("unlocked_at", "")

func get_all_unlocked() -> Dictionary:
	return _unlocked.duplicate()

# -- Persistence ---------------------------------------------------------------

func _save_achievements() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AchievementManager: Could not open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_unlocked))
	file.close()

func _load_achievements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_unlocked = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("AchievementManager: Could not open %s for reading." % SAVE_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_unlocked = parsed
	else:
		push_warning("AchievementManager: Could not parse achievements file -- resetting.")
		_unlocked = {}

# scripts/managers/tutorial_manager.gd
# Global autoload — placeholder tutorial content + persisted "seen" tracking,
# so each tutorial only ever fires its notification card once.
# Save location: user://tutorials.json (separate from game saves)
extends Node

const SAVE_PATH := "user://tutorials.json"

# Mock data — content will be filled in later with real steps/screenshots.
# Order here is the order shown in the Encyclopedia's Tutorials tab.
const TUTORIALS: Array = [
	{"id": "welcome", "icon": "👋", "title": "Welcome", "summary": "Start here — your goals and how to win.",
		"pages": [
			{"heading": "Welcome to Cursr", "body": "Placeholder: a quick tour of the game and what you're building toward."},
			{"heading": "Victory Conditions", "body": "Placeholder: how a game is won or lost."},
		]},
	{"id": "first_building", "icon": "🏗", "title": "Building Your First Building", "summary": "Placing your first structure.",
		"pages": [
			{"heading": "Placing a Building", "body": "Placeholder: opening the build menu and placing a building on the map."},
		]},
	{"id": "employment", "icon": "💼", "title": "Employment", "summary": "Getting villagers into jobs.",
		"pages": [
			{"heading": "Assigning Jobs", "body": "Placeholder: how villagers get assigned to open jobs."},
		]},
	{"id": "daily_events", "icon": "📜", "title": "Daily Events", "summary": "Random events that occur each day.",
		"pages": [
			{"heading": "Daily Events", "body": "Placeholder: how world events fire and how to resolve them."},
		]},
	{"id": "resource_overview", "icon": "📦", "title": "Resource Overview", "summary": "Understanding your resources.",
		"pages": [
			{"heading": "Resources", "body": "Placeholder: gold, food, wood, stone, and science explained."},
			{"heading": "Resource Rates", "body": "Placeholder: reading the per-day production rates in the resource bar."},
		]},
	{"id": "wood", "icon": "🪵", "title": "Wood", "summary": "Harvesting and using wood.",
		"pages": [
			{"heading": "Wood", "body": "Placeholder: lumberjacks and the wood supply chain."},
		]},
	{"id": "stone", "icon": "🪨", "title": "Stone", "summary": "Mining and using stone.",
		"pages": [
			{"heading": "Stone", "body": "Placeholder: stoneworkers and the stone supply chain."},
		]},
	{"id": "fish", "icon": "🐟", "title": "Fish", "summary": "Fishing for food.",
		"pages": [
			{"heading": "Fish", "body": "Placeholder: fishing huts and fish tiles."},
		]},
	{"id": "farms", "icon": "🌾", "title": "Farms and Farmhouses", "summary": "Growing food over the seasons.",
		"pages": [
			{"heading": "Farms", "body": "Placeholder: sowing, growing, and harvesting a farm plot."},
			{"heading": "Farmhouses", "body": "Placeholder: farmhouses and upgrading farm output."},
		]},
	{"id": "barracks", "icon": "🏹", "title": "Barracks", "summary": "Training soldiers.",
		"pages": [
			{"heading": "Barracks", "body": "Placeholder: training villagers into soldiers."},
		]},
	{"id": "army", "icon": "⚔", "title": "Army", "summary": "Managing your army roster.",
		"pages": [
			{"heading": "Army", "body": "Placeholder: the Army modal, roster, and totals."},
		]},
	{"id": "merchant", "icon": "💰", "title": "Merchant", "summary": "Trading resources for gold.",
		"pages": [
			{"heading": "Merchant", "body": "Placeholder: trading surplus resources for gold."},
		]},
	{"id": "science", "icon": "🔬", "title": "Science", "summary": "Researching technologies.",
		"pages": [
			{"heading": "Science", "body": "Placeholder: earning science points."},
			{"heading": "Technologies", "body": "Placeholder: the technology tree and unlocks."},
		]},
	{"id": "marauders", "icon": "🏴", "title": "Marauders", "summary": "Enemy camps and waves.",
		"pages": [
			{"heading": "Marauders", "body": "Placeholder: how waves spawn and camps raid your buildings."},
		]},
	{"id": "combat", "icon": "💥", "title": "Combat", "summary": "Fighting marauder camps.",
		"pages": [
			{"heading": "Combat Basics", "body": "Placeholder: attacking a marauder camp."},
			{"heading": "Combat Rolls", "body": "Placeholder: what the d20 roll outcomes mean."},
			{"heading": "Rewards", "body": "Placeholder: spoils of war after a victory."},
		]},
]

var _triggered: Dictionary = {}  # id -> true

func _ready() -> void:
	_load_triggered()

func get_tutorial(id: String) -> Dictionary:
	for t in TUTORIALS:
		if t["id"] == id:
			return t
	return {}

func has_been_triggered(id: String) -> bool:
	return _triggered.get(id, false)

func mark_triggered(id: String) -> void:
	if _triggered.get(id, false):
		return
	_triggered[id] = true
	_save_triggered()

func _save_triggered() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TutorialManager: Could not open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_triggered))
	file.close()

func _load_triggered() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_triggered = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("TutorialManager: Could not open %s for reading." % SAVE_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_triggered = parsed
	else:
		push_warning("TutorialManager: Could not parse tutorials file -- resetting.")
		_triggered = {}

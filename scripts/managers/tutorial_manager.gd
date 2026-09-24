# scripts/managers/tutorial_manager.gd
# Global autoload — tutorial CONTENT only (mock data, filled in later with real steps/screenshots).
# "Has this tutorial been seen" is tracked per-save-game on game.gd (triggered_tutorials),
# NOT here — unlike achievements, tutorials reset for every new playthrough, so this manager
# holds no persisted state of its own.
extends Node

# Order here is the order shown in the Encyclopedia's Tutorials tab.
const TUTORIALS: Array = [
	{"id": "welcome", "icon": "👋", "title": "Welcome", "summary": "Start here — your goals and how to win.",
		"next_tutorial": "first_building",
		"pages": [
			{"heading": "Welcome to Cursr!", "body": "This is a solo dev fantasy city builder, with the main purpose to have interesting and fun cities. There is no 'right' way to play, although there are victory and loss conditions.", "image": "res://assets/tutorials/Welcome.JPG"},
			{"heading": "How to Play", "body": "Grow your population and create a thriving city to fight off enemies! Click the End Day button to cycle a day.", "image": "res://assets/tutorials/day 100.JPG"},
			{"heading": "Win Condition: Day 100", "body": "Survive until day 100 to outlast the competition and settle permanently.", "image": "res://assets/tutorials/victory_100.JPG"},
			{"heading": "Win Condition: Wonder", "body": "Research all tech to unlock the Wonder and stockpile resources to build this unique building, triggering a Wonder victory.", "images": ["res://assets/tutorials/wonder_research.JPG", "res://assets/tutorials/wonder built.JPG"]},
			{"heading": "Need Help?", "body": "If you ever get stuck, you can see all tutorials and information in the Encyclopedia. Good luck!", "image": "res://assets/tutorials/encyclopedia.JPG"},
		]},
	{"id": "first_building", "icon": "🏗", "title": "Building Your First Building", "summary": "Placing your first structure.",
		"pages": [
			{"heading": "Open the Build Menu", "body": "Click the Build button to bring up the construction list.", "image": "res://assets/tutorials/BuildButton.JPG"},
			{"heading": "Choose a Building", "body": "Select the building you want to construct.", "image": "res://assets/tutorials/buildingmenu.JPG"},
			{"heading": "Place It", "body": "Click to place and build your building.", "image": "res://assets/tutorials/placebuilding.JPG"},
			{"heading": "View the Details", "body": "Click on your placed building to get the details!", "image": "res://assets/tutorials/buildingdetails.JPG"},
		]},
	{"id": "employment", "icon": "💼", "title": "Employment", "summary": "Getting villagers into jobs.",
		"pages": [
			{"heading": "Assigning Jobs", "body": "Placeholder: how villagers get assigned to open jobs."},
		]},
	{"id": "ending_day", "icon": "📜", "title": "Ending Day", "summary": "Rolling the dice and resolving what the day brings.",
		"pages": [
			{"heading": "Ending Day", "body": "Press the End Day button if enabled to end the day and start the Random Daily Event roll. You cannot end the Day until a decision has been made for all pending actions. The D20 is associated with events in a range of good and bad based on your roll. There are also other events besides the dailies that trigger on conditions like population increase, camp spawn, or camp raid. Feel free to click the notifications for more event details if available, and right click to dismiss them.", "image": "res://assets/tutorials/Daily event.JPG"},
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

func get_tutorial(id: String) -> Dictionary:
	for t in TUTORIALS:
		if t["id"] == id:
			return t
	return {}

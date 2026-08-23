# scripts/managers/game_log.gd
# Central log for in-game events. Stores timestamped entries across categories.
# Call GameLog.add(day, category, message) from anywhere in the game.
extends Node

enum Category { EVENT, BUILDING, TRAINING, RESEARCH, COMBAT, SYSTEM, INCOME }

const CATEGORY_ICONS: Dictionary = {
	Category.EVENT:    "📜",
	Category.BUILDING: "🏗",
	Category.TRAINING: "⚔",
	Category.RESEARCH: "🔬",
	Category.COMBAT:   "💥",
	Category.SYSTEM:   "ℹ",
	Category.INCOME:   "📈",
}

const CATEGORY_NAMES: Dictionary = {
	Category.EVENT:    "Event",
	Category.BUILDING: "Building",
	Category.TRAINING: "Training",
	Category.RESEARCH: "Research",
	Category.COMBAT:   "Combat",
	Category.SYSTEM:   "System",
	Category.INCOME:   "Income",
}

const CATEGORY_COLORS: Dictionary = {
	Category.EVENT:    Color(0.55, 0.75, 1.00),
	Category.BUILDING: Color(0.85, 0.75, 0.30),
	Category.TRAINING: Color(0.95, 0.45, 0.35),
	Category.RESEARCH: Color(0.50, 0.90, 0.80),
	Category.COMBAT:   Color(1.00, 0.30, 0.30),
	Category.SYSTEM:   Color(0.65, 0.65, 0.65),
	Category.INCOME:   Color(0.45, 0.90, 0.55),
}

# Each entry: {day, category (int), message, timestamp (real time)}
var entries: Array = []

signal entry_added(entry: Dictionary)

func add(day: int, category: int, message: String, extra: Dictionary = {}) -> void:
	var entry := {
		"day": day,
		"category": category,
		"message": message,
	}
	entry.merge(extra)
	entries.append(entry)
	entry_added.emit(entry)

func get_all() -> Array:
	return entries.duplicate()

func get_by_category(category: int) -> Array:
	return entries.filter(func(e): return e["category"] == category)

func clear() -> void:
	entries.clear()

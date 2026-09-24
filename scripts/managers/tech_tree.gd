# scripts/managers/tech_tree.gd
# Single source of truth for the research tree — shared by game.gd (prereq validation +
# bonus application) and science_modal.gd (tree UI) so new techs are only added here.
extends RefCounted

const ALL_PREREQ := "__ALL__"  # sentinel: unlocked only once every other tech is at level 1+

const CATEGORIES := [
	{"id": "labour", "name": "Labour"},
	{"id": "crafts", "name": "Crafts"},
	{"id": "military_hp", "name": "HP Pool"},
	{"id": "military_power", "name": "Battle Power"},
]

# bonus_target: "all" | "food" | "wood" | "stone" | "gold" | "science" | "hp" | "atk" | "none"
const TECHS := [
	# ── Labour ──────────────────────────────────────────────────────────────
	{"id": "work_ethic", "name": "Work Ethic", "icon": "🛠️", "category": "labour",
		"desc": "+5% to ALL resource production per level", "prereq": "",
		"max_level": 10, "bonus_target": "all", "bonus_percent": 0.05},
	{"id": "fishing_bonus", "name": "Fishing Mastery", "icon": "🐟", "category": "labour",
		"desc": "+5% food from fishing per level", "prereq": "work_ethic",
		"max_level": 10, "bonus_target": "food", "bonus_percent": 0.05},
	{"id": "woodcutting_bonus", "name": "Woodcutting Mastery", "icon": "🌲", "category": "labour",
		"desc": "+5% wood production per level", "prereq": "work_ethic",
		"max_level": 10, "bonus_target": "wood", "bonus_percent": 0.05},
	{"id": "stoneworking_bonus", "name": "Stoneworking Mastery", "icon": "⛏️", "category": "labour",
		"desc": "+5% stone production per level", "prereq": "work_ethic",
		"max_level": 10, "bonus_target": "stone", "bonus_percent": 0.05},
	{"id": "wonder_unlock", "name": "Wonder Construction", "icon": "🏛️", "category": "labour",
		"desc": "Unlocks construction of the Wonder. Requires every other technology researched.",
		"prereq": ALL_PREREQ, "max_level": 1, "bonus_target": "none", "bonus_percent": 0.0},

	# ── Crafts ──────────────────────────────────────────────────────────────
	{"id": "craftsmanship", "name": "Craftsmanship", "icon": "🔨", "category": "crafts",
		"desc": "Unlocks advanced trade & artisan technologies.", "prereq": "",
		"max_level": 1, "bonus_target": "none", "bonus_percent": 0.0},
	{"id": "mercantile_expertise", "name": "Mercantile Expertise", "icon": "💰", "category": "crafts",
		"desc": "+5% Gold income per level", "prereq": "craftsmanship",
		"max_level": 10, "bonus_target": "gold", "bonus_percent": 0.05},
	{"id": "scholarly_grants", "name": "Scholarly Grants", "icon": "📚", "category": "crafts",
		"desc": "+5% Science income per level", "prereq": "craftsmanship",
		"max_level": 10, "bonus_target": "science", "bonus_percent": 0.05},

	# ── Military: HP Pool (linear) ───────────────────────────────────────────
	{"id": "combat_conditioning", "name": "Combat Conditioning", "icon": "💪", "category": "military_hp",
		"desc": "+5% max HP per level", "prereq": "",
		"max_level": 10, "bonus_target": "hp", "bonus_percent": 0.05},
	{"id": "fortified_training", "name": "Fortified Training", "icon": "🛡️", "category": "military_hp",
		"desc": "+5% max HP per level", "prereq": "combat_conditioning",
		"max_level": 10, "bonus_target": "hp", "bonus_percent": 0.05},

	# ── Military: Battle Power (linear) ──────────────────────────────────────
	{"id": "weapon_forging", "name": "Weapon Forging", "icon": "⚔️", "category": "military_power",
		"desc": "+5% Battle Power per level", "prereq": "",
		"max_level": 10, "bonus_target": "atk", "bonus_percent": 0.05},
	{"id": "veteran_tactics", "name": "Veteran Tactics", "icon": "🎖️", "category": "military_power",
		"desc": "+5% Battle Power per level", "prereq": "weapon_forging",
		"max_level": 10, "bonus_target": "atk", "bonus_percent": 0.05},
]

static func get_tech(tech_id: String) -> Dictionary:
	for t in TECHS:
		if t["id"] == tech_id:
			return t
	return {}

static func default_technologies() -> Dictionary:
	"""Zeroed technologies dict covering every known tech (new players + old-save backfill)"""
	var out := {}
	for t in TECHS:
		out[t["id"]] = 0
	return out

static func prereq_met(technologies: Dictionary, tech_id: String) -> bool:
	"""True if tech_id's prerequisite (single tech, or ALL_PREREQ = every other tech) is satisfied"""
	var tech = get_tech(tech_id)
	if tech.is_empty():
		return false
	var prereq = tech.get("prereq", "")
	if prereq == "":
		return true
	if prereq == ALL_PREREQ:
		for t in TECHS:
			if t["id"] != tech_id and technologies.get(t["id"], 0) < 1:
				return false
		return true
	return technologies.get(prereq, 0) >= 1

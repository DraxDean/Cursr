# scripts/main/game.gd - Orchestrator (with Debug Prints)
extends Node

# --- Signals ---
signal building_jobs_updated(building_name: String)  # Emitted when a building's jobs are updated

# --- Constants ---
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# Training system definitions
const TRAINING_DEFINITIONS: Dictionary = {
	"soldier": {
		"name": "Soldier",
		"days_required": 5,
		"description": "Combat veteran. +10% combat effectiveness.",
		"building_type": "barracks"
	},
	"scholar": {
		"name": "Scholar",
		"days_required": 4,
		"description": "Learned academic. +10% science per turn.",
		"building_type": "research"
	}
}
const SOLDIER_TRAINING_COST: int = 20  # One-time gold cost to begin soldier training

# Army reference guide — used to calculate aggregate army stats (hp pool, strength)
# from unit roles instead of giving every unit its own combat fields.
const ARMY_UNIT_STATS: Dictionary = {
	"peasant":          {"label": "Villager",          "hp": 20, "atk": 5},
	"soldier_training": {"label": "Soldier (training)", "hp": 30, "atk": 10},
	"soldier":          {"label": "Soldier",            "hp": 40, "atk": 15},
	"marauder":         {"label": "Marauder",           "hp": 30, "atk": 5},
}

# --- Export Variables for Scenes ---
@export var tree_scene: PackedScene
@export var mountain_scene: PackedScene
@export var fish_scene: PackedScene

# --- Node References ---
@onready var tilemap_layer: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UI_Layer
@onready var map_objects_holder: Node2D = $MapObjects
@onready var console_modal: Control = $UI_Layer/ConsoleModal
# Manager Nodes
@onready var camera_controller: Node = $CameraController
@onready var ui_manager: Node = $UIManager
@onready var map_object_manager: Node = $MapObjectManager
@onready var turn_manager: Node = $TurnManager

# UI Components
var game_header: Control
var game_footer: Control
var resource_bar: Control

# Info Modals
var players_modal: Control
var resources_modal: Control
var buildings_modal: Control
var population_modal: Control
var army_modal: Control
var units_modal: Control
var science_modal: Control
var settings_modal: Control
var encyclopedia_modal: Control
var log_modal: Control
var graphs_modal: Control
var day_transition: Control
var game_log: Node  # GameLog manager
var game_over_modal: Control
var turn_events_modal: Control
var turn_event_manager: Node
var notification_panel: Control
var world_event_modal: Control
var active_combat_modal: Control  # Tracked so its raid timer can be refreshed on End Day
var modal_positions: Dictionary = {}  # Track modal positions to prevent overlap

# Pending pop growth to notify at end of _on_end_day_pressed (after world event)
var _pending_pop_growth: int = 0
# Monotonic counter so every event firing gets a unique instance id (see tag_event_instance)
var _event_instance_seq: int = 0

# Building System
var is_placing_building: bool = false
var building_to_place: String = ""
var building_placement_build_more: bool = false  # Track if in continuous building mode
var building_preview_sprite: Sprite2D
var building_preview_overlay: Sprite2D
var preview_green_texture: Texture2D
var preview_red_texture: Texture2D

# Building Modals
var build_selection_modal: Control
var building_placement_modal: Control
var building_details_modal: Control

# Unit Sprite Tracking - bidirectional mapping
var unit_sprite_map: Dictionary = {}  # Maps unit_id -> sprite_node for quick lookup

# Building Selection System
var selected_building: Node2D = null
var highlighted_building: Node2D = null
var building_outline_material: ShaderMaterial
var building_counter: Dictionary = {}  # Track building counts for unique IDs
var unit_counter: int = 0  # Track unit counts for unique IDs
var buildings_connections_cache: Dictionary = {}  # Cache for building-to-building connections with paths (no recalculation)
var unit_movement_paused: bool = false  # Pause unit movement paths
var unit_movement_speed: float = 1.0  # Speed multiplier for unit movement (0.5 = half speed, 2.0 = double speed)

# Name System - for generating unique unit names by race
var race_names: Dictionary = {}  # Caches loaded names: {"human": {"given": [], "surnames": []}, "elf": {...}}

# Building naming - for workplace names (building_type -> array of work-related names)
var building_work_names: Dictionary = {}  # {"fishing_hut": ["Angling", "Fishery", ...], "lumberjack": [...], ...}
var renamed_workplaces: Dictionary = {}  # Track already-renamed workplaces to avoid duplicates

# --- Variables ---
var world_data: Dictionary = {}
var loaded_buildings_data: Array = []
var loaded_units_data: Array = []
var loaded_environment_objects_data: Array = []
var current_save_path: String = ""

# Player Data Structure
var players_data: Dictionary = {
	1: {
		"name": "Player 1",
		"race": "human",
		"buildings": [],  # Array of building names owned by this player
		"units": [],  # Array of unit data owned by this player
		"resources": {
			"gold": 100,
			"food": 100,
			"wood": 100,
			"stone": 100,
			"science": 100
		},
		"resource_rates": {
			# Per-day production/consumption rates
			"gold": 0,
			"food": 0,
			"wood": 0,
			"stone": 0,
			"science": 0
		},
		"population": {
			"total": 10,  # Base starting population
			"housed": 0,  # Number of people currently housed
			"working": 0,  # Number of people currently working
			"unhoused": 10,  # total - housed
			"unemployed": 10,  # total - working
			"growth_accumulator": 0.0  # Fractional growth accumulation (adds 1 when >= 1.0)
		},
		"technologies": {
			# Tech levels; each key maps to current level (0 = not researched)
			"work_ethic": 0,
			"fishing_bonus": 0,
			"woodcutting_bonus": 0,
			"stoneworking_bonus": 0
		}
	},
	"environment": {
		"name": "Environment",
		"type": "environment",
		"objects": {
			"mountains": {},  # Dictionary of mountain_id: {name, position, tile_coords}
			"trees": {},       # Dictionary of tree_id: {name, position, tile_coords}
			"fish": {}        # Dictionary of fish_id: {name, position, tile_coords}
		},
		"counts": {
			"mountains": 0,
			"trees": 0,
			"fish": 0
		}
	}
}

# World Creation System
var world_creator: Node
var is_in_world_creation: bool = false

# Wave Spawner
var wave_spawner: Node


# --- Preload ---
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")


func _update_building_preview(_mouse_pos: Vector2):
	# Convert screen position to world position
	var world_pos = camera.get_global_mouse_position()
	# Convert to tile coordinates
	var tile_coords = tilemap_layer.local_to_map(world_pos)
	
	if building_preview_sprite and building_preview_sprite.texture:
		# Position at tile center (sprite centering handled by building script)
		var tile_center_pos = tilemap_layer.map_to_local(tile_coords)
		building_preview_sprite.position = tile_center_pos
		
		# Check if placement is valid and update sprite tint
		var can_place = _can_place_building_at_tile(tile_coords)
		if can_place:
			building_preview_sprite.modulate = Color(0.7, 1.0, 0.7, 0.7)  # Green tint
		else:
			building_preview_sprite.modulate = Color(1.0, 0.7, 0.7, 0.7)  # Red tint

func _can_place_building_at_tile(tile_coords: Vector2i) -> bool:
	# Check if tile is within map bounds
	var used_rect = tilemap_layer.get_used_rect()
	if not used_rect.has_point(tile_coords):
		return false
	
	# Check if there's already a building at this location
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child):
				var building_tile = tilemap_layer.local_to_map(child.position)
				if building_tile == tile_coords:
					return false
	
	# Additional checks could be added here (terrain type, resources, etc.)
	return true

func _try_place_building(_mouse_pos: Vector2):
	# Convert screen position to tile coordinates
	var world_pos = camera.get_global_mouse_position()
	var tile_coords = tilemap_layer.local_to_map(world_pos)
	
	if _can_place_building_at_tile(tile_coords):
		# Place the actual building
		_place_building_at_tile(tile_coords, building_to_place)
		# Only cancel placement if not in build more mode
		if not building_placement_build_more:
			_cancel_building_placement()
		# If in build more mode, placement continues with same preview
	else:
		DebugConfig.dprint("buildings", ["Cannot place building at this location"])

func _place_building_at_tile(tile_coords: Vector2i, building_type: String):
	# Get building texture path
	var building_texture_path = _get_building_texture_path(building_type)
	
	if ResourceLoader.exists(building_texture_path):
		# Generate unique building name
		var building_id = _get_next_building_id(building_type)
		var building_name = building_type + str(building_id)
		
		# Create building using proper scene
		var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
		building_scene.name = building_name
		
		# Position it at tile center (building script will handle sprite centering)
		var world_pos = tilemap_layer.map_to_local(tile_coords)
		building_scene.position = world_pos
		building_scene.z_index = 5  # Above terrain but below UI
		
		# Setup building with all data including texture and initial occupancy
		var setup_data = {
			"type": building_type,
			"texture_path": building_texture_path,
			"owner_player": 1,  # Player 1
			"building_type": building_type,
			"construction_day": turn_manager.get_day(),
			"living_occupancy": 0,  # Start with no occupancy
			"worker_occupancy": 0   # Start with no occupancy
		}
		
		# Add farm-specific state if it's a farm
		if building_type == "farm":
			setup_data["farm_state"] = "tilled"  # Start in tilled state
			building_scene.set_meta("farm_state", "tilled")
			building_scene.set_meta("farm_worker_assigned", false)
		
		# Add barracks-specific occupancy (single job type: stationed soldiers-in-training)
		if building_type == "barracks":
			setup_data["station_occupancy"] = 0
		
		if building_scene.has_method("setup"):
			building_scene.setup(setup_data)
		
		# Set initial occupancy metadata on the building node
		building_scene.set_meta("living_occupancy", 0)
		building_scene.set_meta("worker_occupancy", 0)
		
		# Set barracks-specific occupancy
		if building_type == "barracks":
			building_scene.set_meta("station_occupancy", 0)
		
		# Initialize empty jobs array for work buildings
		building_scene.set_meta("resource_jobs", [])
		
		DebugConfig.dprint("buildings", ["Game: Placing building at tile ", tile_coords, " world pos ", world_pos])
		
		# Deduct building costs from player resources
		var owner_player = setup_data.get("owner_player", 1)
		_deduct_building_cost(owner_player, building_type)
		
		# Add to map objects holder
		map_objects_holder.add_child(building_scene)
		
		# Add building to player's buildings list
		if players_data.has(owner_player):
			var player_data = players_data[owner_player]
			if not player_data.has("buildings"):
				player_data["buildings"] = []
			player_data["buildings"].append(building_name)
			DebugConfig.dprint("buildings", ["Game: Added building ", building_name, " to player ", owner_player, " buildings list"])
		
		DebugConfig.dprint("buildings", ["Game: Successfully placed ", building_type, " at world position: ", world_pos])
		if is_instance_valid(game_log):
			var GL = preload("res://scripts/managers/game_log.gd")
			var day: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0
			game_log.add(day, GL.Category.BUILDING, "Built %s at tile %s." % [building_type.capitalize().replace("_", " "), str(tile_coords)])
		
		# Calculate and cache connections for the new building (one-time, with bidirectional paths)
		_calculate_and_cache_building_connections(building_scene)
		
		# Create jobs for work buildings
		var work_buildings = ["lumberjack", "stoneworker", "fishing_hut", "research", "lumber_mill", "farmhouse", "town_center"]
		DebugConfig.dprint("buildings", ["DEBUG: Checking if ", building_type, " is a work building. Is in list: ", building_type in work_buildings])
		if building_type in work_buildings:
			DebugConfig.dprint("buildings", ["DEBUG: Creating jobs for work building ", building_type])
			# Get the worker capacity for this building type
			var worker_capacity = _get_worker_capacity(building_type)
			DebugConfig.dprint("buildings", ["DEBUG: Worker capacity for ", building_type, " is ", worker_capacity])
			if worker_capacity > 0:
				DebugConfig.dprint("buildings", ["DEBUG: About to create ", worker_capacity, " jobs"])
				_create_jobs_for_worker_capacity(building_scene, worker_capacity)
				_initialize_job_paths_on_load(building_scene)
				DebugConfig.dprint("buildings", ["DEBUG: Job creation completed"])
			else:
				DebugConfig.dprint("buildings", ["DEBUG: Worker capacity is 0, skipping job creation"])
		elif building_type == "farm":
			# Farm tile placed — initialize its state and notify nearby farmhouses to add a job
			building_scene.set_meta("farm_state", "tilled")
			building_scene.set_meta("farm_worker_assigned", false)
			_register_farm_with_nearby_farmhouse(building_scene)
		else:
			DebugConfig.dprint("buildings", ["DEBUG: Not a work building, skipping job creation"])
		
		# Refresh resource bar so housing/employment capacity updates immediately
		if is_instance_valid(resource_bar):
			resource_bar.refresh()
		# Check building and workforce achievements
		check_building_achievements()
		check_workforce_achievements()
	else:
		DebugConfig.dprint("buildings", ["Warning: Could not find building texture: ", building_texture_path])

func _get_building_texture_path(building_type: String) -> String:
	match building_type:
		"house":
			return "res://assets/buildings/human_house.png"
		"barracks":
			return "res://assets/buildings/human_barracks.png"
		"fishing_hut":
			return "res://assets/buildings/human_finshinghut.png"
		"lumberjack":
			return "res://assets/buildings/human_lumberjack.png"
		"stoneworker":
			return "res://assets/buildings/human_stoneworker.png"
		"research":
			return "res://assets/buildings/human_research.png"
		"town_center":
			return "res://assets/buildings/human_towncentre-export.png"
		"farmhouse":
			return "res://assets/buildings/human_farmhouse.png"
		"farm":
			return "res://assets/buildings/human_farm_tilled.png"  # Start with tilled state
		_:
			return "res://assets/buildings/human_towncentre-export.png"

func _get_living_capacity(building_type: String) -> int:
	"""Get the living capacity for a building type. Only houses and town_center provide housing."""
	match building_type:
		"house":
			return 7
		"town_center":
			return 20
		_:
			return 0

func _get_worker_capacity(building_type: String) -> int:
	"""Get the worker capacity for a building type"""
	match building_type:
		"town_center":
			return 2  # 2 scientist slots
		"research":
			return 8  # Research team size
		"stoneworker":
			return 10  # Most work stations employ up to 10
		"lumberjack":
			return 10
		"lumber_mill":
			return 10
		"farmhouse":
			return 6  # Agricultural workers
		"fishing_hut":
			return 5  # Fishing employs 5 labourers
		_:
			return 0

func _get_next_building_id(building_type: String) -> int:
	# Initialize counter for this building type if it doesn't exist
	if not building_counter.has(building_type):
		building_counter[building_type] = 0
	
	# Increment and return the next ID
	building_counter[building_type] += 1
	return building_counter[building_type]

func _is_building_node(node: Node) -> bool:
	# Check if node is a building by looking for common building types in the name
	var building_types = ["house", "fishing_hut", "town_center", "barracks", "farm", "farmhouse", "stoneworker", "lumberjack", "research", "lumber_mill"]
	for building_type in building_types:
		if node.name.begins_with(building_type):
			return true
	return false

func _extract_building_type_from_name(building_name: String) -> String:
	# Extract building type from name (e.g., "house1" -> "house")
	var building_types = ["fishing_hut", "town_center", "lumber_mill", "lumberjack", "stoneworker", "farmhouse", "research", "house", "barracks", "farm"]  # Order matters - check longer names first
	for building_type in building_types:
		if building_name.begins_with(building_type):
			return building_type
	return "unknown"

func get_player_buildings(player_id: int) -> Array:
	# Get list of building names owned by a player
	if players_data.has(player_id):
		var player_data = players_data[player_id]
		if player_data.has("buildings") and player_data["buildings"] is Array:
			return player_data["buildings"].duplicate()
		else:
			# Initialize buildings array if missing
			player_data["buildings"] = []
			return []
	return []

func get_player_building_nodes(player_id: int) -> Array:
	# Get actual building nodes owned by a player
	var player_buildings = get_player_buildings(player_id)
	var building_nodes = []
	
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.name in player_buildings:
				building_nodes.append(child)
	
	return building_nodes

func remove_building_from_player(building_name: String, player_id: int):
	# Remove building from player's buildings list (for destruction, etc.)
	if players_data.has(player_id):
		var player_data = players_data[player_id]
		if not player_data.has("buildings"):
			return  # No buildings to remove
		var buildings = player_data["buildings"]
		var index = buildings.find(building_name)
		if index >= 0:
			buildings.remove_at(index)
			DebugConfig.dprint("buildings", ["Game: Removed building ", building_name, " from player ", player_id, " buildings list"])

func debug_print_all_buildings():
	# Debug function to print all buildings and their status
	DebugConfig.dprint("buildings", ["=== BUILDING DEBUG INFO ==="])
	DebugConfig.dprint("buildings", ["Player 1 buildings list: ", players_data.get(1, {}).get("buildings", [])])
	
	if map_objects_holder:
		DebugConfig.dprint("buildings", ["All objects in map_objects_holder:"])
		for child in map_objects_holder.get_children():
			DebugConfig.dprint("buildings", ["  - Name: ", child.name, " | Is Building: ", _is_building_node(child)])
			if _is_building_node(child):
				var building_type = _extract_building_type_from_name(child.name)
				DebugConfig.dprint("buildings", ["    Type: ", building_type, " | Position: ", child.position])
	
	DebugConfig.dprint("buildings", ["Building counters: ", building_counter])
	DebugConfig.dprint("buildings", ["==========================="])

func calculate_resource_rates(player_id: int) -> Dictionary:
	"""Calculate per-day resource production/consumption rates based on buildings and workers"""
	var rates = {
		"gold": 0,
		"food": 0,
		"wood": 0,
		"stone": 0,
		"science": 0
	}
	
	if not map_objects_holder:
		return rates
	
	# Iterate through all buildings owned by this player
	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		
		var owner_player = child.get_meta("owner_player", 1)
		if owner_player != player_id:
			continue
		
		var building_type = _extract_building_type_from_name(child.name)
		
		# Count actual assigned workers from jobs, not cached occupancy
		var worker_count = 0
		var jobs = child.get_meta("resource_jobs", [])
		if not jobs.is_empty():
			# Count jobs with assigned units
			for job in jobs:
				if job.get("unit_assigned") != null:
					worker_count += 1
		else:
			# Fallback to metadata if no jobs exist
			worker_count = child.get_meta("worker_occupancy", 0)
		
		# Each building type produces different resources based on worker count
		match building_type:
			"lumberjack":
				rates["wood"] += worker_count * 5  # +5 wood per worker
			"lumber_mill":
				rates["wood"] += worker_count * 5  # +5 wood per worker
			"stoneworker":
				rates["stone"] += worker_count * 5  # +5 stone per worker
			"fishing_hut":
				rates["food"] += worker_count * 5  # +5 food per worker
			"town_center":
				rates["science"] += worker_count * 3  # +3 science per scientist
			"research":
				# Tiered production: scholars-in-training contribute less than fully trained scholars
				if jobs.is_empty():
					rates["science"] += worker_count * 3  # Fallback when no job slots exist yet
				else:
					for job in jobs:
						var assigned_uid = job.get("unit_assigned")
						if assigned_uid == null:
							continue
						var worker_unit = _get_unit_by_uid(player_id, assigned_uid)
						if worker_unit.get("type", "peasant") == "scholar":
							rates["science"] += 5
						else:
							rates["science"] += 3
			"farm":
				# Per-farm contribution: +FARM_HARVEST_FOOD only if this tile is grown with a worker
				if child.get_meta("farm_worker_assigned", false) and child.get_meta("farm_state", "tilled") == "grown":
					rates["food"] += FARM_HARVEST_FOOD
			"barracks":
				# Barracks don't produce resources
				pass
			"house", "farmhouse":
				# Housing doesn't produce resources
				pass
	
	# Update player data
	if players_data.has(player_id):
		players_data[player_id]["resource_rates"] = rates
	
	# Apply technology bonuses (post-calculation multipliers)
	_apply_tech_bonuses_to_rates(player_id, rates)
	
	# Subtract food upkeep from food rate so bar shows the net (-1 per citizen)
	var pop_total: int = players_data.get(player_id, {}).get("population", {}).get("total", 0)
	rates["food"] = rates.get("food", 0) - pop_total
	# Persist net rate
	if players_data.has(player_id):
		players_data[player_id]["resource_rates"]["food"] = rates["food"]
	
	return rates

func _apply_tech_bonuses_to_rates(player_id: int, rates: Dictionary):
	"""Apply researched technology bonuses to the already-calculated base rates"""
	if not players_data.has(player_id):
		return
	var techs = players_data[player_id].get("technologies", {})
	
	# Work Ethic: +5% to ALL resource production per level
	var work_ethic_level = techs.get("work_ethic", 0)
	if work_ethic_level > 0:
		var global_mult = work_ethic_level * 0.05
		for key in rates:
			rates[key] = int(rates[key] * (1.0 + global_mult))
	
	# Fishing Bonus: +5% food per level (on top of work ethic)
	var fishing_level = techs.get("fishing_bonus", 0)
	if fishing_level > 0 and rates.has("food"):
		rates["food"] = int(rates["food"] * (1.0 + fishing_level * 0.05))
	
	# Woodcutting Bonus: +5% wood per level
	var woodcutting_level = techs.get("woodcutting_bonus", 0)
	if woodcutting_level > 0 and rates.has("wood"):
		rates["wood"] = int(rates["wood"] * (1.0 + woodcutting_level * 0.05))
	
	# Stoneworking Bonus: +5% stone per level
	var stoneworking_level = techs.get("stoneworking_bonus", 0)
	if stoneworking_level > 0 and rates.has("stone"):
		rates["stone"] = int(rates["stone"] * (1.0 + stoneworking_level * 0.05))
	
	# Persist the bonus-adjusted rates back
	players_data[player_id]["resource_rates"] = rates

func get_tech_level(player_id: int, tech_id: String) -> int:
	"""Return current research level for a technology"""
	if not players_data.has(player_id):
		return 0
	return players_data[player_id].get("technologies", {}).get(tech_id, 0)

func get_tech_cost(current_level: int) -> int:
	"""Cost to advance from current_level to current_level+1. Doubles each level: 50,100,200…"""
	return 50 * int(pow(2, current_level))

func research_tech(player_id: int, tech_id: String, max_level: int = 10) -> bool:
	"""Attempt to purchase the next level of a technology. Returns true on success."""
	if not players_data.has(player_id):
		return false
	var player_data = players_data[player_id]
	
	# Ensure technologies dict exists (backward compat with old saves)
	if not player_data.has("technologies"):
		player_data["technologies"] = {
			"work_ethic": 0, "fishing_bonus": 0,
			"woodcutting_bonus": 0, "stoneworking_bonus": 0
		}
	
	var current_level = player_data["technologies"].get(tech_id, 0)
	if current_level >= max_level:
		DebugConfig.dprint("general", ["Tech %s already at max level %d" % [tech_id, max_level]])
		return false
	
	# Check prerequisites: fishing/woodcutting/stoneworking require work_ethic >= 1
	var prereqs = {
		"fishing_bonus": "work_ethic",
		"woodcutting_bonus": "work_ethic",
		"stoneworking_bonus": "work_ethic"
	}
	if prereqs.has(tech_id):
		var req = prereqs[tech_id]
		if player_data["technologies"].get(req, 0) < 1:
			DebugConfig.dprint("general", ["Tech %s requires %s level 1+" % [tech_id, req]])
			return false
	
	var cost = get_tech_cost(current_level)
	var resources = player_data.get("resources", {})
	var current_science = resources.get("science", 0)
	
	if current_science < cost:
		DebugConfig.dprint("general", ["Not enough science: need %d, have %d" % [cost, current_science]])
		return false
	
	# Deduct science and apply upgrade
	resources["science"] = current_science - cost
	player_data["resources"] = resources
	player_data["technologies"][tech_id] = current_level + 1
	players_data[player_id] = player_data
	
	# Recalculate rates with new bonus
	calculate_resource_rates(player_id)
	
	DebugConfig.dprint("general", ["Researched %s to level %d (cost %d science)" % [tech_id, current_level + 1, cost]])
	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(turn_manager.get_day() if is_instance_valid(turn_manager) else 0,
			GL.Category.RESEARCH,
			"Researched %s to level %d (cost %d science)." % [tech_id.capitalize().replace("_", " "), current_level + 1, cost])
	check_research_achievements()
	return true

func get_resource_rates(player_id: int) -> Dictionary:
	"""Get current resource rates for a player"""
	if players_data.has(player_id):
		return players_data[player_id].get("resource_rates", {
			"gold": 0,
			"food": 0,
			"wood": 0,
			"stone": 0,
			"science": 0
		})
	return {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0}

func get_total_housing_capacity(player_id: int) -> int:
	"""Sum living capacity across all buildings owned by this player."""
	var total: int = 0
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.get_meta("owner_player", 1) == player_id:
				total += _get_living_capacity(child.get_meta("building_type", ""))
	return total

func apply_resource_production(player_id: int):
	"""Apply resource production based on current rates, then deduct food upkeep (1 per citizen)"""
	if not players_data.has(player_id):
		return
	
	var player_data = players_data[player_id]
	var rates = player_data.get("resource_rates", {})
	var resources = player_data.get("resources", {})
	
	# Ensure all resource types exist in the resources dict (for compatibility with old saves)
	for resource_type in rates.keys():
		if not resources.has(resource_type):
			resources[resource_type] = 0
	
	# Apply production to each resource
	for resource_type in rates.keys():
		resources[resource_type] += rates[resource_type]
		if rates[resource_type] != 0:
			DebugConfig.dprint("general", ["Player ", player_id, " produced +", rates[resource_type], " ", resource_type])
	
	# Food upkeep: -1 food per citizen per day
	var pop_total: int = player_data.get("population", {}).get("total", 0)
	if pop_total > 0:
		if not resources.has("food"):
			resources["food"] = 0
		resources["food"] = max(0, resources["food"] - pop_total)
		DebugConfig.dprint("general", ["Player ", player_id, " food upkeep: -", pop_total, " (population)"])

func _deduct_building_cost(player_id: int, building_type: String):
	"""Deduct building cost from player resources"""
	if not players_data.has(player_id):
		return
	
	var building_costs = {
		"house": {"wood": 10, "stone": 5},
		"barracks": {"wood": 10, "stone": 5},
		"fishing_hut": {"wood": 12, "stone": 3},
		"lumberjack": {"wood": 15, "stone": 8},
		"stoneworker": {"wood": 8, "stone": 15},
		"research": {"wood": 20, "stone": 10},
		"town_center": {"wood": 30, "stone": 25, "gold": 15},
		"farmhouse": {"wood": 15},
		"farm": {"wood": 10},
		"lumber_mill": {"wood": 20, "stone": 10}
	}
	
	var costs = building_costs.get(building_type, {})
	var player_data = players_data[player_id]
	var resources = player_data.get("resources", {})
	
	# Ensure all resource types exist
	for resource_type in costs.keys():
		if not resources.has(resource_type):
			resources[resource_type] = 0
	
	# Deduct costs
	for resource_type in costs.keys():
		resources[resource_type] -= costs[resource_type]
		DebugConfig.dprint("buildings", ["Player ", player_id, " paid -", costs[resource_type], " ", resource_type, " for ", building_type])

func log_to_console(message: String):
	# Send message to debug console
	if is_instance_valid(console_modal):
		console_modal.add_debug_message(message)
	else:
		print(message)

# Environment Object Management Functions
func register_mountain(mountain_node: Node2D) -> String:
	# Generate unique ID for mountain
	var mountain_id = "mountain_" + str(players_data["environment"]["counts"]["mountains"] + 1)
	
	# Get tile coordinates
	var tile_coords = Vector2i(0, 0)
	if tilemap_layer:
		tile_coords = tilemap_layer.local_to_map(mountain_node.position)
	
	# Store mountain data
	players_data["environment"]["objects"]["mountains"][mountain_id] = {
		"name": mountain_node.name,
		"position": mountain_node.position,
		"tile_coords": tile_coords,
		"node_path": mountain_node.get_path(),
		"job": null  # Track which job is assigned to this resource
	}
	
	# Update count
	players_data["environment"]["counts"]["mountains"] += 1
	
	# Update the node name to include the unique ID
	mountain_node.name = mountain_id
	mountain_node.set_meta("environment_id", mountain_id)
	
	return mountain_id

func register_tree(tree_node: Node2D) -> String:
	# Generate unique ID for tree
	var tree_id = "tree_" + str(players_data["environment"]["counts"]["trees"] + 1)
	
	# Get tile coordinates
	var tile_coords = Vector2i(0, 0)
	if tilemap_layer:
		tile_coords = tilemap_layer.local_to_map(tree_node.position)
	
	# Store tree data
	players_data["environment"]["objects"]["trees"][tree_id] = {
		"name": tree_node.name,
		"position": tree_node.position,
		"tile_coords": tile_coords,
		"node_path": tree_node.get_path(),
		"job": null  # Track which job is assigned to this resource
	}
	
	# Update count
	players_data["environment"]["counts"]["trees"] += 1
	
	# Update the node name to include the unique ID
	tree_node.name = tree_id
	tree_node.set_meta("environment_id", tree_id)
	
	return tree_id

func register_fish(fish_node: Node2D) -> String:
	# Generate unique ID for fish
	var fish_id = "fish_" + str(players_data["environment"]["counts"]["fish"] + 1)
	
	# Get tile coordinates
	var tile_coords = Vector2i(0, 0)
	if tilemap_layer:
		tile_coords = tilemap_layer.local_to_map(fish_node.position)
	
	# Store fish data
	players_data["environment"]["objects"]["fish"][fish_id] = {
		"name": fish_node.name,
		"position": fish_node.position,
		"tile_coords": tile_coords,
		"node_path": fish_node.get_path(),
		"job": null  # Track which job is assigned to this resource
	}
	
	# Update count
	players_data["environment"]["counts"]["fish"] += 1
	
	# Update the node name to include the unique ID
	fish_node.name = fish_id
	fish_node.set_meta("environment_id", fish_id)
	
	return fish_id

func get_environment_objects(object_type: String) -> Dictionary:
	# Get all environment objects of a specific type (mountains, trees, etc.)
	if players_data.has("environment") and players_data["environment"]["objects"].has(object_type):
		return players_data["environment"]["objects"][object_type]
	return {}

func get_player_population_data(player_id: int) -> Dictionary:
	# Get population data for a specific player
	if players_data.has(player_id):
		var player_data = players_data[player_id]
		var pop_data = player_data.get("population", {})
		return pop_data
	return {}

func get_resource_on_tile(tile_coords: Vector2i) -> Dictionary:
	"""Get the resource object on a specific tile.
	Returns the resource data if found, or empty dict if none found.
	Prints error if more than 1 resource is on the same tile."""
	var found_resources = []
	
	# Check all resource types
	var resource_types = ["mountains", "trees", "fish"]
	
	for resource_type in resource_types:
		var objects = get_environment_objects(resource_type)
		for obj_id in objects:
			var obj_data = objects[obj_id]
			if obj_data.get("tile_coords") == tile_coords:
				found_resources.append({
					"id": obj_id,
					"type": resource_type,
					"data": obj_data
				})
	
	# Check for multiple resources on same tile (error condition)
	if found_resources.size() > 1:
		push_error("ERROR: Found ", found_resources.size(), " resources on tile ", tile_coords, "! Should only have 1.")
		for res in found_resources:
			push_error("  - ", res["type"], " (", res["id"], ")")
	
	# Return first (only) resource if found
	if found_resources.size() == 1:
		return found_resources[0]["data"]
	
	return {}

func _clear_all_resource_job_markers():
	"""Clear all job markers from all resources (used before pathfinding on load)"""
	var resource_types = ["mountains", "trees", "fish"]
	var total_cleared = 0
	
	for resource_type in resource_types:
		var objects = get_environment_objects(resource_type)
		for obj_id in objects:
			if objects[obj_id].get("job") != null:
				objects[obj_id]["job"] = null
				total_cleared += 1
	
	if total_cleared > 0:
		DebugConfig.dprint("jobs", ["Game: Cleared ", total_cleared, " resource job markers before pathfinding"])

func _count_actual_occupancy(building_name: String, capacity_type: String, owner_player: int) -> int:
	"""Count actual number of units assigned to a building for a specific capacity type"""
	if not players_data.has(owner_player):
		return 0
	
	var player_units = players_data[owner_player].get("units", [])
	var count = 0
	
	for unit in player_units:
		var job = unit.get("job", null)
		var living_quarters = unit.get("living_quarters", null)
		
		# Count based on capacity type
		if capacity_type == "living" and living_quarters == building_name:
			count += 1
		elif capacity_type == "worker" and job == building_name:
			count += 1
		elif capacity_type == "station":
			# For barracks jobs, check the job naming convention
			var expected_job = building_name + "_station"
			if job == expected_job:
				count += 1
	
	return count

func update_building_occupancy(building_node: Node2D, capacity_type: String, new_value: int) -> bool:
	# Update building occupancy and validate against available population
	if not building_node:
		return false
	
	var owner_player = building_node.get_meta("owner_player", 1)
	
	# For worker capacity, count filled jobs instead of using occupancy number
	if capacity_type == "worker":
		var jobs = building_node.get_meta("resource_jobs", [])
		var filled_count = 0
		for job in jobs:
			if job.get("unit_assigned") != null:
				filled_count += 1
		
		var max_jobs = jobs.size()
		var difference = new_value - filled_count
		
		DebugConfig.dprint("population", ["DEBUG: Worker capacity change - filled jobs: ", filled_count, " -> new: ", new_value, ", max jobs available: ", max_jobs, " (diff: ", difference, ")"])
		
		if difference > 0:
			# Need to assign more units to existing job slots
			var available_pop = get_player_population_data(owner_player).get("unemployed", 0)
			if available_pop < difference:
				DebugConfig.dprint("population", ["Not enough unemployed population to fill ", difference, " jobs. Available: ", available_pop])
				return false
			# Auto-assign units to empty job slots
			_auto_assign_units_to_building(building_node, capacity_type, difference)
		elif difference < 0:
			# Need to unassign units from filled job slots
			_remove_excess_unit_assignments(building_node, capacity_type, abs(difference), owner_player)
		
		# Recalculate global population
		update_player_population(owner_player)
		
		# Recalculate resource production rates
		calculate_resource_rates(owner_player)
		
		# Emit signal for modal updates
		building_jobs_updated.emit(building_node.name)
		
		return true
	
	# For non-worker capacity types (living, station), use original logic
	var current_occupancy = building_node.get_meta(capacity_type + "_occupancy", 0)
	var occupancy_difference = new_value - current_occupancy
	
	# Check if we have enough available population for increases
	if occupancy_difference > 0:
		var pop_data = get_player_population_data(owner_player)
		var available = 0
		if capacity_type == "living":
			available = pop_data.get("unhoused", 0)
		elif capacity_type == "station":
			# For barracks jobs, check unemployed population
			available = pop_data.get("unemployed", 0)
		
		DebugConfig.dprint("population", ["DEBUG: Capacity check for ", capacity_type, " - need ", occupancy_difference, ", available ", available])
		
		if available < occupancy_difference:
			DebugConfig.dprint("population", ["Not enough ", capacity_type, " population available. Need ", occupancy_difference, ", have ", available])
			return false
	
	# Update building occupancy
	building_node.set_meta(capacity_type + "_occupancy", new_value)
	
	# Auto-assign units to this building if capacity increased
	if occupancy_difference > 0:
		# For barracks: ensure job slots exist before assigning units
		if capacity_type == "station":
			var current_jobs = building_node.get_meta("resource_jobs", []).size()
			_create_jobs_for_worker_capacity(building_node, current_jobs + occupancy_difference)
		# Assign units to existing unassigned jobs (jobs exist at max capacity from creation)
		_auto_assign_units_to_building(building_node, capacity_type, occupancy_difference)
	elif occupancy_difference < 0:
		# Capacity decreased - remove unit assignments from some jobs (keep job slots)
		_remove_excess_unit_assignments(building_node, capacity_type, abs(occupancy_difference), owner_player)
	
	# Recalculate global population
	update_player_population(owner_player)
	
	# Recalculate resource production rates based on worker assignments
	calculate_resource_rates(owner_player)
	
	return true

func update_player_population(player_id: int):
	# Recalculate housed/unhoused and working/unemployed populations
	if not players_data.has(player_id):
		return

	var player_data = players_data[player_id]
	var pop_data = player_data.get("population", {})
	
	# Clean up unit sprites that lost assignments
	_cleanup_unassigned_unit_sprites(player_id)

	# Derive total from the actual unit list (excluding pets) — source of truth
	var total_pop: int = 0
	for unit in player_data.get("units", []):
		if not unit.get("is_pet", false):
			total_pop += 1

	# Calculate housed population from actual building data
	var total_housed = 0
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.get_meta("owner_player", 1) == player_id:
				total_housed += child.get_meta("living_occupancy", 0)
	
	# Calculate working population directly from units (job field is the source of truth)
	var total_working = 0
	for unit in player_data.get("units", []):
		if not unit.get("is_pet", false) and unit.get("job", null) != null:
			total_working += 1
	
	# Update population data — keep total in sync with actual unit count
	pop_data["total"] = total_pop
	pop_data["housed"] = total_housed
	pop_data["working"] = total_working
	pop_data["unhoused"] = total_pop - total_housed
	pop_data["unemployed"] = total_pop - total_working
	
	DebugConfig.dprint("population", ["DEBUG: Population update - Total: ", total_pop, " | Housed: ", total_housed, " (unhoused: ", pop_data["unhoused"], ") | Working: ", total_working, " (unemployed: ", pop_data["unemployed"], ")"])
	
	player_data["population"] = pop_data
	
	# Ensure values don't go negative
	pop_data["unhoused"] = max(0, pop_data["unhoused"])
	pop_data["unemployed"] = max(0, pop_data["unemployed"])
	
	# Ensure sprites exist for fully assigned units after population updates
	_check_and_create_missing_sprites(player_id)

func apply_population_growth(player_id: int):
	"""Apply population growth per turn (current_total * 0.34, ~1 new villager every 3 turns).
	New citizens are only born if there is spare housing capacity."""
	if not players_data.has(player_id):
		return
	
	var player_data = players_data[player_id]
	var pop_data = player_data.get("population", {})
	
	if pop_data.is_empty():
		return
	
	# Calculate available housing capacity
	var total_housing_capacity: int = 0
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.get_meta("owner_player", 1) == player_id:
				total_housing_capacity += _get_living_capacity(child.get_meta("building_type", ""))
	var currently_housed: int = pop_data.get("housed", 0)
	var free_housing: int = max(0, total_housing_capacity - currently_housed)
	
	# No housing available — no growth this turn (accumulator still advances so growth resumes when housing is built)
	if free_housing <= 0:
		return
	
	var current_total = pop_data.get("total", 10)
	var growth_accumulator = pop_data.get("growth_accumulator", 0.0)
	
	# Calculate growth: 3.4% of current population per turn (~1 new unit every 3 turns at pop 10)
	var daily_growth = current_total * 0.034
	growth_accumulator += daily_growth
	
	# Convert accumulated growth to actual population increase, capped by free housing
	var pop_to_add: int = min(int(growth_accumulator), free_housing)
	if pop_to_add > 0:
		growth_accumulator -= pop_to_add  # Keep the fractional part
		DebugConfig.dprint("population", ["Player ", player_id, " population grew by ", pop_to_add])
		# Create actual unit entries (handles sprite, housing, pop count update)
		add_event_units(player_id, pop_to_add)
		var new_total: int = players_data[player_id].get("population", {}).get("total", 0)
		# Log the birth event
		if is_instance_valid(game_log):
			var GL = preload("res://scripts/managers/game_log.gd")
			var citizen_word := "citizen" if pop_to_add == 1 else "citizens"
			game_log.add(
				turn_manager.get_day() if is_instance_valid(turn_manager) else 0,
				GL.Category.EVENT,
				"👶 +%d %s born! Population: %d" % [pop_to_add, citizen_word, new_total]
			)
		# Queue notification to fire after the world event in _on_end_day_pressed
		_pending_pop_growth += pop_to_add
	
	# Store updated accumulator
	pop_data["growth_accumulator"] = growth_accumulator

func _check_and_create_missing_sprites(player_id: int):
	"""Check for units with both assignments but no sprites and create them"""
	if not players_data.has(player_id) or not map_objects_holder:
		return
	
	var player_data = players_data[player_id]
	var player_units = player_data.get("units", [])
	
	DebugConfig.dprint("population", ["DEBUG: _check_and_create_missing_sprites for player ", player_id, " - checking ", player_units.size(), " units"])
	
	for unit in player_units:
		var unit_id = unit["unique_id"]
		var living_quarters = unit.get("living_quarters", null)
		var job = unit.get("job", null)
		var has_full_assignment = living_quarters != null and job != null
		
		var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
		
		if has_full_assignment:
			if not existing_sprite:
				_create_unit_sprite_and_start_cycle(unit)
			else:
				# Sprite exists — check for state transitions
				var old_job = unit.get("previous_job", job)
				var current_state = unit.get("movement_state", "idle")
				
				if old_job != job or current_state == "idle_wander" or current_state == "returning_home":
					# Job changed OR unit was wandering but now fully assigned: start work cycle
					unit["movement_state"] = "idle"
					unit["current_path"] = []
					unit["path_index"] = 0
					unit["movement_cycle_step"] = 0
					unit["work_timer"] = 0.0
					unit["previous_job"] = job
				
				# Always ensure job_connections are available
				if not unit.has("job_connections") or unit.get("job_connections", []).is_empty():
					var job_building = job
					if job.contains("_station") or job.contains("_training"):
						job_building = job.substr(0, job.rfind("_"))
					var job_building_node = map_objects_holder.get_node_or_null(NodePath(job_building))
					if job_building_node:
						unit["job_connections"] = _find_building_connections_for_unit(job_building_node)
				
				if not unit.has("sprite_id") or unit.get("sprite_id") == "":
					unit["sprite_id"] = unit_id
					unit_sprite_map[unit_id] = existing_sprite
				_start_unit_movement_cycle(unit)
		else:
			# Unit not fully assigned — ensure it's in idle_wander if it has a sprite
			if existing_sprite:
				var current_state = unit.get("movement_state", "idle_wander")
				if current_state != "idle_wander" and current_state != "moving":
					unit["movement_state"] = "idle_wander"
					unit["current_path"] = []
					unit["path_index"] = 0
					unit["work_timer"] = 0.0

func _cleanup_unassigned_unit_sprites(player_id: int):
	"""Remove sprites for units that lost housing or work assignments"""
	if not players_data.has(player_id) or not map_objects_holder:
		return
	
	var player_data = players_data[player_id]
	var player_units = player_data.get("units", [])
	
	for unit in player_units:
		var living_quarters = unit.get("living_quarters", null)
		var job = unit.get("job", null)
		
		# Check if unit lost either assignment
		if living_quarters == null or job == null:
			# Unit is unassigned — keep its sprite but switch to idle wandering near town centre
			var unit_id = unit["unique_id"]
			var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
			if existing_sprite:
				var current_state = unit.get("movement_state", "idle_wander")
				# Don't override returning_home or moving (already heading somewhere sensible)
				if current_state != "idle_wander" and current_state != "moving" and current_state != "returning_home":
					unit["movement_state"] = "idle_wander"
					unit["current_path"] = []
					unit["path_index"] = 0
					unit["movement_cycle_step"] = 0
					unit["work_timer"] = 0.0

func _remove_unit_assignments_for_building(building_name: String, owner_player: int):
	"""Remove assignments for units that were assigned to a demolished building"""
	if not players_data.has(owner_player):
		return
	
	var player_data = players_data[owner_player]
	var player_units = player_data.get("units", [])
	
	for unit in player_units:
		var unit_id = unit["unique_id"]
		var assignments_removed = false
		
		# Check if unit was living in this building
		if unit.get("living_quarters", null) == building_name:
			unit["living_quarters"] = null
			assignments_removed = true
			DebugConfig.dprint("buildings", ["Removed living assignment for unit ", unit_id, " from demolished building ", building_name])
		
		# Check if unit was working in this building
		if unit.get("job", null) == building_name:
			unit["job"] = null
			_cancel_unit_training(unit)  # No longer working here — stop any in-progress training
			assignments_removed = true
			DebugConfig.dprint("buildings", ["Removed job assignment for unit ", unit_id, " from demolished building ", building_name])
		
		# If assignments were removed, path back home first, then idle_wander
		if assignments_removed:
			unit["movement_cycle_step"] = 0
			_start_return_home(unit)

func _remove_excess_unit_assignments(building_node: Node2D, capacity_type: String, excess_count: int, owner_player: int):
	"""Remove assignments when building capacity is reduced"""
	if not players_data.has(owner_player):
		return
	
	var building_name = building_node.name
	var player_data = players_data[owner_player]
	var player_units = player_data.get("units", [])
	var assignments_removed = 0
	
	# For worker capacity, we also need to clear the job slots
	var jobs = []
	if capacity_type == "worker":
		jobs = building_node.get_meta("resource_jobs", [])
	
	# Find units assigned to this building and remove excess assignments
	for unit in player_units:
		if assignments_removed >= excess_count:
			break
		
		var unit_id = unit["unique_id"]
		var should_remove = false
		
		# Check if unit is assigned to this building for the reduced capacity type
		if capacity_type == "living" and unit.get("living_quarters", null) == building_name:
			should_remove = true
		elif capacity_type == "worker" and unit.get("job", null) == building_name:
			should_remove = true
		elif capacity_type == "station":
			# For barracks jobs, look for the specific job name pattern
			var expected_job = building_name + "_station"
			if unit.get("job", null) == expected_job:
				should_remove = true
		
		if should_remove:
			# For worker capacity, also clear the unit_assigned field from the job slot
			if capacity_type == "worker":
				for job in jobs:
					if job.get("unit_assigned") == unit_id:
						job["unit_assigned"] = null
						job["assigned_job_index"] = -1
						# If this was a farm job, release the farm tile's worker lock and clear mirror
						if job.get("resource_type", "") == "farm":
							var farm_node = map_objects_holder.get_node_or_null(NodePath(job.get("resource_id", "")))
							if is_instance_valid(farm_node):
								farm_node.set_meta("farm_worker_assigned", false)
								# Remove the display mirror from the farm tile
								var fm_jobs: Array = farm_node.get_meta("resource_jobs", [])
								fm_jobs = fm_jobs.filter(func(j): return j.get("resource_type", "") != "farm_mirror")
								farm_node.set_meta("resource_jobs", fm_jobs)
						DebugConfig.dprint("population", ["DEBUG: Cleared job slot unit_assigned for unit ", unit_id])
						break
			
			# Remove the specific assignment from the unit
			if capacity_type == "living":
				unit["living_quarters"] = null
			elif capacity_type == "worker":
				unit["job"] = null
				_cancel_unit_training(unit)  # No longer working here — stop any in-progress training
			elif capacity_type == "station":
				unit["job"] = null
				_cancel_unit_training(unit)  # No longer stationed — stop any in-progress training
			
			assignments_removed += 1
			DebugConfig.dprint("population", ["Removed ", capacity_type, " assignment for unit ", unit_id, " due to capacity reduction at ", building_name])
			
			# Path back home first, then idle_wander on arrival
			unit["movement_cycle_step"] = 0
			_start_return_home(unit)

func _create_jobs_for_worker_capacity(building_node: Node2D, new_capacity: int):
	"""Create empty job entries when worker capacity increases (no pathfinding)"""
	if not building_node:
		return
	
	var building_type = building_node.get_meta("building_type", "unknown")
	
	# Only create jobs for work buildings (farmhouse jobs are farm-specific — created by _initialize_farmhouse_paths)
	var work_buildings = ["lumberjack", "stoneworker", "fishing_hut", "research", "lumber_mill", "barracks", "town_center"]
	if not building_type in work_buildings:
		DebugConfig.dprint("jobs", ["DEBUG: Building type ", building_type, " is not a work building, skipping job creation"])
		return
	
	# Get existing jobs or create new array
	var jobs = building_node.get_meta("resource_jobs", [])
	var current_job_count = jobs.size()
	var new_jobs_needed = new_capacity - current_job_count
	
	DebugConfig.dprint("jobs", ["DEBUG: Creating jobs for ", building_type, " - capacity: ", new_capacity, ", current jobs: ", current_job_count, ", need: ", new_jobs_needed])
	
	if new_jobs_needed <= 0:
		DebugConfig.dprint("jobs", ["DEBUG: No new jobs needed (", new_jobs_needed, ")"])
		return  # No new jobs to create
	
	# Create simple job entries without pathfinding
	for i in range(current_job_count, new_capacity):
		var job = {
			"job_id": "job_" + building_node.name + "_" + str(i),
			"path_id": "",
			"resource_id": "",
			"resource_type": "",
			"tile_path": [],
			"world_path": [],
			"unit_assigned": null,
			"created_day": 0
		}
		jobs.append(job)
	
	# Update building metadata with jobs
	building_node.set_meta("resource_jobs", jobs)
	# Notify modal that jobs have been updated
	building_jobs_updated.emit(building_node.name)
	DebugConfig.dprint("jobs", ["DEBUG: Successfully created %d empty job slots for %s (building: %s). Total jobs now: %d" % [new_jobs_needed, building_type, building_node.name, jobs.size()]])

func _initialize_job_paths_on_load(building_node: Node2D):
	"""Initialize paths for jobs on load by finding nearby resources"""
	if not building_node:
		return
	
	var building_type = building_node.get_meta("building_type", "unknown")
	
	DebugConfig.dprint("jobs", ["DEBUG: Initializing job paths for ", building_type, " (", building_node.name, ")"])
	
	# Farmhouse paths to nearby farm tile buildings — separate logic
	if building_type == "farmhouse":
		_initialize_farmhouse_paths(building_node)
		return
	
	# Only initialize paths for work buildings that harvest map resources
	var work_buildings = ["lumberjack", "stoneworker", "fishing_hut", "research", "lumber_mill"]
	if not building_type in work_buildings:
		DebugConfig.dprint("jobs", ["DEBUG: Not a resource-harvesting work building, skipping path init"])
		return
	
	var jobs = building_node.get_meta("resource_jobs", [])
	DebugConfig.dprint("jobs", ["DEBUG: Found ", jobs.size(), " jobs to initialize"])
	
	if jobs.is_empty():
		DebugConfig.dprint("jobs", ["DEBUG: No jobs found, skipping path init"])
		return
	
	# Determine resource type based on building type
	var resource_type = ""
	match building_type:
		"lumberjack", "lumber_mill":
			resource_type = "trees"
		"stoneworker":
			resource_type = "mountains"
		"fishing_hut":
			resource_type = "fish"
		"research":
			# Research buildings don't target specific resources
			DebugConfig.dprint("jobs", ["DEBUG: Research building doesn't target resources, skipping"])
			return
	
	# Get building tile coordinates
	var building_tile = tilemap_layer.local_to_map(building_node.position)
	var job_count = jobs.size()
	
	DebugConfig.dprint("jobs", ["DEBUG: Searching for ", job_count, " resources of type ", resource_type, " from tile ", building_tile])
	
	# Find nearby resources up to the job count
	var nearby_resources = _find_nearby_resources(building_tile, resource_type, job_count)
	
	DebugConfig.dprint("jobs", ["DEBUG: Found ", nearby_resources.size(), " nearby resources"])
	
	# If we found resources, calculate paths to them
	var resource_paths = []
	if not nearby_resources.is_empty():
		resource_paths = _calculate_paths_to_resources(building_node, nearby_resources)
	
	# Assign paths to jobs
	for i in range(jobs.size()):
		if i < resource_paths.size():
			var path_data = resource_paths[i]
			jobs[i]["path_id"] = path_data["path_id"]
			jobs[i]["resource_id"] = path_data["resource_id"]
			jobs[i]["resource_type"] = resource_type
			jobs[i]["tile_path"] = path_data["tile_path"]
			jobs[i]["world_path"] = path_data["world_path"]
	
	# Mark resources as assigned to jobs (conflict avoidance)
	var objects = get_environment_objects(resource_type)
	for i in range(jobs.size()):
		if i < resource_paths.size():
			var job = jobs[i]
			var resource_id = job.get("resource_id")
			var job_id = job.get("job_id", "")
			if resource_id and resource_id in objects:
				objects[resource_id]["job"] = job_id
				DebugConfig.dprint("jobs", ["Game: Marked resource ", resource_id, " as assigned to job ", job_id])
	
	# Update building metadata
	building_node.set_meta("resource_jobs", jobs)
	# Notify modal that jobs have been updated
	building_jobs_updated.emit(building_node.name)
	DebugConfig.dprint("jobs", ["DEBUG: Initialized %d job paths for %s (building: %s). Total jobs: %d" % [resource_paths.size(), building_type, building_node.name, jobs.size()]])

func get_nearest_environment_objects(position: Vector2, object_type: String, max_count: int = -1) -> Array:
	# Get environment objects sorted by distance from a position
	var objects = get_environment_objects(object_type)
	var object_list = []
	
	for obj_id in objects:
		var obj_data = objects[obj_id]
		var distance = position.distance_to(obj_data["position"])
		object_list.append({
			"id": obj_id,
			"data": obj_data,
			"distance": distance
		})
	
	# Sort by distance
	object_list.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Limit results if max_count is specified
	if max_count > 0 and object_list.size() > max_count:
		object_list = object_list.slice(0, max_count)
	
	return object_list

func debug_print_environment_objects():
	# Debug function to print environment object counts and data
	DebugConfig.dprint("map_objects", ["=== ENVIRONMENT DEBUG INFO ==="])
	if players_data.has("environment"):
		var env_data = players_data["environment"]
		DebugConfig.dprint("map_objects", ["Mountain count: ", env_data["counts"]["mountains"]])
		DebugConfig.dprint("map_objects", ["Tree count: ", env_data["counts"]["trees"]])
		DebugConfig.dprint("map_objects", ["Mountains: ", env_data["objects"]["mountains"].keys()])
		DebugConfig.dprint("map_objects", ["Trees: ", env_data["objects"]["trees"].keys()])
	else:
		DebugConfig.dprint("map_objects", ["No environment data found!"])
	DebugConfig.dprint("map_objects", ["==============================="])

func _migrate_players_data_structure():
	# Migrate old save files to include the environment player structure
	DebugConfig.dprint("save_load", ["Game: Migrating players_data structure..."])
	
	# Check for duplicate unit IDs first
	_fix_duplicate_unit_ids()
	
	# Check if environment player exists
	if not players_data.has("environment"):
		DebugConfig.dprint("save_load", ["Game: Adding missing environment player to save data"])
		players_data["environment"] = {
			"name": "Environment",
			"type": "environment",
			"objects": {
				"mountains": {},
				"trees": {}
			},
			"counts": {
				"mountains": 0,
				"trees": 0
			}
		}
	
	# Migrate player population data to new structure
	for player_id in players_data.keys():
		if typeof(player_id) == TYPE_INT:  # Only process actual players, not environment
			var player_data = players_data[player_id]
			var pop_data = player_data.get("population", {})
			
			# Migrate old population structure to new comprehensive structure
			if pop_data.has("current") and pop_data.has("max"):
				# Old structure, convert to new
				var _old_current = pop_data.get("current", 1)
				pop_data = {
					"total": 10,  # Start with base 10 population
					"housed": 0,  # Will be calculated from buildings
					"working": 0,  # Will be calculated from buildings
					"unhoused": 10,  # total - housed
					"unemployed": 10  # total - working
				}
				DebugConfig.dprint("save_load", ["Game: Migrated player ", player_id, " population to new structure"])
			elif not pop_data.has("total"):
				# New structure but missing fields
				pop_data["total"] = pop_data.get("total", 10)
				pop_data["housed"] = pop_data.get("housed", 0)
				pop_data["working"] = pop_data.get("working", 0)
				pop_data["unhoused"] = pop_data["total"] - pop_data["housed"]
				pop_data["unemployed"] = pop_data["total"] - pop_data["working"]
				DebugConfig.dprint("save_load", ["Game: Updated player ", player_id, " population structure"])
			
			player_data["population"] = pop_data
	
	# Validate existing players have required structures
	for player_id in players_data:
		var player_data = players_data[player_id]
		if str(player_id) != "environment":
			# Ensure regular players have all required fields
			if not player_data.has("buildings"):
				player_data["buildings"] = []
			if not player_data.has("resources"):
				player_data["resources"] = {"gold": 100, "food": 100, "wood": 100, "stone": 100, "science": 100}
			# Don't reset population if it already exists in new format
			if not player_data.has("population"):
				player_data["population"] = {
					"total": 10,
					"housed": 0,
					"working": 0,
					"unhoused": 10,
					"unemployed": 10,
					"growth_accumulator": 0.0
				}
			else:
				# Ensure existing population data has growth_accumulator
				var pop_data = player_data["population"]
				if not pop_data.has("growth_accumulator"):
					pop_data["growth_accumulator"] = 0.0
			# Ensure technologies dict exists for old saves
			if not player_data.has("technologies"):
				player_data["technologies"] = {
					"work_ethic": 0,
					"fishing_bonus": 0,
					"woodcutting_bonus": 0,
					"stoneworking_bonus": 0
				}
			# Ensure training fields exist on each unit for old saves
			for unit in player_data.get("units", []):
				if not unit.has("specialties"):
					unit["specialties"] = []
				if not unit.has("training"):
					unit["training"] = null
			if not player_data.has("name"):
				player_data["name"] = "Player " + str(player_id)
			if not player_data.has("race"):
				player_data["race"] = "human"
	
	# Update all players' population calculations after migration
	for player_id in players_data.keys():
		if typeof(player_id) == TYPE_INT:
			update_player_population(player_id)
	
	DebugConfig.dprint("save_load", ["Game: Players data migration complete"])

func migrate_old_building_names():
	# Migrate buildings with old coordinate-based names to new system
	DebugConfig.dprint("save_load", ["Game: Checking for buildings with old naming system..."])
	
	var buildings_to_migrate = []
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			var old_name = child.name
			# Check if this is an old-style building name
			if old_name.begins_with("TownCenter_") or old_name.begins_with("Building_"):
				buildings_to_migrate.append(child)
	
	if buildings_to_migrate.size() > 0:
		DebugConfig.dprint("save_load", ["Game: Found ", buildings_to_migrate.size(), " buildings with old names, migrating..."])
		
		# Clear player buildings list and rebuild
		if players_data.has(1):
			players_data[1]["buildings"].clear()
		
		for building in buildings_to_migrate:
			var old_name = building.name
			var building_type = "unknown"
			
			# Extract type from old naming system
			if old_name.begins_with("TownCenter_"):
				building_type = "town_center"
			elif old_name.contains("House"):
				building_type = "house"
			elif old_name.contains("Barracks"):
				building_type = "barracks"
			elif old_name.contains("FishingHut"):
				building_type = "fishing_hut"
			elif old_name.contains("Building_house"):
				building_type = "house"
			elif old_name.contains("Building_barracks"):
				building_type = "barracks"
			elif old_name.contains("Building_fishing_hut"):
				building_type = "fishing_hut"
			else:
				DebugConfig.dprint("save_load", ["Warning: Could not determine building type for: ", old_name])
				continue
			
			# Generate new name
			var building_id = _get_next_building_id(building_type)
			var new_name = building_type + str(building_id)
			
			# Update building name
			building.name = new_name
			
			# Add to player's buildings list
			if players_data.has(1):
				players_data[1]["buildings"].append(new_name)
			
			DebugConfig.dprint("save_load", ["Game: Migrated building: ", old_name, " -> ", new_name])
		
		DebugConfig.dprint("save_load", ["Game: Migration complete, auto-saving..."])
		_execute_save()
	else:
		DebugConfig.dprint("save_load", ["Game: No buildings need migration"])

func _start_building_placement(building_type: String):
	# Clear any existing building selection
	_clear_building_selection()
	_clear_building_highlight()
	
	is_placing_building = true
	building_to_place = building_type
	
	# Create preview sprite
	var building_texture_path = _get_building_texture_path(building_type)
	if ResourceLoader.exists(building_texture_path):
		var building_texture = load(building_texture_path)
		building_preview_sprite = Sprite2D.new()
		building_preview_sprite.texture = building_texture
		building_preview_sprite.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
		building_preview_sprite.z_index = 10  # Above everything
		
		add_child(building_preview_sprite)
		
		DebugConfig.dprint("buildings", ["Game: Building texture size: ", building_texture.get_size()])
		DebugConfig.dprint("buildings", ["Game: Tile size: ", str(tilemap_layer.tile_set.tile_size) if tilemap_layer.tile_set else "No tileset"])
		
		# Calculate scale to fit tile if needed
		if tilemap_layer.tile_set:
			var tile_size = tilemap_layer.tile_set.tile_size
			var texture_size = building_texture.get_size()
			DebugConfig.dprint("buildings", ["Game: Texture vs Tile size ratio: ", texture_size.x / tile_size.x, ", ", texture_size.y / tile_size.y])
	
	DebugConfig.dprint("buildings", ["Game: Started building placement mode for: ", building_type])

func _cancel_building_placement():
	is_placing_building = false
	building_to_place = ""
	building_placement_build_more = false  # Reset build more mode
	
	# Clean up preview sprites
	if building_preview_sprite:
		building_preview_sprite.queue_free()
		building_preview_sprite = null
	
	DebugConfig.dprint("buildings", ["Game: Cancelled building placement mode"])

func _update_building_hover(_mouse_pos: Vector2):
	# Convert screen position to world position
	var world_pos = camera.get_global_mouse_position()
	var building = _get_building_at_position(world_pos)
	
	# Update highlighting
	if highlighted_building != building:
		_clear_building_highlight()
		if building:
			_highlight_building(building)
		highlighted_building = building

func _try_select_building(_mouse_pos: Vector2):
	# Convert screen position to world position
	var world_pos = camera.get_global_mouse_position()
	var building = _get_building_at_position(world_pos)
	
	if building:
		_select_building(building)
	else:
		# Only clear selection if building details modal is not open
		# This prevents losing connection lines when clicking empty tiles
		if not building_details_modal or not is_instance_valid(building_details_modal):
			_clear_building_selection()

func _get_building_at_position(world_pos: Vector2) -> Node2D:
	if not map_objects_holder:
		return null
	
	# Check all buildings to see if mouse is over them
	for child in map_objects_holder.get_children():
		if _is_building_node(child):
			# Get building sprite bounds
			var sprite_node = null
			if child.has_node("Sprite2D"):
				sprite_node = child.get_node("Sprite2D")
			
			if sprite_node and sprite_node.texture:
				var building_pos = child.position
				var sprite_offset = sprite_node.position
				var texture_size = sprite_node.texture.get_size()
				
				# Calculate actual sprite bounds
				var sprite_world_pos = building_pos + sprite_offset
				var half_size = texture_size / 2.0
				var bounds = Rect2(sprite_world_pos - half_size, texture_size)
				
				if bounds.has_point(world_pos):
					return child
	
	return null

func _highlight_building(building: Node2D):
	if building and building.has_node("Sprite2D"):
		var sprite = building.get_node("Sprite2D")
		sprite.modulate = Color(1.2, 1.2, 1.0, 1.0)  # Slight yellow tint

func _clear_building_highlight():
	if highlighted_building and highlighted_building.has_node("Sprite2D"):
		var sprite = highlighted_building.get_node("Sprite2D")
		sprite.modulate = Color.WHITE

func _select_building(building: Node2D):
	# Enemy buildings (owner_player >= 1000) open the combat modal instead.
	var owner = building.get_meta("owner_player", 1)
	if owner >= 1000:
		_open_combat_modal(building)
		return

	_clear_building_selection()
	selected_building = building
	
	# Add selection indicator (stronger highlight)
	if building.has_node("Sprite2D"):
		var sprite = building.get_node("Sprite2D")
		sprite.modulate = Color(1.0, 1.5, 1.0, 1.0)  # Green tint for selection
	
	# Open building details modal
	_open_building_details_modal(building)

func _clear_building_selection():
	if selected_building and selected_building.has_node("Sprite2D"):
		var sprite = selected_building.get_node("Sprite2D")
		sprite.modulate = Color.WHITE
	
	# Clear connection lines if building details modal exists
	if building_details_modal and building_details_modal.has_method("clear_all_connections"):
		building_details_modal.clear_all_connections()
	
	selected_building = null

func _open_building_details_modal(building: Node2D):
	# Close and cleanup existing modal if open
	if building_details_modal:
		DebugConfig.dprint("buildings", ["Game: Closing old building details modal before opening new one"])
		building_details_modal.close_modal()  # This clears lines and unregisters from stack
		building_details_modal.queue_free()
	
	# Create new building details modal properly
	var BuildingDetailsModalScript = preload("res://scripts/ui/building_details_modal.gd")
	building_details_modal = BuildingDetailsModalScript.new()
	
	DebugConfig.dprint("buildings", ["Game: Created building details modal: ", building_details_modal])
	
	# Add to UI layer first so it can get proper positioning
	ui_layer.add_child(building_details_modal)
	
	DebugConfig.dprint("buildings", ["Game: Added modal to UI layer, calling setup..."])
	
	# Then setup the building details
	building_details_modal.setup_building_details(building)
	
	# Connect close signal
	building_details_modal.close_requested.connect(_on_building_details_closed)
	
	# Connect demolish signal
	building_details_modal.demolish_confirmed.connect(_on_building_demolish_confirmed)
	
	DebugConfig.dprint("buildings", ["Game: Building details modal setup complete"])

func _on_building_details_closed():
	# Clean up building selection and free the modal
	_clear_building_selection()
	if building_details_modal and is_instance_valid(building_details_modal):
		building_details_modal.queue_free()
	building_details_modal = null

func _on_building_demolish_confirmed(building_data_to_delete: Dictionary):
	DebugConfig.dprint("buildings", ["Game: Demolishing building: ", building_data_to_delete])
	
	# Find the building node to delete
	var building_name = building_data_to_delete.get("name", "")
	if building_name == "":
		DebugConfig.dprint("buildings", ["Error: No building name provided for demolish"])
		return
	
	# Find building in the map objects holder
	if not map_objects_holder:
		DebugConfig.dprint("buildings", ["Error: MapObjects holder not found"])
		return
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(building_name))
	if not building_node:
		DebugConfig.dprint("buildings", ["Error: Building node not found: ", building_name])
		return
	
	# Update population counts before deletion
	var _building_type = building_data_to_delete.get("building_type", "")
	var living_occupancy = building_data_to_delete.get("living_occupancy", 0)
	var worker_occupancy = building_data_to_delete.get("worker_occupancy", 0)
	var owner_player = building_node.get_meta("owner_player", 1)
	
	# Remove unit assignments for this building before demolishing
	_remove_unit_assignments_for_building(building_name, owner_player)
	
	# Reduce occupancy to 0 before deletion to update population counts
	if living_occupancy > 0:
		update_building_occupancy(building_node, "living", 0)
	if worker_occupancy > 0:
		update_building_occupancy(building_node, "working", 0)
	
	# Remove building from game
	building_node.queue_free()
	
	# Check for game over: did the player just lose their last town centre?
	var building_type = _extract_building_type_from_name(building_name)
	if building_type == "town_center":
		_check_town_centre_game_over(owner_player, building_name)
	
	# TODO: Return some resources to player based on building type
	# Could return 50% of building cost or similar
	
	DebugConfig.dprint("buildings", ["Game: Building demolished successfully: ", building_name])
	
	# Clear selection and close modal (modal should already be closed by demolish handler)
	_clear_building_selection()

func _check_town_centre_game_over(player_id: int, demolished_building_name: String = ""):
	"""Trigger game over if the given player has no town_centre buildings remaining."""
	if not map_objects_holder:
		return
	# Check if any town_center node belonging to this player still exists
	# (skip the just-demolished node which may still be in the tree pending queue_free)
	for child in map_objects_holder.get_children():
		if child.name == demolished_building_name:
			continue  # Skip the node being freed
		if not _is_building_node(child):
			continue
		if child.get_meta("owner_player", 1) != player_id:
			continue
		if _extract_building_type_from_name(child.name) == "town_center":
			return  # Still has at least one — no game over
	# No town centres left — show game over
	DebugConfig.dprint("buildings", ["Game: Player ", player_id, " has no town centres remaining — GAME OVER"])
	_trigger_game_over()

func _trigger_game_over():
	"""Show the game over screen. Call this for any loss condition (town centre destroyed, forfeit, etc.)."""
	if is_instance_valid(game_over_modal):
		game_over_modal.show_game_over()

func _get_wave_state_for_save() -> Dictionary:
	if is_instance_valid(wave_spawner):
		return {"wave_number": wave_spawner.wave_number, "next_wave_day": wave_spawner.next_wave_day}
	return {"wave_number": 0, "next_wave_day": 28}

func _unhandled_input(event: InputEvent):
	# Handle debug console toggle
	if event.is_action_pressed("debug_console"):
		if is_instance_valid(console_modal):
			console_modal.toggle_console()
		get_viewport().set_input_as_handled()
		return
	
	# Debug key for building info
	if event.is_action_pressed("ui_accept") and Input.is_action_pressed("ui_cancel"):
		debug_print_all_buildings()
		get_viewport().set_input_as_handled()
		return
	
	# Handle building placement mode first
	if is_placing_building:
		if event is InputEventMouseMotion:
			_update_building_preview(event.position)
		elif event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_try_place_building(event.position)
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_building_placement()
		return
	
	if is_in_world_creation:
		# During world creation, use camera controller for all input
		if is_instance_valid(camera_controller):
			camera_controller.handle_input(event, false)  # Not paused during world creation
		get_viewport().set_input_as_handled()
		return
		
	# Normal game input handling
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(ui_manager): ui_manager.handle_escape()
		get_viewport().set_input_as_handled(); return
	
	# Handle building selection
	if event is InputEventMouseMotion:
		_update_building_hover(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_select_building(event.position)

	if is_instance_valid(camera_controller):
		camera_controller.handle_input(event, get_tree().paused)

func _ready():
	DebugConfig.dprint("general", ["game.gd: _ready started."])
	# --- Node Validation ---
	# ... (Keep validation) ...
	if not is_instance_valid(camera_controller) or not is_instance_valid(ui_manager) \
	or not is_instance_valid(map_object_manager) or not is_instance_valid(turn_manager):
		push_error("Game: Manager nodes not found!"); get_tree().quit(); return
	if SaveLoadManager == null:
		push_error("Game: SaveLoadManager Autoload not found!"); get_tree().quit(); return


# --- Calculate Map Bounds ---
	var map_pixel_width = 0
	var map_pixel_height = 0
	DebugConfig.dprint("general", ["Game: Checking TileSet..."]) # Debug Print
	if is_instance_valid(tilemap_layer) and is_instance_valid(tilemap_layer.tile_set):
		var tile_size = tilemap_layer.tile_set.tile_size
		DebugConfig.dprint("general", ["Game: Found TileSet, Tile Size: ", tile_size]) # Debug Print
		if tile_size.x > 0 and tile_size.y > 0:
			map_pixel_width = MAP_WIDTH * tile_size.x
			map_pixel_height = MAP_HEIGHT * tile_size.y
			DebugConfig.dprint("general", ["Game: Calculated map pixel dimensions: %d x %d" % [map_pixel_width, map_pixel_height]]) # Debug Print
		else:
			push_error("Game: TileSet has invalid tile_size (<= 0): %s" % str(tile_size))
			# Stop execution potentially? Or default sizes? For now, error is enough.
	else:
		# This case covers both invalid tilemap_layer and missing tile_set
		if not is_instance_valid(tilemap_layer):
			# This shouldn't happen if previous validation passed, but good to check
			push_error("Game: Cannot calculate bounds, tilemap_layer node is invalid!")
		else:
			# This is the more likely error cause if validation passed
			push_error("Game: Cannot calculate bounds, TileMapLayer node is missing its TileSet resource!")
			push_error("Game: Please assign a TileSet resource to the TileMapLayer node in the editor Inspector.")
		# Consider quitting if bounds calculation fails, as it's critical
		# get_tree().quit()
		return # Stop further execution in _ready if bounds failed

	# --- Setup Managers ---
	DebugConfig.dprint("general", ["Game: Setting up CameraController..."])
	camera_controller.setup(camera, map_pixel_width, map_pixel_height)

	DebugConfig.dprint("general", ["Game: Setting up UIManager..."])
	var ui_nodes = { # Verify these paths carefully!
		"modal_menu_panel": $UI_Layer/ModalMenuPanel,
		"world_creation_panel": $UI_Layer/WorldCreationPanel,
		"load_button": $UI_Layer/ModalMenuPanel/ModalButtonsVBox/LoadButton,
		"confirmation_panel": $UI_Layer/ConfirmationPanel,
		"confirmation_label": $UI_Layer/ConfirmationPanel/VBoxContainer/ConfirmationLabel,
		"confirm_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmSaveButton,
		"confirm_no_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmNoSaveButton,
		"confirm_cancel_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmCancelButton,
	}
	ui_manager.setup(ui_nodes)
	# Store ui_manager reference for modals to access
	set_meta("ui_manager", ui_manager)

	DebugConfig.dprint("general", ["Game: Setting up MapObjectManager..."])
	var forest_coords = Vector2i(0, 4); var mountain_coords = Vector2i(0, 3); var ocean_coords = Vector2i(0, 2) # Corrected coords
	DebugConfig.dprint("general", ["Game: fish_scene before setup = %s" % fish_scene])
	
	# Fallback: if fish_scene is not assigned, load it
	if not fish_scene:
		fish_scene = preload("res://scenes/objects/fish.tscn")
		DebugConfig.dprint("general", ["Game: Fish scene was null, loaded via preload: %s" % fish_scene])
	
	map_object_manager.setup(map_objects_holder, tilemap_layer, tree_scene, mountain_scene, forest_coords, mountain_coords, self, fish_scene, ocean_coords)
	DebugConfig.dprint("general", ["Game: map_object_manager.fish_scene after setup = %s" % map_object_manager.fish_scene])

	DebugConfig.dprint("general", ["Game: Setting up TurnManager..."])
	var day_label = $UI_Layer/TurnControlsContainer/TurnVBox/DayCounterLabel
	if not is_instance_valid(day_label): push_error("Game: Day counter label node not found!")
	turn_manager.setup(day_label)

	DebugConfig.dprint("general", ["Game: Setting up WaveSpawner..."])
	var WaveSpawnerScript = preload("res://scripts/managers/wave_spawner.gd")
	wave_spawner = WaveSpawnerScript.new()
	wave_spawner.name = "WaveSpawner"
	add_child(wave_spawner)
	wave_spawner.setup(self)
	# Connect wave signal so we can fire a turn event when a wave spawns
	wave_spawner.wave_spawned.connect(_on_wave_spawned)

	DebugConfig.dprint("general", ["Game: Setting up TurnEventManager..."])
	var TurnEventManagerScript = preload("res://scripts/managers/turn_event_manager.gd")
	turn_event_manager = TurnEventManagerScript.new()
	turn_event_manager.name = "TurnEventManager"
	add_child(turn_event_manager)

	DebugConfig.dprint("general", ["Game: Setting up GameLog..."])
	var GameLogScript = preload("res://scripts/managers/game_log.gd")
	game_log = GameLogScript.new()
	game_log.name = "GameLog"
	add_child(game_log)
	
	# Load preview textures for building placement
	# Create simple colored rectangles for overlays since we don't have overlay assets
	DebugConfig.dprint("general", ["Game: Setting up building placement preview system"])


	# --- Connect Signals ---
	DebugConfig.dprint("general", ["Game: Connecting signals..."])
	# Connect UI buttons to UIManager requests / TurnManager
	# Using get_node for safety in case @onready vars haven't resolved (unlikely but safe)

	var return_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/ReturnButton")
	if return_btn: return_btn.pressed.connect(ui_manager.close_main_modal)
	else: push_error("Game: ReturnButton not found for connection.")

	# Add connections for SettingsButton if needed, connecting to a UIManager function

	var save_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/SaveButton")
	if save_btn: save_btn.pressed.connect(_on_save_requested) # Calls local wrapper
	else: push_error("Game: SaveButton not found for connection.")

	# Add connection for LoadButton (simple version)
	var load_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/LoadButton")
	if load_btn: load_btn.pressed.connect(_on_load_pressed) # Calls local simple load
	else: push_error("Game: LoadButton not found for connection.")

	var main_menu_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/MainMenuButton")
	if main_menu_btn: main_menu_btn.pressed.connect(ui_manager.request_main_menu)
	else: push_error("Game: MainMenuButton not found for connection.")

	var quit_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/QuitButton")
	if quit_btn: quit_btn.pressed.connect(ui_manager.request_quit)
	else: push_error("Game: QuitButton not found for connection.")

	# End day button connection removed - now in resources modal footer


	# --- DEBUG: Connect signals *from* UIManager back to game.gd ---
	DebugConfig.dprint("general", ["Game: Connecting signals FROM UIManager..."])
	if is_instance_valid(ui_manager):
		if not ui_manager.is_connected("save_requested", Callable(self, "_on_save_requested_from_ui")):
			var err_save_req = ui_manager.save_requested.connect(_on_save_requested_from_ui)
			if err_save_req == OK: DebugConfig.dprint("general", ["Game: Connected ui_manager.save_requested to _on_save_requested_from_ui"])
			else: push_error("Game: FAILED to connect ui_manager.save_requested. Error: %d" % err_save_req)
		else: DebugConfig.dprint("general", ["Game: ui_manager.save_requested ALREADY connected."])

		if not ui_manager.is_connected("action_confirmed", Callable(self, "_on_action_confirmed_from_ui")):
			var err_action_conf = ui_manager.action_confirmed.connect(_on_action_confirmed_from_ui)
			if err_action_conf == OK: DebugConfig.dprint("general", ["Game: Connected ui_manager.action_confirmed to _on_action_confirmed_from_ui"])
			else: push_error("Game: FAILED to connect ui_manager.action_confirmed. Error: %d" % err_action_conf)
		else: DebugConfig.dprint("general", ["Game: ui_manager.action_confirmed ALREADY connected."])
	else:
		push_error("Game: Cannot connect UIManager signals, ui_manager node is invalid!")
	# --- END DEBUG ---

	DebugConfig.dprint("general", ["Game: Connecting signals complete."])

	# --- Setup Game Header ---
	_setup_game_header()

	# Hide the legacy TurnControlsContainer from the scene — the GameFooter replaces it.
	var turn_controls = get_node_or_null("UI_Layer/TurnControlsContainer")
	if turn_controls:
		turn_controls.hide()

	# --- Load Name System ---
	_load_race_names()
	_load_building_work_names()

	# --- Initialize Map ---
	initialize_map()
	DebugConfig.dprint("general", ["game.gd: _ready finished."])


func _process(delta: float):
	if is_instance_valid(camera_controller):
		camera_controller.process_movement(delta, get_tree().paused)
	
	# Update unit movements
	_update_unit_movements(delta)


# --- Map Initialization ---
func initialize_map():
	DebugConfig.dprint("general", ["Game: Initializing Map..."]); DebugConfig.dprint("general", ["Game: Start Mode: %s" % GameManager.start_mode])
	var success = false; var loaded_day = 1
	
	if GameManager.start_mode == "world_creation":
		DebugConfig.dprint("general", ["Game: Mode: World Creation"])
		_start_world_creation_mode()
		return  # Don't proceed with normal map initialization
	elif GameManager.start_mode == "new":
		DebugConfig.dprint("general", ["Game: Mode: New Game"]); current_save_path = ""
		unit_counter = 0  # Reset unit counter for new games
		if generate_world_data(): 
			success = true
			# Initialize population data for new games
			_migrate_players_data_structure()
			# Create initial units based on population total
			_create_initial_units_from_population()
		else: push_error("Game: Failed to generate world data.")
	elif GameManager.start_mode == "new_with_data":
		DebugConfig.dprint("general", ["Game: Mode: New Game with Generated Data"])
		current_save_path = ""
		unit_counter = 0  # Reset unit counter for new games
		if not GameManager.generated_world_data.is_empty():
			world_data = GameManager.generated_world_data.duplicate()
			GameManager.generated_world_data.clear()  # Clear it after use
			success = true
			# Initialize population data for new games
			_migrate_players_data_structure()
		else:
			push_error("Game: Generated world data is empty, falling back to normal generation")
			if generate_world_data(): 
				success = true
				# Initialize population data for new games
				_migrate_players_data_structure()
	elif GameManager.start_mode == "load":
		DebugConfig.dprint("general", ["Game: Mode: Load Game from Path: ", GameManager.load_file_path])
		if GameManager.load_file_path.is_empty(): push_error("Game: Load mode selected but no load_file_path provided! Starting new game."); GameManager.start_mode = "new"; initialize_map(); return
		else:
			var loaded_state = SaveLoadManager.load_game(GameManager.load_file_path)
			if not loaded_state.is_empty():
				world_data = loaded_state["map_data"]; loaded_day = loaded_state["current_day"]
				current_save_path = loaded_state["current_save_path"]; success = true
				# Store buildings data for restoration after map is drawn
				if loaded_state.has("buildings_data"):
					loaded_buildings_data = loaded_state["buildings_data"]
				# Store environment objects data for restoration
				if loaded_state.has("environment_objects_data"):
					loaded_environment_objects_data = loaded_state["environment_objects_data"]
				# Restore player data if available
				if loaded_state.has("players_data"):
					players_data = loaded_state["players_data"]
					# Migrate old save files to include environment player
					_migrate_players_data_structure()
					# Update unit_counter based on existing units so new units get correct IDs
					_update_unit_counter_from_existing_units()
					# Don't create new units - they should already exist in the save file with assignments
					# Sprite restoration will happen after buildings are restored
					DebugConfig.dprint("general", ["Game: Restored player data for ", players_data.size(), " players"])
				# Restore wave spawner state
				if loaded_state.has("wave_state") and is_instance_valid(wave_spawner):
					wave_spawner.wave_number = loaded_state["wave_state"].get("wave_number", 0)
					wave_spawner.next_wave_day = loaded_state["wave_state"].get("next_wave_day", wave_spawner.WAVE_INTERVAL)
					DebugConfig.dprint("general", ["Game: Restored wave state — wave %d, next wave day %d" % [wave_spawner.wave_number, wave_spawner.next_wave_day]])
				# Restore game log entries
				if loaded_state.has("log_entries") and is_instance_valid(game_log):
					game_log.entries = loaded_state["log_entries"].duplicate()
					DebugConfig.dprint("general", ["Game: Restored %d log entries" % game_log.entries.size()])
			else: push_error("Game: Failed to load state from %s. Starting new game." % GameManager.load_file_path); GameManager.start_mode = "new"; initialize_map(); return
	else: push_error("Game: Invalid start mode: %s. Starting new game." % GameManager.start_mode); GameManager.start_mode = "new"; initialize_map(); return
	if success:
		DebugConfig.dprint("general", ["Game: Map state ready. Updating managers..."])
		# Reset environment data for new games (not loaded games)
		if GameManager.start_mode == "new" or loaded_environment_objects_data.is_empty():
			_reset_environment_data()
		
		turn_manager.set_day(loaded_day); _clear_and_draw_map(); map_object_manager.clear_objects()
		# Update footer to display loaded day
		if game_footer:
			game_footer.set_day_text(loaded_day)
		# Only place fresh environment objects for new games.
		# On load, objects are restored from save data below.
		if loaded_environment_objects_data.is_empty():
			map_object_manager.place_objects(world_data)
			map_object_manager.place_fish(world_data)
		# Restore buildings if loading from save
		if not loaded_buildings_data.is_empty():
			_restore_buildings_with_proper_centering(loaded_buildings_data)
			_auto_assign_jobs_on_load()  # Auto-assign units to jobs based on occupancy
			loaded_buildings_data = []  # Clear after restoration
		
		# Restore environment objects if loading from save
		if not loaded_environment_objects_data.is_empty():
			_restore_environment_objects(loaded_environment_objects_data)
			loaded_environment_objects_data = []  # Clear after restoration
		else:
			DebugConfig.dprint("general", ["Game: No environment objects to restore (new game or empty save)"])
		
		# Migrate any old building names to new system
		migrate_old_building_names()
		
		# Create initial units (cosmetic)
		_create_initial_units()
		
		# Update population data after units are created
		for player_id in players_data.keys():
			if str(player_id) != "environment":
				update_player_population(player_id)
		
		# CRITICAL: Ensure unit sprites are restored after buildings
		# This is especially important for loaded games where units exist but have no sprites yet
		if GameManager.start_mode == "load":
			call_deferred("_restore_unit_sprites_on_load")
			DebugConfig.dprint("general", ["Game: Queued unit sprite restoration for loaded game"])
		
		camera_controller.center_camera()
		# Refresh resource bar with loaded data
		if resource_bar:
			resource_bar.refresh()
		DebugConfig.dprint("general", ["Game: Map ready."])
	else: DebugConfig.dprint("general", ["Game: Map initialization failed."])
	DebugConfig.dprint("general", ["Game: --- Map Initialization Finished ---"])


# --- World Creation Functions ---

func _reset_environment_data():
	# Reset environment object tracking for new games
	DebugConfig.dprint("map_objects", ["Game: Resetting environment data for new game"])
	players_data["environment"] = {
		"name": "Environment",
		"type": "environment",
		"objects": {
			"mountains": {},
			"trees": {}
		},
		"counts": {
			"mountains": 0,
			"trees": 0
		}
	}
	# Also clear any lingering loaded data
	loaded_environment_objects_data = []
	# Reset unit counter for fresh IDs
	unit_counter = 0

func _fix_duplicate_unit_ids():
	"""Check for and fix duplicate unit IDs in player data"""
	var all_unit_ids = {}  # Track all unit IDs and their occurrences
	var duplicates_found = 0
	
	for player_id in players_data.keys():
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		if not player_data.has("units"):
			continue
		
		var player_units = player_data.get("units", [])
		
		for unit in player_units:
			var unit_id = unit.get("unique_id", "")
			if unit_id == "":
				continue
			
			# Track this unit ID
			if unit_id not in all_unit_ids:
				all_unit_ids[unit_id] = []
			all_unit_ids[unit_id].append({"unit": unit, "player_id": player_id})
	
	# Now check for duplicates and fix them
	for unit_id in all_unit_ids.keys():
		var occurrences = all_unit_ids[unit_id]
		
		if occurrences.size() > 1:
			DebugConfig.dprint("save_load", ["Game: Found %d units with duplicate ID: %s" % [occurrences.size(), unit_id]])
			duplicates_found += occurrences.size() - 1  # Count extras
			
			# Keep the first one, reassign the others
			for i in range(1, occurrences.size()):
				var duplicate_unit = occurrences[i]["unit"]
				var old_id = duplicate_unit["unique_id"]
				var new_id = _get_next_unit_id()
				
				duplicate_unit["unique_id"] = new_id
				DebugConfig.dprint("save_load", ["Game: Fixed duplicate unit - reassigned %s -> %s (name: %s)" % [old_id, new_id, duplicate_unit.get("name", "Unknown")]])
	
	if duplicates_found > 0:
		DebugConfig.dprint("save_load", ["Game: Fixed %d duplicate unit IDs" % duplicates_found])
	else:
		DebugConfig.dprint("save_load", ["Game: No duplicate unit IDs found"])

func _create_initial_units():
	"""Create initial unit population for new games, or restore sprites for loaded games"""
	
	if GameManager.start_mode == "new" or GameManager.start_mode == "new_with_data":
		# NEW GAME: Create 10 units per player upfront
		DebugConfig.dprint("population", ["Game: Creating initial unit population for new game"])
		for player_id in players_data.keys():
			if str(player_id) == "environment":
				continue
			
			# Create 10 units per player
			for i in range(10):
				var unit_id = _get_next_unit_id()
				var player_race = players_data[player_id].get("race", "human")
				var gender = ["male", "female"][randi() % 2]  # Randomly choose male or female
				var unit_data = {
					"unique_id": unit_id,
					"name": _generate_random_name(player_race, gender),
					"type": "peasant",
					"race": player_race,
					"gender": gender,
					"player_id": player_id,
					"position": Vector2.ZERO,  # Will be updated when assigned housing
					"living_quarters": null,
					"job": null,
					"assigned_job_index": -1,
					"previous_job": null,
					"job_connections": [],
					# Movement properties
					"current_path": [],
					"path_index": 0,
					"movement_state": "idle",
					"movement_target": null,
					"movement_cycle_step": 0,
					"work_timer": 0.0,
					"movement_speed": 25.0,
					"speed_multiplier": randf_range(0.85, 1.15),
					"sprite_id": "",
					# Training system
					"specialties": [],
					"training": null
				}
				
				if not players_data[player_id].has("units"):
					players_data[player_id]["units"] = []
				
				players_data[player_id]["units"].append(unit_data)
		
		DebugConfig.dprint("population", ["Game: Created 10 units per player for new game"])
		
		# ── Spawn the player's named pet ──────────────────────────────────────
		var pet_name: String = world_data.get("player_data", {}).get("pet_name", "Wilson")
		if pet_name.strip_edges().is_empty():
			pet_name = "Wilson"
		var pet_type: String = world_data.get("player_data", {}).get("pet_type", "cat")
		var pet_id: String = _get_next_unit_id()
		var pet_race: String = players_data.get(1, {}).get("race", "human")
		var pet_data: Dictionary = {
			"unique_id": pet_id,
			"name": pet_name,
			"type": "peasant",
			"is_pet": true,
			"pet_type": pet_type,
			"race": pet_race,
			"gender": "male",
			"player_id": 1,
			"position": Vector2.ZERO,
			"living_quarters": null,
			"job": null,
			"assigned_job_index": -1,
			"previous_job": null,
			"job_connections": [],
			"current_path": [],
			"path_index": 0,
			"movement_state": "idle_wander",
			"movement_target": null,
			"movement_cycle_step": 0,
			"work_timer": 0.0,
			"movement_speed": 20.0,
			"speed_multiplier": 0.9,
			"sprite_id": "",
			"specialties": [],
			"training": null,
			"pet_cooldown_day": 0
		}
		if not players_data[1].has("units"):
			players_data[1]["units"] = []
		players_data[1]["units"].append(pet_data)
		DebugConfig.dprint("population", ["Game: Spawned pet '%s' (id=%s)" % [pet_name, pet_id]])
	else:
		DebugConfig.dprint("population", ["Game: Not a new game (mode: %s) - units loaded or will be restored from save" % GameManager.start_mode])
	
	# For both new and loaded games: restore sprites for units that meet conditions
	_restore_unit_sprites_on_load()

func _clear_existing_unit_sprites():
	"""Clear any existing unit sprites before restoration"""
	if not map_objects_holder:
		return
	
	# Remove any existing unit sprites (nodes with unit_X names)
	for child in map_objects_holder.get_children():
		if child.name.begins_with("unit_"):
			DebugConfig.dprint("general", ["Removing existing unit sprite: ", child.name])
			child.queue_free()

func _restore_unit_sprites_on_load():
	"""Restore unit sprites for loaded units that have both living and job assignments"""
	
	# Ensure map_objects_holder exists
	if not map_objects_holder:
		await get_tree().process_frame
		call_deferred("_restore_unit_sprites_on_load")
		return
	
	var sprites_created = 0
	var units_checked = 0
	var units_with_assignments = 0
	var units_without_sprites = 0
	var units_already_have_sprites = 0
	
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		if not player_data.has("units"):
			continue
		
		for unit in player_data["units"]:
			units_checked += 1
			var living_quarters = unit.get("living_quarters", null)
			var job = unit.get("job", null)
			
			if living_quarters != null and job != null:
				units_with_assignments += 1
			
			# All units get a sprite, regardless of assignment status
			var unit_id = unit["unique_id"]
			var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
			
			if not existing_sprite:
				units_without_sprites += 1
				# Ensure unassigned units default to idle_wander so they walk near town centre
				if living_quarters == null or job == null:
					_ensure_unit_movement_properties(unit)
					unit["movement_state"] = "idle_wander"
				_create_unit_sprite_and_start_cycle(unit)
				sprites_created += 1
			else:
				units_already_have_sprites += 1
	
	DebugConfig.dprint("save_load", ["Unit sprite restoration complete: %d created, %d checked, %d with assignments, %d without sprites, %d already had sprites" % [sprites_created, units_checked, units_with_assignments, units_without_sprites, units_already_have_sprites]])

func _ensure_unit_movement_properties(unit: Dictionary):
	"""Ensure unit has all required movement properties for backward compatibility"""
	if not unit.has("current_path"):
		unit["current_path"] = []
	if not unit.has("path_index"):
		unit["path_index"] = 0
	if not unit.has("movement_state"):
		# Default unassigned units to idle_wander so they walk near town centre
		var has_job = unit.get("job", null) != null
		var has_home = unit.get("living_quarters", null) != null
		unit["movement_state"] = "idle" if (has_job and has_home) else "idle_wander"
	if not unit.has("movement_target"):
		unit["movement_target"] = null
	if not unit.has("movement_cycle_step"):
		unit["movement_cycle_step"] = 0
	if not unit.has("work_timer"):
		unit["work_timer"] = 0.0
	if not unit.has("wander_wait_time"):
		unit["wander_wait_time"] = randf_range(1.0, 4.0)
	if not unit.has("movement_speed"):
		unit["movement_speed"] = 25.0
	if not unit.has("speed_multiplier"):
		unit["speed_multiplier"] = randf_range(0.85, 1.15)  # Random speed variation for older saves
	if not unit.has("specialties"):
		unit["specialties"] = []
	if not unit.has("training"):
		unit["training"] = null
	
func _spawn_unit(unit_data: Dictionary):
	# Only create sprite if both living_quarters and job are assigned
	var living_quarters = unit_data.get("living_quarters", null)
	var job = unit_data.get("job", null)
	
	if living_quarters != null and job != null:
		# Create unit sprite
		var unit_sprite = Sprite2D.new()
		unit_sprite.name = unit_data["unique_id"]  # Use unique_id for node name
		unit_sprite.position = unit_data["position"]
		unit_sprite.z_index = 6  # Above buildings but below UI
		unit_sprite.scale = _get_unit_sprite_scale(unit_data)
		
	# Load appropriate texture based on race and type
		var texture_path = _get_pet_sprite_path(unit_data.get("pet_type", "cat")) if unit_data.get("is_pet", false) else _get_unit_sprite_path(unit_data.get("race", "human"), unit_data.get("gender", "male"), unit_data.get("type", "peasant"))
		if ResourceLoader.exists(texture_path):
			unit_sprite.texture = load(texture_path)
		else:
			DebugConfig.dprint("population", ["Warning: Unit texture not found: ", texture_path])
		
		# Add to map objects holder
		map_objects_holder.add_child(unit_sprite)
		DebugConfig.dprint("population", ["Game: Spawned unit sprite: ", unit_data["unique_id"], " (both living and job assigned)"])
	else:
		DebugConfig.dprint("population", ["Game: Unit created but no sprite (missing living or job assignment): ", unit_data["unique_id"]])
	
	# Store unit in player data
	var player_id = unit_data.get("player_id", 1)
	if players_data.has(player_id) and not players_data[player_id].has("units"):
		players_data[player_id]["units"] = []
	if players_data.has(player_id):
		players_data[player_id]["units"].append(unit_data)
	
	DebugConfig.dprint("population", ["Game: Spawned unit: ", unit_data["unique_id"], " (", unit_data["name"], ") at ", unit_data["position"]])

func _get_next_unit_id() -> String:
	# Generate unique unit ID
	unit_counter += 1
	return "unit_" + str(unit_counter)

# ── Event-driven population helpers ─────────────────────────────────────────

func add_event_units(player_id: int, count: int):
	"""Spawn `count` new unassigned wandering units for a player (used by world events)."""
	if not players_data.has(player_id):
		return
	if not players_data[player_id].has("units"):
		players_data[player_id]["units"] = []
	var player_race: String = players_data[player_id].get("race", "human")
	var anchor: Vector2 = _get_player_town_centre_position(player_id)
	for _i in range(count):
		var uid: String = _get_next_unit_id()
		var gender: String = ["male", "female"][randi() % 2]
		var scatter_angle: float = randf() * TAU
		var scatter_dist: float = randf_range(20.0, 60.0)
		var spawn_pos: Vector2 = anchor + Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_dist
		var unit_data: Dictionary = {
			"unique_id": uid,
			"name": _generate_random_name(player_race, gender),
			"type": "peasant",
			"race": player_race,
			"gender": gender,
			"player_id": player_id,
			"position": spawn_pos,
			"living_quarters": null,
			"job": null,
			"assigned_job_index": -1,
			"previous_job": null,
			"job_connections": [],
			"current_path": [],
			"path_index": 0,
			"movement_state": "idle_wander",
			"movement_target": null,
			"movement_cycle_step": 0,
			"work_timer": randf_range(0.0, 3.0),
			"wander_wait_time": randf_range(1.0, 4.0),
			"movement_speed": 25.0,
			"speed_multiplier": randf_range(0.85, 1.15),
			"sprite_id": uid,
			"specialties": [],
			"training": null
		}
		players_data[player_id]["units"].append(unit_data)
		# Build sprite directly (bypass _create_unit_sprite_and_start_cycle which forces idle state)
		_spawn_event_unit_sprite(unit_data)
		DebugConfig.dprint("general", ["Game: Event added unit %s (%s) for player %d" % [uid, unit_data["name"], player_id]])
	# Try to house the new arrivals in any spare capacity
	_auto_assign_all_units_to_housing()
	# Recalculate housing/employment counts (new units are unemployed until auto-assigned to a job)
	update_player_population(player_id)
	if is_instance_valid(resource_bar):
		resource_bar.refresh()
	# Update population current count to reflect actual unit list size
	var pop = players_data[player_id].get("population", {})
	pop["current"] = players_data[player_id]["units"].size()
	players_data[player_id]["population"] = pop

func remove_event_units(player_id: int, count: int):
	"""Remove `count` units from a player (prefer unassigned first), used by world events."""
	if not players_data.has(player_id):
		return
	var player_units: Array = players_data[player_id].get("units", [])
	if player_units.is_empty():
		return
	# Sort: remove unassigned units first, then assigned ones
	var unassigned: Array = []
	var assigned: Array = []
	for u in player_units:
		if u.get("living_quarters") == null or u.get("job") == null:
			unassigned.append(u)
		else:
			assigned.append(u)
	var removal_order: Array = unassigned + assigned
	var removed: int = 0
	for unit in removal_order:
		if removed >= count:
			break
		# Remove sprite
		var uid: String = unit.get("unique_id", "")
		if uid != "" and is_instance_valid(map_objects_holder):
			var sprite = map_objects_holder.get_node_or_null(uid)
			if is_instance_valid(sprite):
				sprite.queue_free()
			var clickable = map_objects_holder.get_node_or_null(uid + "_clickable")
			if is_instance_valid(clickable):
				clickable.queue_free()
		player_units.erase(unit)
		removed += 1
		DebugConfig.dprint("general", ["Game: Event removed unit %s (%s) for player %d" % [uid, unit.get("name", "?"), player_id]])
	players_data[player_id]["units"] = player_units
	# Recalculate current from actual array size
	var pop = players_data[player_id].get("population", {})
	pop["current"] = player_units.size()
	players_data[player_id]["population"] = pop
	# Refresh housing/employment counts and bar
	update_player_population(player_id)
	if is_instance_valid(resource_bar):
		resource_bar.refresh()

func _spawn_event_unit_sprite(unit: Dictionary):
	"""Create a visible, wandering sprite for an event-spawned unassigned unit."""
	if not is_instance_valid(map_objects_holder):
		return
	var uid: String = unit["unique_id"]
	if map_objects_holder.get_node_or_null(uid):
		return  # Already exists

	var unit_sprite = Sprite2D.new()
	unit_sprite.name = uid
	unit_sprite.position = unit["position"]
	unit_sprite.z_index = 6
	unit_sprite.centered = true
	unit_sprite.scale = _get_unit_sprite_scale(unit)

	var texture_path = _get_pet_sprite_path(unit.get("pet_type", "cat")) if unit.get("is_pet", false) else _get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"))
	if ResourceLoader.exists(texture_path):
		unit_sprite.texture = load(texture_path)
	else:
		var rect = ColorRect.new()
		rect.size = Vector2(16, 16)
		rect.color = Color.YELLOW
		unit_sprite.add_child(rect)

	unit_sprite.set_meta("unit_id", uid)
	unit_sprite.set_meta("unit_data", unit)

	var click_control = Control.new()
	click_control.name = uid + "_clickable"
	click_control.set_meta("unit_id", uid)
	click_control.set_meta("unit_data", unit)
	click_control.mouse_filter = Control.MOUSE_FILTER_PASS
	click_control.size = Vector2(40, 40)
	click_control.position = Vector2(-20, -20)
	click_control.gui_input.connect(_on_unit_control_gui_input.bindv([unit]))
	click_control.mouse_entered.connect(_on_unit_mouse_entered.bindv([unit]))
	click_control.mouse_exited.connect(_on_unit_mouse_exited.bindv([unit]))
	unit_sprite.add_child(click_control)

	map_objects_holder.add_child(unit_sprite)
	unit_sprite_map[uid] = unit_sprite
	unit["sprite_id"] = uid
	# Unit stays in idle_wander — movement process will pick it up automatically
	DebugConfig.dprint("general", ["Game: Event unit sprite spawned: %s at %s" % [uid, str(unit["position"])]])

func _update_unit_counter_from_existing_units():
	"""Update the unit_counter based on all existing units in players_data.
	Call this after loading a game to ensure new units get correct unique_ids."""
	var max_unit_num = 0
	
	# Scan all players' units to find the highest unit number
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		var player_data = players_data[player_id]
		if player_data.has("units"):
			for unit in player_data["units"]:
				var unit_id = unit.get("unique_id", "")
				if unit_id.begins_with("unit_"):
					var num_str = unit_id.trim_prefix("unit_")
					if num_str.is_valid_int():
						var num = num_str.to_int()
						max_unit_num = max(max_unit_num, num)
	
	# Set counter to the next number after the highest found
	unit_counter = max_unit_num
	DebugConfig.dprint("naming", ["Game: Updated unit_counter to %d (next unit will be unit_%d)" % [unit_counter, unit_counter + 1]])

func _load_race_names():
	"""Load name lists for each race from asset files"""
	DebugConfig.dprint("naming", ["Game: ===== STARTING NAME LOADING ====="])
	var races = ["human", "elf"]
	
	for race in races:
		race_names[race] = {"given": {"male": [], "female": []}, "surnames": []}
		
		# Load male given names
		var male_names_path = "res://assets/names/%ss/male_given_names.txt" % race
		DebugConfig.dprint("naming", ["Game: Attempting to load male given names from: %s" % male_names_path])
		
		var male_file = FileAccess.open(male_names_path, FileAccess.READ)
		if male_file:
			var content = male_file.get_as_text().strip_edges()
			var names_array = content.split("\n")
			# Filter out empty strings
			var filtered_names = []
			for name_item in names_array:
				var trimmed = name_item.strip_edges()
				if not trimmed.is_empty():
					filtered_names.append(trimmed)
			race_names[race]["given"]["male"] = filtered_names
			DebugConfig.dprint("naming", ["Game: Loaded %d male given names for %s" % [filtered_names.size(), race]])
		else:
			push_error("Game: Failed to open male given names file: %s" % male_names_path)
		
		# Load female given names
		var female_names_path = "res://assets/names/%ss/female_given_names.txt" % race
		DebugConfig.dprint("naming", ["Game: Attempting to load female given names from: %s" % female_names_path])
		
		var female_file = FileAccess.open(female_names_path, FileAccess.READ)
		if female_file:
			var content = female_file.get_as_text().strip_edges()
			var names_array = content.split("\n")
			# Filter out empty strings
			var filtered_names = []
			for name_item in names_array:
				var trimmed = name_item.strip_edges()
				if not trimmed.is_empty():
					filtered_names.append(trimmed)
			race_names[race]["given"]["female"] = filtered_names
			DebugConfig.dprint("naming", ["Game: Loaded %d female given names for %s" % [filtered_names.size(), race]])
		else:
			push_error("Game: Failed to open female given names file: %s" % female_names_path)
		
		# Load surnames - use direct file path without ResourceLoader
		var surnames_path = "res://assets/names/%ss/surnames.txt" % race
		DebugConfig.dprint("naming", ["Game: Attempting to load surnames from: %s" % surnames_path])
		
		var surnames_file = FileAccess.open(surnames_path, FileAccess.READ)
		if surnames_file:
			var content = surnames_file.get_as_text().strip_edges()
			DebugConfig.dprint("naming", ["Game: File content length for surnames: %d" % content.length()])
			var surnames_array = content.split("\n")
			# Filter out empty strings
			var filtered_surnames = []
			for surname in surnames_array:
				var trimmed = surname.strip_edges()
				if not trimmed.is_empty():
					filtered_surnames.append(trimmed)
			race_names[race]["surnames"] = filtered_surnames
			DebugConfig.dprint("naming", ["Game: Loaded %d surnames for %s (filtered from %d)" % [filtered_surnames.size(), race, surnames_array.size()]])
			if filtered_surnames.size() > 0:
				DebugConfig.dprint("naming", ["Game: First surname: %s, Last surname: %s" % [filtered_surnames[0], filtered_surnames[filtered_surnames.size()-1]]])
		else:
			push_error("Game: Failed to open surnames file: %s" % surnames_path)
			DebugConfig.dprint("naming", ["Game: FileAccess error: %d" % FileAccess.get_open_error()])
	
	DebugConfig.dprint("naming", ["Game: ===== NAME LOADING COMPLETE ====="])

func _generate_random_name(race: String, gender: String = "male") -> String:
	"""Generate a random name for a unit of the given race and gender"""
	if not race_names.has(race):
		push_error("Game: Race '%s' not found in race_names" % race)
		return "Unit " + str(unit_counter)
	
	if not race_names[race]["given"].has(gender):
		push_error("Game: Gender '%s' not found in given names for race '%s'" % [gender, race])
		return "Unit " + str(unit_counter)
	
	if race_names[race]["given"][gender].is_empty():
		push_error("Game: No %s given names loaded for race '%s'" % [gender, race])
		return "Unit " + str(unit_counter)
	
	if race_names[race]["surnames"].is_empty():
		push_error("Game: No surnames loaded for race '%s'" % race)
		return "Unit " + str(unit_counter)
	
	var given_names = race_names[race]["given"][gender]
	var surnames = race_names[race]["surnames"]
	
	var random_given = given_names[randi() % given_names.size()]
	var random_surname = surnames[randi() % surnames.size()]
	
	return random_given + " " + random_surname

func _get_unit_sprite_path(race: String, gender: String, type: String = "peasant") -> String:
	"""Get the sprite path for a unit based on race, gender, and type"""
	if type == "soldier":
		return "res://assets/units/human_soldier.png"
	if type == "scholar":
		return "res://assets/units/human_scholar.png"
	var gender_prefix = "female" if gender.to_lower() == "female" else "male"
	var race_prefix = race.to_lower()
	return "res://assets/units/%s_%s_peasant_side.png" % [race_prefix, gender_prefix]

func _get_pet_sprite_path(pet_type: String) -> String:
	"""Get the sprite path for the player's companion based on chosen pet type"""
	return "res://assets/units/dog_1.png" if pet_type == "dog" else "res://assets/units/wilson.png"

func _get_unit_sprite_scale(unit: Dictionary) -> Vector2:
	"""Per-texture scale correction — human_soldier.png/human_scholar.png are drawn at 2x the size of other unit sprites"""
	if unit.get("is_pet", false):
		return Vector2(0.25, 0.25)
	if unit.get("type", "peasant") in ["soldier", "scholar"]:
		return Vector2(0.5, 0.5)
	return Vector2.ONE

func _unit_sprite_is_reversed(unit: Dictionary) -> bool:
	"""Soldier/scholar artwork faces the opposite default direction from the peasant sprites."""
	return unit.get("type", "peasant") in ["soldier", "scholar"]

func _get_unit_portrait_path(race: String, gender: String) -> String:
	"""Get the portrait path for a unit based on race and gender"""
	var gender_prefix = "female" if gender.to_lower() == "female" else "male"
	var race_prefix = race.to_lower()
	return "res://assets/portraits/%s-portrait-%s-peasant-brownhair.png" % [race_prefix, gender_prefix]

func _restore_missing_unit_names():
	"""Restore names for units that don't have them (backward compatibility for old saves)"""
	var units_without_names = 0
	
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		if not player_data.has("units"):
			continue
		
		var race = player_data.get("race", "human")
		
		for unit in player_data["units"]:
			if not unit.has("name") or unit.get("name", "").is_empty():
				unit["name"] = _generate_random_name(race)
				units_without_names += 1
				DebugConfig.dprint("naming", ["Game: Assigned name '%s' to unit %s" % [unit["name"], unit.get("unique_id", "unknown")]])
	
	if units_without_names > 0:
		DebugConfig.dprint("naming", ["Game: Restored names for %d units from old save" % units_without_names])

func _load_building_work_names():
	"""Load work-related names for each workplace building type"""
	DebugConfig.dprint("naming", ["Game: Loading building work names..."])
	
	var workplace_types = ["fishing_hut", "lumberjack", "stoneworker"]
	
	for building_type in workplace_types:
		var names_path = "res://assets/names/buildings/%s.txt" % building_type
		var names_file = FileAccess.open(names_path, FileAccess.READ)
		if names_file:
			var content = names_file.get_as_text().strip_edges()
			var names_array = content.split("\n")
			# Filter out empty strings
			var filtered_names = []
			for work_name in names_array:
				var trimmed = work_name.strip_edges()
				if not trimmed.is_empty():
					filtered_names.append(trimmed)
			building_work_names[building_type] = filtered_names
			DebugConfig.dprint("naming", ["Game: Loaded %d work names for %s" % [filtered_names.size(), building_type]])
		else:
			push_error("Game: Failed to load work names for %s from %s" % [building_type, names_path])
			building_work_names[building_type] = []

func _rename_workplace_on_first_assignment(building_node: Node2D, unit: Dictionary):
	"""Rename a workplace when the first worker is assigned, combining surname + work name"""
	if not building_node or not unit:
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - building_node or unit is null"])
		return false
	
	var building_type = building_node.get_meta("building_type", "")
	var building_id = building_node.name
	DebugConfig.dprint("naming", ["DEBUG RENAME: Starting rename check for %s (type: %s)" % [building_id, building_type]])
	
	# Only rename workplaces (fishing_hut, lumberjack, stoneworker, research, lumber_mill)
	var workplace_types = ["fishing_hut", "lumberjack", "stoneworker", "research", "lumber_mill"]
	if building_type not in workplace_types:
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - %s not in workplace_types" % building_type])
		return false
	
	# Check if already renamed (would have a name like "Surname WorkName" instead of "building_type#")
	# Default format is building_type followed by digits (e.g., "lumberjack1", "town_center1")
	if not building_id.begins_with(building_type):
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - building ID doesn't start with type"])
		return false
	
	var after_type = building_id.substr(building_type.length())
	if not after_type.is_valid_int():
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - building already has non-default name (%s after type %s is not just digits)" % [after_type, building_type]])
		return false
	
	DebugConfig.dprint("naming", ["DEBUG RENAME: Pattern check passed - ID: %s has default format (type + digits)" % building_id])
	
	# Extract surname from unit name (e.g., "John Gonzalez" -> "Gonzalez")
	var unit_name = unit.get("name", "")
	if unit_name.is_empty():
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - unit has no name"])
		return false
	
	var name_parts = unit_name.split(" ")
	var surname = name_parts[-1] if name_parts.size() > 0 else unit_name
	DebugConfig.dprint("naming", ["DEBUG RENAME: Unit name: %s, Surname: %s" % [unit_name, surname]])
	
	# Load building work names if not already loaded
	if not building_work_names.has(building_type) or building_work_names[building_type].is_empty():
		DebugConfig.dprint("naming", ["DEBUG RENAME: Loading work names for %s" % building_type])
		_load_building_work_names()
	
	# Get work names for this building type
	var work_names = building_work_names.get(building_type, [])
	DebugConfig.dprint("naming", ["DEBUG RENAME: Available work names for %s: %d names" % [building_type, work_names.size()]])
	if work_names.is_empty():
		DebugConfig.dprint("naming", ["DEBUG RENAME: Failed - No work names available for %s" % building_type])
		return false
	
	# Select a random work name
	var work_name = work_names[randi() % work_names.size()]
	
	# Combine surname + work name
	var new_building_name = surname + " " + work_name
	
	# Check for duplicates by seeing if this exact name already exists
	for other_building_name in renamed_workplaces.values():
		if other_building_name == new_building_name:
			# Duplicate found, try adding a number
			var counter = 1
			while renamed_workplaces.values().has(new_building_name + " " + str(counter)):
				counter += 1
			new_building_name = new_building_name + " " + str(counter)
			break
	
	# Update building metadata - store display name but keep node name as ID for selection
	var old_name = building_node.name
	
	# Store display name in metadata instead of renaming node
	building_node.set_meta("display_name", new_building_name)
	renamed_workplaces[old_name] = new_building_name
	
	# Update building connections cache - keep using building IDs
	# (no change needed, it already uses old_name which we're keeping)
	
	# No need to update player data - building ID stays the same (the node name)
	# Only the display_name metadata was changed
	var owner_player = building_node.get_meta("owner_player", 1)
	
	DebugConfig.dprint("naming", ["Game: Renamed workplace from '%s' to '%s' (display name only) after assigning %s" % [old_name, new_building_name, unit.get("unique_id")]])
	return true

func _cache_job_connections_for_unit(unit: Dictionary):
	"""Cache or recache the job connections for a unit after a new building is placed.
	This updates the unit's cached paths to include any newly available buildings."""
	var job = unit.get("job")
	if not job:
		return  # Unit doesn't have a job, nothing to do
	
	# Extract building name from job (handle barracks job naming: barracks1_station -> barracks1)
	var job_building = job
	if job.contains("_station") or job.contains("_training"):
		job_building = job.substr(0, job.rfind("_"))
	
	# Check if job building's connections are already cached
	if buildings_connections_cache.has(job_building):
		unit["job_connections"] = buildings_connections_cache[job_building]
		DebugConfig.dprint("jobs", ["Game: Used cached connections for unit ", unit.get("unique_id"), " at job ", job])
	else:
		var job_building_node = map_objects_holder.get_node_or_null(NodePath(job_building))
		if job_building_node:
			# Fallback: calculate if not cached (shouldn't happen in normal flow)
			var connections = _find_building_connections_for_unit(job_building_node)
			unit["job_connections"] = connections
			# Also cache it for future use
			buildings_connections_cache[job_building] = connections
			DebugConfig.dprint("jobs", ["Game: Calculated and cached connections for unit ", unit.get("unique_id"), " at job ", job])
		else:
			DebugConfig.dprint("jobs", ["Game: Warning - could not find job building node: ", job])

func _recalculate_affected_unit_paths_after_building_placement(new_building_name: String, owner_player: int):
	"""Recalculate paths for all units with jobs after a new building is placed.
	This ensures that the new building can be accessed as a resource location if applicable."""
	if not players_data.has(owner_player):
		return
	
	var player_data = players_data[owner_player]
	var units = player_data.get("units", [])
	var units_updated = 0
	
	# Check all units with jobs - they might need path updates
	for unit in units:
		var job = unit.get("job")
		if job:  # Unit has a job assignment
			# Re-cache the job connections to include the new building
			_cache_job_connections_for_unit(unit)
			units_updated += 1
	
	if units_updated > 0:
		DebugConfig.dprint("buildings", ["Game: Updated paths for ", units_updated, " units after building ", new_building_name, " was placed"])

func _calculate_and_cache_building_connections(new_building: Node2D):
	"""Calculate connections for a new building ONCE and cache them with paths bidirectionally.
	This eliminates the need to recalculate paths for every unit assignment and building placement."""
	var building_name = new_building.name
	var connections = _find_building_connections_for_unit(new_building)
	
	# Store connections in cache indexed by building name
	buildings_connections_cache[building_name] = connections
	
	# Also add reverse connections: if A→B exists, add B→A with reversed path
	for connection in connections:
		var target_building_name = connection.get("name", "")
		if target_building_name and connection.get("object_type") == "building":
			# Get or create the target building's connection list
			if not buildings_connections_cache.has(target_building_name):
				buildings_connections_cache[target_building_name] = []
			
			# Create reverse connection with reversed path
			var reversed_path = connection.get("path", []).duplicate()
			reversed_path.reverse()
			
			var reverse_connection = {
				"name": building_name,
				"type": new_building.get_meta("building_type", "unknown"),
				"distance": connection.get("distance", 0),
				"object_type": "building",
				"path": reversed_path,
				"tile_coords": tilemap_layer.local_to_map(new_building.position)
			}
			
			# Check if this reverse connection already exists
			var already_exists = false
			for existing in buildings_connections_cache[target_building_name]:
				if existing.get("name") == building_name:
					already_exists = true
					break
			
			if not already_exists:
				buildings_connections_cache[target_building_name].append(reverse_connection)
	
	DebugConfig.dprint("buildings", ["Game: Cached connections for building ", building_name, " (", connections.size(), " connections)"])

func _auto_assign_units_to_building(building_node: Node2D, capacity_type: String, slots_to_fill: int):
	"""Automatically assign available units to a building when capacity is increased"""
	if not building_node:
		return
	
	var owner_player = building_node.get_meta("owner_player", 1)
	var building_id = building_node.name
	
	DebugConfig.dprint("jobs", ["Auto-assigning ", slots_to_fill, " units to ", capacity_type, " capacity at ", building_id])
	
	# Get all unassigned units for this player
	var player_units = players_data.get(owner_player, {}).get("units", [])
	var units_assigned = 0
	
	DebugConfig.dprint("jobs", ["Player ", owner_player, " has ", player_units.size(), " total units"])
	
	# First, try to assign existing unassigned units
	for unit in player_units:
		if units_assigned >= slots_to_fill:
			break
		
		if unit.get("is_pet", false):
			continue  # Pets are not assigned to buildings
		
		# Check if unit can be assigned to this capacity type
		var can_assign = false
		var living_quarters = unit.get("living_quarters", null)
		var job = unit.get("job", null)
		
		if capacity_type == "living" and living_quarters == null:
			can_assign = true
		elif capacity_type == "worker" and job == null:
			can_assign = true
		elif capacity_type == "station" and job == null:
			can_assign = true
		
		if can_assign:
			# Assign unit to this building
			if capacity_type == "living":
				unit["living_quarters"] = building_id
			elif capacity_type == "worker":
				unit["job"] = building_id
				# Peasants assigned to a research post automatically begin scholar training
				if building_node.get_meta("building_type", "") == "research" and unit.get("type", "peasant") == "peasant":
					_start_unit_training(unit, "scholar")
				# Use cached building connections if available, otherwise calculate
				if buildings_connections_cache.has(building_id):
					unit["job_connections"] = buildings_connections_cache[building_id]
				else:
					var job_building_node = map_objects_holder.get_node_or_null(NodePath(building_id))
					if job_building_node:
						var connections = _find_building_connections_for_unit(job_building_node)
						unit["job_connections"] = connections
						buildings_connections_cache[building_id] = connections
			elif capacity_type == "station":
				# Barracks uses a compound job name so unit_view_modal can strip the suffix
				unit["job"] = building_id + "_station"
				if buildings_connections_cache.has(building_id):
					unit["job_connections"] = buildings_connections_cache[building_id]
				else:
					var job_building_node = map_objects_holder.get_node_or_null(NodePath(building_id))
					if job_building_node:
						var connections = _find_building_connections_for_unit(job_building_node)
						unit["job_connections"] = connections
						buildings_connections_cache[building_id] = connections
				# Peasants stationed at the barracks automatically begin soldier training
				if unit.get("type", "peasant") == "peasant":
					_start_unit_training(unit, "soldier")
			
			# Also update the job metadata to track which unit is assigned
			var jobs = building_node.get_meta("resource_jobs", [])
			
			# Count filled jobs BEFORE assignment to detect if this is the first
			var jobs_filled_before = 0
			for job_slot in jobs:
				if job_slot.get("unit_assigned") != null:
					jobs_filled_before += 1
			var is_first_assignment = jobs_filled_before == 0
			
			var assigned_job = null
			var job_index = -1
			for i in range(jobs.size()):
				if jobs[i].get("unit_assigned") == null:
					jobs[i]["unit_assigned"] = unit["unique_id"]
					assigned_job = jobs[i]
					job_index = i
					break
			
			# Store building_id and job_index in unit (building ID is already stored as unit["job"])
			if assigned_job:
				# Store the index of the job within the building's resource_jobs array
				unit["assigned_job_index"] = job_index
				unit["previous_job"] = building_id  # Initialize previous_job when assigning
				DebugConfig.dprint("jobs", ["DEBUG: Assigned unit ", unit["unique_id"], " to job with path containing ", assigned_job.get("tile_path", []).size(), " tiles"])
				
				# Update unit position to home if it now has both assignments
				var current_living_quarters = unit.get("living_quarters", null)
				if current_living_quarters:
					var living_building = map_objects_holder.get_node_or_null(NodePath(current_living_quarters))
					if living_building:
						unit["position"] = living_building.position
						DebugConfig.dprint("jobs", ["DEBUG: Updated unit ", unit["unique_id"], " position to home at ", current_living_quarters])
			
			# CRITICAL: Save the updated jobs back to building metadata
			building_node.set_meta("resource_jobs", jobs)
			
			# Mark farm tile as having a worker and mirror the job so its modal shows the unit
			if assigned_job and assigned_job.get("resource_type", "") == "farm":
				var farm_node = map_objects_holder.get_node_or_null(NodePath(assigned_job.get("resource_id", "")))
				if is_instance_valid(farm_node):
					farm_node.set_meta("farm_worker_assigned", true)
					# Mirror a display-only job entry on the farm so its modal shows the assigned unit
					var farm_jobs: Array = farm_node.get_meta("resource_jobs", [])
					# Replace existing mirror or append
					var mirror_inserted := false
					for fi in range(farm_jobs.size()):
						if farm_jobs[fi].get("resource_type", "") == "farm_mirror":
							farm_jobs[fi]["unit_assigned"] = unit["unique_id"]
							farm_jobs[fi]["farmhouse_id"] = building_id
							mirror_inserted = true
							break
					if not mirror_inserted:
						farm_jobs.append({
							"job_id":        "mirror_" + building_id + "_" + unit["unique_id"],
							"path_id":       "",
							"resource_id":   building_id,
							"resource_type": "farm_mirror",
							"farmhouse_id":  building_id,
							"tile_path":     [],
							"world_path":    [],
							"unit_assigned": unit["unique_id"],
							"created_day":   0
						})
					farm_node.set_meta("resource_jobs", farm_jobs)
			
			# If this is the first assignment to a workplace, rename it with the worker's surname + work name
			if is_first_assignment and capacity_type == "worker":
				DebugConfig.dprint("jobs", ["DEBUG: About to call rename - building name before: %s" % building_node.name])
				var rename_result = _rename_workplace_on_first_assignment(building_node, unit)
				DebugConfig.dprint("jobs", ["DEBUG: Rename result: %s, building name after: %s" % [rename_result, building_node.name]])
			
			# Notify modal that jobs have been updated (use updated building name)
			building_jobs_updated.emit(building_node.name)
			units_assigned += 1
			DebugConfig.dprint("jobs", ["Auto-assigned unit ", unit["unique_id"], " to ", capacity_type, " at ", building_id])
	
	var remaining_slots = slots_to_fill - units_assigned
	if remaining_slots > 0:
		DebugConfig.dprint("jobs", ["Creating ", remaining_slots, " new units for ", capacity_type, " capacity"])
		_create_new_units_for_capacity(building_node, capacity_type, remaining_slots, owner_player)
	
	# After all assignments, check for units that now have both living quarters and jobs
	_check_and_create_missing_sprites(owner_player)
	check_workforce_achievements()
	
	DebugConfig.dprint("jobs", ["Auto-assigned ", units_assigned, " units and created ", (slots_to_fill - units_assigned), " new units for ", capacity_type, " capacity"])

func _create_unit_sprite_and_start_cycle(unit: Dictionary):
	"""Create sprite for a fully assigned unit and start its movement cycle"""
	var unit_id = unit["unique_id"]
	var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
	
	# Cache building connections if unit has a job (calculate once, reuse in cycle)
	var job = unit.get("job", null)
	if job and not unit.has("job_connections"):
		# Extract building name from job (handle barracks job naming: barracks1_station -> barracks1)
		var job_building = job
		if job.contains("_station") or job.contains("_training"):
			job_building = job.substr(0, job.rfind("_"))
		
		var building_node = map_objects_holder.get_node_or_null(NodePath(job_building))
		if building_node:
			unit["job_connections"] = _find_building_connections_for_unit(building_node)
	
	if not existing_sprite:
		# Create sprite for this unit (visible for all units, assigned or not)
		var unit_sprite = Sprite2D.new()
		unit_sprite.name = unit_id
		
		# Choose scatter anchor: home building if assigned, town centre otherwise
		var living_quarters_id = unit.get("living_quarters", null)
		var anchor_pos: Vector2
		if living_quarters_id and map_objects_holder:
			var home_building = map_objects_holder.get_node_or_null(NodePath(living_quarters_id))
			if home_building:
				anchor_pos = home_building.position
			else:
				anchor_pos = _get_player_town_centre_position(unit.get("player_id", 1))
		else:
			anchor_pos = _get_player_town_centre_position(unit.get("player_id", 1))
		
		# If we have a stored non-zero position from a previous session, use it
		if unit["position"] != Vector2.ZERO:
			unit_sprite.position = unit["position"]
		else:
			# Scatter the unit around the anchor point
			var scatter_radius = 50.0
			var random_angle = randf() * TAU
			var random_distance = randf() * scatter_radius
			var offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
			unit_sprite.position = anchor_pos + offset
			unit["position"] = unit_sprite.position
		
		unit_sprite.z_index = 6
		unit_sprite.centered = true  # Center the sprite on its position
		unit_sprite.scale = _get_unit_sprite_scale(unit)
		
		# Load texture based on unit's race and gender
		var texture_path = _get_pet_sprite_path(unit.get("pet_type", "cat")) if unit.get("is_pet", false) else _get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"))
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			unit_sprite.texture = texture
			DebugConfig.dprint("population", ["Unit %s: Loaded texture %s (size: %s)" % [unit_id, texture_path, str(texture.get_size())]])
		else:
			DebugConfig.dprint("population", ["Unit %s: Texture not found at %s - using fallback" % [unit_id, texture_path]])
			# Create a colored rectangle as fallback
			var rect = ColorRect.new()
			rect.size = Vector2(16, 16)
			rect.color = Color.YELLOW
			unit_sprite.add_child(rect)
		
		# Track bidirectional mapping
		unit_sprite.set_meta("unit_id", unit_id)  # Sprite knows which unit it belongs to
		unit_sprite.set_meta("unit_data", unit)  # Store reference to unit data dictionary
		
		# Create clickable area for the unit sprite using a Control node for proper input detection
		var click_control = Control.new()
		click_control.name = unit_id + "_clickable"
		click_control.set_meta("unit_id", unit_id)
		click_control.set_meta("unit_data", unit)
		click_control.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse to pass through when not hovering
		
		# Set size and centered position relative to sprite
		click_control.size = Vector2(40, 40)
		click_control.position = Vector2(-20, -20)  # Center on sprite position
		
		# Connect mouse input detection
		click_control.gui_input.connect(_on_unit_control_gui_input.bindv([unit]))
		click_control.mouse_entered.connect(_on_unit_mouse_entered.bindv([unit]))
		click_control.mouse_exited.connect(_on_unit_mouse_exited.bindv([unit]))
		

		unit_sprite.add_child(click_control)
		
		if map_objects_holder:
			map_objects_holder.add_child(unit_sprite)
			DebugConfig.dprint("population", ["Unit %s sprite added to scene at position: %s" % [unit_id, str(unit_sprite.position)]])
		else:
			DebugConfig.dprint("population", ["ERROR: map_objects_holder is null, cannot add sprite"])
		
		existing_sprite = unit_sprite  # Store reference for tracking below
	
	# ALWAYS set sprite_id in unit data, whether sprite was just created or already existed
	unit["sprite_id"] = unit_id  # Unit data tracks its sprite ID
	unit_sprite_map[unit_id] = existing_sprite  # Game tracks unit -> sprite mapping
	DebugConfig.dprint("population", ["Unit %s: Sprite tracking added to map" % unit_id])
	
	# Initialize unit at home and start movement cycle
	unit["movement_cycle_step"] = 0  # Start at home
	unit["movement_state"] = "idle"
	_start_unit_movement_cycle(unit)

func _create_new_units_for_capacity(building_node: Node2D, capacity_type: String, count: int, owner_player: int):
	"""DEPRECATED: Units are now created upfront during game initialization and stored in players_data.
	This function is kept for compatibility but does not create new units."""
	DebugConfig.dprint("population", ["Game: Note - Units created at game start, not when capacity increases. No new units created for remaining capacity slots."])
	# Units exist from game initialization - they get assigned to buildings via _auto_assign_units_to_building()
	# If there aren't enough unassigned units for the capacity increase, the capacity will simply be partially filled

func _assign_unit_to_living_quarters(unit_data: Dictionary, owner_player: int):
	"""Assign a unit to living quarters if available"""
	DebugConfig.dprint("population", ["DEBUG: Assigning living quarters for unit ", unit_data["unique_id"]])
	# Find a house or town_center with available space
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.get_meta("owner_player", 1) == owner_player:
				var building_type = child.get_meta("building_type", "unknown")
				if building_type in ["house", "town_center"]:
					var living_occupancy = child.get_meta("living_occupancy", 0)
					var living_capacity = _get_living_capacity(building_type)
					DebugConfig.dprint("population", ["DEBUG: Found %s %s - occupancy:%d capacity:%d" % [building_type, child.name, living_occupancy, living_capacity]])
					if living_occupancy < living_capacity:
						unit_data["living_quarters"] = child.name
						unit_data["position"] = child.position
						child.set_meta("living_occupancy", living_occupancy + 1)
						update_player_population(owner_player)
						DebugConfig.dprint("population", ["DEBUG: Assigned unit ", unit_data["unique_id"], " to living quarters at ", child.name])
						return
	
	DebugConfig.dprint("population", ["DEBUG: No housing available for unit ", unit_data["unique_id"]])

func _auto_assign_all_units_to_housing():
	"""Assign all unhoused units to available living-capacity buildings.
	Priority: town_center → house.
	Called once after _create_initial_units on new game."""
	if not map_objects_holder:
		return

	# Priority order for living buildings (only house and town_center provide housing)
	var priority: Array = ["town_center", "house"]

	for player_id in players_data.keys():
		if str(player_id) == "environment":
			continue
		var player_units: Array = players_data[player_id].get("units", [])

		# Build a list of buildings with spare living capacity, in priority order
		var housing_slots: Array = []  # [{node, remaining}]
		for ptype in priority:
			for child in map_objects_holder.get_children():
				if not _is_building_node(child):
					continue
				if child.get_meta("owner_player", 1) != player_id:
					continue
				if child.get_meta("building_type", "") != ptype:
					continue
				var cap: int = _get_living_capacity(ptype)
				var occ: int = child.get_meta("living_occupancy", 0)
				var remaining: int = cap - occ
				if remaining > 0:
					housing_slots.append({"node": child, "remaining": remaining})

		# Assign each unhoused unit to the next available slot
		var slot_idx: int = 0
		for unit in player_units:
			if unit.get("is_pet", false):
				continue  # Pets roam free — no housing assignment
			if unit.get("living_quarters") != null:
				continue  # Already housed
			if slot_idx >= housing_slots.size():
				break  # No more housing

			var slot = housing_slots[slot_idx]
			var building_node: Node2D = slot["node"]
			unit["living_quarters"] = building_node.name
			# Scatter position near the building
			var angle: float = randf() * TAU
			var dist: float = randf_range(20.0, 50.0)
			unit["position"] = building_node.position + Vector2(cos(angle), sin(angle)) * dist
			# Increment building occupancy
			var new_occ: int = building_node.get_meta("living_occupancy", 0) + 1
			building_node.set_meta("living_occupancy", new_occ)
			slot["remaining"] -= 1
			if slot["remaining"] <= 0:
				slot_idx += 1

			DebugConfig.dprint("population", ["Game: Auto-housed %s in %s" % [unit["unique_id"], building_node.name]])

		# Refresh population data now occupancy is accurate
		update_player_population(player_id)
		DebugConfig.dprint("population", ["Game: Auto-housing complete for player %d — %d units housed" % [player_id, player_units.filter(func(u): return u.get("living_quarters") != null).size()]])

func _get_unit_spawn_position_near_building(building_node: Node2D) -> Vector2:
	"""Get a spawn position near a building"""
	# Spawn slightly offset from the building to avoid overlap
	var offset_distance = 30.0
	var random_angle = randf() * TAU  # Random angle in radians
	var offset = Vector2(cos(random_angle), sin(random_angle)) * offset_distance
	return building_node.position + offset

func _try_to_complete_unit_assignment(unit_data: Dictionary, owner_player: int):
	"""Try to find a matching assignment for the other capacity type"""
	var living_quarters = unit_data.get("living_quarters", null)
	var job = unit_data.get("job", null)
	
	# If unit already has both assignments, create sprite immediately
	if living_quarters != null and job != null:
		_create_unit_sprite_and_start_cycle(unit_data)
		return
	
	# Look for buildings with available capacity of the needed type
	var needed_capacity_type = "living" if living_quarters == null else "worker"
	
	# Find buildings with available capacity
	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		
		var building_owner = child.get_meta("owner_player", 1)
		if building_owner != owner_player:
			continue
		
		# Check if this building type can provide the needed capacity
		var building_type = child.get_meta("building_type", "unknown")
		if not _building_provides_capacity(building_type, needed_capacity_type):
			continue
		
		# Check if building has available capacity
		var max_capacity = _get_building_max_capacity(building_type, needed_capacity_type)
		var current_occupancy = child.get_meta(needed_capacity_type + "_occupancy", 0)
		
		if current_occupancy < max_capacity:
			# Assign unit to this building
			if needed_capacity_type == "living":
				unit_data["living_quarters"] = child.name
			else:
				unit_data["job"] = child.name
			
			# Update building occupancy
			child.set_meta(needed_capacity_type + "_occupancy", current_occupancy + 1)
			
			# Update global population
			update_player_population(owner_player)
			
			# Create sprite since unit now has both assignments
			_create_unit_sprite_and_start_cycle(unit_data)
			
			DebugConfig.dprint("population", ["Auto-matched unit ", unit_data["unique_id"], " to ", needed_capacity_type, " at ", child.name])
			return
	
	DebugConfig.dprint("population", ["No available ", needed_capacity_type, " capacity found for unit ", unit_data["unique_id"]])

func _create_initial_units_from_population():
	"""Dynamically create units based on population total for new games and loaded games"""
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		var pop_data = player_data.get("population", {})
		var total_population = pop_data.get("total", 10)
		var player_race = player_data.get("race", "human")
		
		# Clear existing units array and create new ones based on population
		player_data["units"] = []
		
		DebugConfig.dprint("population", ["Creating ", total_population, " units for player ", player_id, " based on population total"])
		
		# Create unassigned units at default spawn position
		for i in range(total_population):
			var unit_data = {
				"unique_id": _get_next_unit_id(),
				"name": _generate_random_name(player_race),
				"type": "peasant",
				"race": player_race,
				"player_id": player_id,
				"position": Vector2.ZERO,  # Will be scattered near town centre when sprite is created
				"living_quarters": null,
				"job": null,
				# Movement properties
				"current_path": [],
				"path_index": 0,
				"movement_state": "idle_wander",  # Wander near town centre until assigned
				"movement_target": null,
				"movement_cycle_step": 0,
				"work_timer": randf_range(0.0, 3.0),  # Stagger start times
				"wander_wait_time": randf_range(1.0, 4.0),
				"movement_speed": 25.0,
				"speed_multiplier": randf_range(0.85, 1.15)  # 85% to 115% speed variation
			}
			
			DebugConfig.dprint("population", ["Game: Created unit %s with name '%s' for player %d" % [unit_data["unique_id"], unit_data["name"], player_id]])
			player_data["units"].append(unit_data)
		
		DebugConfig.dprint("population", ["Created ", total_population, " unassigned units for player ", player_id])

func _building_provides_capacity(building_type: String, capacity_type: String) -> bool:
	"""Check if a building type provides a specific capacity type"""
	match capacity_type:
		"living":
			return building_type in ["house", "town_center"]
		"worker":
			return building_type in ["barracks", "fishing_hut", "farmhouse", "stoneworker", "research", "lumber_mill", "lumberjack", "town_center"]
	return false

func _get_building_max_capacity(building_type: String, capacity_type: String) -> int:
	"""Get the maximum capacity for a building type"""
	# Define capacity limits for different building types
	var capacity_limits = {
		"house": {"living": 7, "worker": 0},
		"farmhouse": {"living": 0, "worker": 6},
		"town_center": {"living": 12, "worker": 2},
		"barracks": {"living": 0, "worker": 8},
		"fishing_hut": {"living": 0, "worker": 5},
		"stoneworker": {"living": 0, "worker": 10},
		"research": {"living": 0, "worker": 8},
		"lumber_mill": {"living": 0, "worker": 10},
		"lumberjack": {"living": 0, "worker": 10}
	}
	
	return capacity_limits.get(building_type, {}).get(capacity_type, 0)

func _update_unit_movements(delta: float):
	"""Update all unit movements each frame"""
	# Skip if unit movement is paused
	if unit_movement_paused:
		return
	
	# Apply speed multiplier to delta
	var adjusted_delta = delta * unit_movement_speed
	
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		if not player_data.has("units"):
			continue
		
		for unit in player_data["units"]:
			# Process all units that have a visible sprite (assigned or idle-wandering)
			var unit_sprite = map_objects_holder.get_node_or_null(unit["unique_id"])
			if not unit_sprite:
				continue
			
			_process_unit_movement(unit, unit_sprite, adjusted_delta)

func _process_unit_movement(unit: Dictionary, sprite: Node2D, delta: float):
	"""Process movement for a single unit"""
	var movement_state = unit.get("movement_state", "idle")
	
	match movement_state:
		"idle":
			# Route based on assignment: unassigned units return home then wander
			if unit.get("job", null) == null or unit.get("living_quarters", null) == null:
				_start_return_home(unit)
			elif is_instance_valid(_get_stationary_job_building(unit)):
				# Stationary job (barracks/research) — wander near the workplace instead of commuting
				unit["work_timer"] += delta
				var wander_wait = unit.get("wander_wait_time", 3.0)
				if unit["work_timer"] >= wander_wait:
					unit["work_timer"] = 0.0
					_start_idle_wander(unit)
			else:
				# Fully assigned — run work cycle
				unit["work_timer"] += delta
				if unit["work_timer"] >= 2.0:
					unit["work_timer"] = 0.0
					_start_unit_movement_cycle(unit)
		
		"idle_wander":
			# Unassigned units wander near the town centre
			unit["work_timer"] += delta
			var wander_wait = unit.get("wander_wait_time", 3.0)
			if unit["work_timer"] >= wander_wait:
				unit["work_timer"] = 0.0
				_start_idle_wander(unit)
		
		"returning_home":
			# Unit lost their job — follow path home then idle_wander on arrival
			var current_path = unit.get("current_path", [])
			if current_path.is_empty():
				unit["movement_state"] = "idle_wander"
				unit["work_timer"] = 0.0
				return
			var path_index = unit.get("path_index", 0)
			if path_index >= current_path.size():
				# Arrived home — start wandering
				unit["current_path"] = []
				unit["path_index"] = 0
				unit["movement_state"] = "idle_wander"
				unit["work_timer"] = 0.0
				return
			# Move towards next waypoint (same logic as "moving")
			var target_pos = current_path[path_index]
			var current_pos = sprite.position
			var direction = (target_pos - current_pos).normalized()
			var movement_speed = unit.get("movement_speed", 50.0)
			var speed_multiplier = unit.get("speed_multiplier", 1.0)
			var move_distance = movement_speed * speed_multiplier * delta
			if direction.x != 0:
				sprite.flip_h = (direction.x > 0) != _unit_sprite_is_reversed(unit)
			if current_pos.distance_to(target_pos) <= move_distance:
				sprite.position = target_pos
				unit["position"] = target_pos
				unit["path_index"] = path_index + 1
			else:
				sprite.position = current_pos + direction * move_distance
				unit["position"] = sprite.position
		
		"waiting":
			# Unit is waiting at the resource/workplace
			unit["work_timer"] += delta
			if unit["work_timer"] >= 3.0:  # Wait 3 seconds at resource
				unit["work_timer"] = 0.0
				unit["movement_state"] = "idle"
				_on_unit_reached_destination(unit)
		
		"moving":
			# Follow current path
			var current_path = unit.get("current_path", [])
			if current_path.is_empty():
				# No path — go back to appropriate idle state
				var has_job = unit.get("job", null) != null and unit.get("living_quarters", null) != null and not is_instance_valid(_get_stationary_job_building(unit))
				unit["movement_state"] = "idle" if has_job else "idle_wander"
				return
			
			var path_index = unit.get("path_index", 0)
			if path_index >= current_path.size():
				# Reached end of path
				var has_job = unit.get("job", null) != null and unit.get("living_quarters", null) != null and not is_instance_valid(_get_stationary_job_building(unit))
				if has_job:
					unit["movement_state"] = "waiting"  # Work cycle: wait at destination
					unit["work_timer"] = 0.0
				else:
					# Idle wander: just pause then pick a new destination
					unit["movement_state"] = "idle_wander"
					unit["work_timer"] = 0.0
				unit["current_path"] = []
				unit["path_index"] = 0
				return
			
			# Move towards next waypoint
			var target_pos = current_path[path_index]
			var current_pos = sprite.position
			var direction = (target_pos - current_pos).normalized()
			var movement_speed = unit.get("movement_speed", 50.0)
			var speed_multiplier = unit.get("speed_multiplier", 1.0)
			var move_distance = movement_speed * speed_multiplier * delta
			
			# Handle sprite flipping based on direction
			if direction.x != 0:  # Only flip if there's horizontal movement
				sprite.flip_h = (direction.x > 0) != _unit_sprite_is_reversed(unit)  # Flip when moving right (soldier/scholar art faces the other way)
			
			if current_pos.distance_to(target_pos) <= move_distance:
				# Reached this waypoint
				sprite.position = target_pos
				unit["path_index"] = path_index + 1
			else:
				# Keep moving towards waypoint
				sprite.position = current_pos + direction * move_distance
			
			# Update unit position data
			unit["position"] = sprite.position

func _start_unit_movement_cycle(unit: Dictionary):
	"""Start or continue the unit's movement cycle"""
	var cycle_step = unit.get("movement_cycle_step", 0)
	var living_quarters = unit.get("living_quarters", null)
	var job = unit.get("job", null)
	
	if living_quarters == null or job == null:
		return  # Can't move without both assignments
	
	# Prevent starting new cycle if unit is already moving
	if unit.get("movement_state", "idle") == "moving":
		return
	
	# Extract building name from job (handle barracks job naming: barracks1_station -> barracks1)
	var job_building = job
	if job.contains("_station") or job.contains("_training"):
		job_building = job.substr(0, job.rfind("_"))
	
	DebugConfig.dprint("movement", ["Starting movement cycle for unit ", unit["unique_id"], " step: ", cycle_step, " (job: ", job, " -> building: ", job_building, ")"])
	
	match cycle_step:
		0:  # At home - go to work
			_move_unit_to_building(unit, job_building, 1)
		1:  # At work - find resource connection and go there
			_move_unit_to_resource(unit, 2)
		2:  # At resource - go back to work
			_move_unit_to_building(unit, job_building, 3)
		3:  # Back at work - go home
			_move_unit_to_building(unit, living_quarters, 4)
		4:  # Back home - cycle complete, start over
			unit["movement_cycle_step"] = 0
			_start_unit_movement_cycle(unit)

func _on_unit_reached_destination(unit: Dictionary):
	"""Called when unit reaches its movement target"""
	var cycle_step = unit.get("movement_cycle_step", 0)
	
	# Clear movement state
	unit["current_path"] = []
	unit["path_index"] = 0
	unit["work_timer"] = 0.0
	
	# Route based on current assignment
	var has_full_assignment = unit.get("job", null) != null and unit.get("living_quarters", null) != null
	if not has_full_assignment:
		# Unit lost its assignment mid-cycle — fall back to wandering
		unit["movement_state"] = "idle_wander"
		return
	
	unit["movement_state"] = "idle"
	# Advance to next step in cycle
	unit["movement_cycle_step"] = (cycle_step + 1) % 5
	# Immediately start the next part of the movement cycle
	_start_unit_movement_cycle(unit)

func _is_tile_walkable(tile_coords: Vector2i) -> bool:
	"""Check if a tile is walkable for idle wandering (in bounds, not blocked by mountain/building)"""
	if not tilemap_layer:
		return false
	var used_rect = tilemap_layer.get_used_rect()
	if not used_rect.has_point(tile_coords):
		return false
	# Reject tiles occupied by buildings or mountains
	if map_objects_holder:
		var tile_world = tilemap_layer.map_to_local(tile_coords)
		for child in map_objects_holder.get_children():
			if child.position.distance_to(tile_world) < 20.0:
				var child_name = child.name as String
				if _is_building_node(child) or child_name.begins_with("mountain_"):
					return false
	return true

func _start_return_home(unit: Dictionary):
	"""Path the unit back to their living quarters, then switch to idle_wander on arrival."""
	var home = unit.get("living_quarters")
	if not home or not map_objects_holder:
		unit["movement_state"] = "idle_wander"
		unit["movement_cycle_step"] = 0
		unit["current_path"] = []
		unit["path_index"] = 0
		unit["work_timer"] = 0.0
		return
	var home_node = map_objects_holder.get_node_or_null(NodePath(home))
	if not home_node or not tilemap_layer:
		unit["movement_state"] = "idle_wander"
		unit["movement_cycle_step"] = 0
		unit["current_path"] = []
		unit["path_index"] = 0
		unit["work_timer"] = 0.0
		return
	var from_tile = tilemap_layer.local_to_map(unit.get("position", home_node.position))
	var to_tile = tilemap_layer.local_to_map(home_node.position)
	var tile_path = _astar_pathfind_for_game(from_tile, to_tile)
	if tile_path.is_empty():
		unit["movement_state"] = "idle_wander"
		unit["movement_cycle_step"] = 0
		unit["current_path"] = []
		unit["path_index"] = 0
		unit["work_timer"] = 0.0
		return
	var world_path = []
	for tc in tile_path:
		world_path.append(tilemap_layer.map_to_local(tc))
	unit["current_path"] = world_path
	unit["path_index"] = 0
	unit["movement_state"] = "returning_home"
	unit["movement_cycle_step"] = 0
	unit["work_timer"] = 0.0

func _get_stationary_job_building(unit: Dictionary) -> Node2D:
	"""Returns the workplace node if unit's job is a 'stationary' role (barracks/research) that
	wanders near the worksite instead of running the fetch-a-resource commute cycle. Null otherwise."""
	var job = unit.get("job", null)
	if job == null or not map_objects_holder:
		return null
	var job_building_name: String = job
	if job.contains("_station") or job.contains("_training"):
		job_building_name = job.substr(0, job.rfind("_"))
	var job_node = map_objects_holder.get_node_or_null(NodePath(job_building_name))
	if not job_node:
		return null
	var btype = job_node.get_meta("building_type", "")
	if btype == "barracks" or btype == "research":
		return job_node
	return null

func _start_idle_wander(unit: Dictionary):
	"""Pick a random walkable tile near the anchor (workplace if stationed, else town centre) and A* pathfind there"""
	if not tilemap_layer:
		return
	var player_id = unit.get("player_id", 1)
	
	# Use the workplace position as anchor if unit has a stationary job (barracks/research)
	var anchor = Vector2.ZERO
	var wander_radius = 8  # tiles — default when wandering near town centre
	var stationary_building = _get_stationary_job_building(unit)
	if is_instance_valid(stationary_building):
		anchor = stationary_building.position
		wander_radius = 4  # Stay closer to their worksite
	if anchor == Vector2.ZERO:
		anchor = _get_player_town_centre_position(player_id)
	if anchor == Vector2.ZERO:
		return
	var anchor_tile = tilemap_layer.local_to_map(anchor)
	var target_tile: Vector2i = anchor_tile  # fallback
	var found = false
	for _attempt in range(15):
		var dx = randi_range(-wander_radius, wander_radius)
		var dy = randi_range(-wander_radius, wander_radius)
		var candidate = Vector2i(anchor_tile.x + dx, anchor_tile.y + dy)
		if _is_tile_walkable(candidate):
			target_tile = candidate
			found = true
			break
	if not found:
		# No walkable tile found — stay put a bit longer
		unit["work_timer"] = 0.0
		unit["wander_wait_time"] = randf_range(2.0, 5.0)
		return
	var unit_tile = tilemap_layer.local_to_map(unit["position"])
	var tile_path = _astar_pathfind_for_game(unit_tile, target_tile)
	if tile_path.is_empty():
		unit["work_timer"] = 0.0
		unit["wander_wait_time"] = randf_range(2.0, 5.0)
		return
	var world_path = []
	for tc in tile_path:
		world_path.append(tilemap_layer.map_to_local(tc))
	unit["current_path"] = world_path
	unit["path_index"] = 0
	unit["movement_state"] = "moving"
	unit["wander_wait_time"] = randf_range(1.5, 5.0)  # Next pause duration

func _move_unit_to_building(unit: Dictionary, building_name: String, next_step: int):
	"""Move unit to a specific building using pre-calculated paths from connections"""
	DebugConfig.dprint("movement", ["DEBUG: _move_unit_to_building called - unit: ", unit["unique_id"], " to building: ", building_name, " next_step: ", next_step])
	
	if building_name == null:
		DebugConfig.dprint("movement", ["DEBUG: Building name is null, returning"])
		return
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(building_name))
	if not building_node:
		DebugConfig.dprint("movement", ["Building not found: ", building_name])
		return
	
	# Check if this is a return trip (next_step > current step would indicate return)
	var is_return_trip = next_step > unit.get("movement_cycle_step", 0)
	
	# For return trips, reverse the appropriate path
	var path = []
	
	if is_return_trip and next_step == 3:
		# Returning from resource to workplace - reverse the resource path
		var resource_path = unit.get("resource_path", [])
		if not resource_path.is_empty():
			path = _reverse_path(resource_path)
			DebugConfig.dprint("movement", ["DEBUG: Using reversed resource path for return to workplace (", path.size(), " waypoints)"])
	elif is_return_trip and next_step == 4:
		# Returning from workplace to home - reverse the home path
		var home_path = unit.get("home_path", [])
		if not home_path.is_empty():
			path = _reverse_path(home_path)
			DebugConfig.dprint("movement", ["DEBUG: Using reversed home path for return to living quarters (", path.size(), " waypoints)"])
	
	# If we didn't get a reversed path, try connections
	if path.is_empty():
		# Try to find the pre-calculated path from job connections
		var connections = unit.get("job_connections", [])
		
		DebugConfig.dprint("movement", ["DEBUG: Looking for path in job_connections (", connections.size(), " connections available)"])
		
		# Look for a connection to this building
		for connection in connections:
			if connection.get("name") == building_name and connection.has("path"):
				path = connection.get("path", [])
				DebugConfig.dprint("movement", ["DEBUG: Found path in job_connections to ", building_name, " with ", path.size(), " waypoints"])
				# Store this path for potential reversal later
				if next_step == 1:
					# This is the home to workplace path - store for reversal
					unit["home_path"] = path
				break
		
		# Fallback: if no pre-calculated path found, calculate it
		if path.is_empty():
			DebugConfig.dprint("movement", ["DEBUG: No path found in job_connections, calculating..."])
			var unit_pos = unit["position"]
			var target_pos = building_node.position
			
			# Get actual path using existing pathfinding system
			path = _get_path_between_positions(unit_pos, target_pos)
			if path.is_empty():
				# Fallback to direct path if pathfinding fails
				path = [target_pos]
				DebugConfig.dprint("movement", ["DEBUG: Calculated path empty, using direct path to ", target_pos])
			else:
				DebugConfig.dprint("movement", ["DEBUG: Calculated path with ", path.size(), " waypoints"])
			
			# Store for potential reversal
			if next_step == 1:
				unit["home_path"] = path
	
	unit["current_path"] = path
	unit["path_index"] = 0
	unit["movement_state"] = "moving"
	unit["movement_target"] = building_name
	unit["movement_cycle_step"] = next_step - 1  # Will be incremented when reached
	
	DebugConfig.dprint("movement", ["Unit ", unit["unique_id"], " moving to ", building_name, " (", path.size(), " waypoints)"])
	
	DebugConfig.dprint("movement", ["Unit ", unit["unique_id"], " moving to building: ", building_name, " with ", path.size(), " waypoints"])

func _get_assigned_job(unit: Dictionary) -> Dictionary:
	"""Retrieve the assigned job for a unit from the building's metadata"""
	var job_building_id = unit.get("job", null)
	var job_index = unit.get("assigned_job_index", -1)
	
	if job_building_id == null or job_index < 0:
		return {}
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(job_building_id))
	if not building_node:
		return {}
	
	var jobs = building_node.get_meta("resource_jobs", [])
	if job_index >= 0 and job_index < jobs.size():
		return jobs[job_index]
	
	return {}

func _move_unit_to_resource(unit: Dictionary, next_step: int):
	"""Move unit to the resource specified in their assigned job using the job's pre-calculated tile_path"""
	var assigned_job = _get_assigned_job(unit)
	if assigned_job.is_empty():
		DebugConfig.dprint("movement", ["Unit ", unit["unique_id"], " has no assigned job - skipping resource step"])
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	# Use the tile_path from the assigned job
	var tile_path = assigned_job.get("tile_path", [])
	if tile_path.is_empty():
		DebugConfig.dprint("movement", ["Unit ", unit["unique_id"], " has no resource path in job - skipping resource step"])
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	# Convert tile coordinates to world coordinates
	if not tilemap_layer:
		DebugConfig.dprint("movement", ["ERROR: TileMapLayer not found"])
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	var world_path = []
	for tile in tile_path:
		world_path.append(tilemap_layer.map_to_local(tile))
	
	# Set unit to move along this path
	unit["current_path"] = world_path
	unit["path_index"] = 0
	unit["movement_state"] = "moving"
	unit["resource_path"] = world_path  # Store for later reversal
	unit["movement_target"] = assigned_job.get("resource_id", "unknown")
	unit["movement_cycle_step"] = next_step - 1  # Will be incremented when reached
	
	DebugConfig.dprint("movement", ["Unit ", unit["unique_id"], " moving to resource ", assigned_job.get("resource_id"), " with path of ", world_path.size(), " waypoints"])

func _reverse_path(path: Array) -> Array:
	"""Reverse a path array for return trips"""
	if path.is_empty():
		return []
	
	var reversed = []
	for i in range(path.size() - 1, -1, -1):
		reversed.append(path[i])
	
	return reversed

func _find_nearest_farm(from_position: Vector2) -> Dictionary:
	"""Find the nearest farm building and return connection data"""
	var nearest = {}
	var nearest_distance = INF
	
	for child in map_objects_holder.get_children():
		if _is_building_node(child):
			var building_type = child.get_meta("building_type", "unknown")
			if building_type == "farm":
				var distance = from_position.distance_to(child.position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = {
						"name": child.name,
						"type": "farm",
						"distance": nearest_distance,
						"object_type": "farm"
					}
	
	return nearest

func _find_building_connections_for_unit(building: Node2D) -> Array:
	"""Get building connections - ensures mountains are included with full pathfinding"""
	# Use direct calculation to ensure all resources are found
	return _calculate_building_connections_directly(building)

func _calculate_building_connections_directly(building: Node2D) -> Array:
	"""Direct calculation of building-to-building connections only (resource connections now handled via job paths)"""
	var connections = []
	var building_type = building.get_meta("building_type", "unknown")
	
	DebugConfig.dprint("buildings", ["Finding connections for building type: ", building_type])
	
	# Define building-to-building connection rules only
	var connection_rules = {
		"house": ["town_center", "barracks", "stoneworker"],
		"barracks": ["town_center", "house"],
		"town_center": ["house", "barracks", "fishing_hut", "farmhouse", "stoneworker", "lumber_mill", "lumberjack"],
		"fishing_hut": ["town_center"],
		"farmhouse": ["town_center", "house"],
		"stoneworker": ["house", "town_center"],
		"lumberjack": ["house", "town_center"],
		"lumber_mill": ["town_center"]
	}
	
	var allowed_connections = connection_rules.get(building_type, [])
	if allowed_connections.is_empty():
		return connections
	
	var tilemap = tilemap_layer
	if not tilemap:
		return connections
	
	var building_tile_coords = tilemap.local_to_map(building.position)
	var connection_range_tiles = 50
	
	# Get buildings only (no resource connections)
	if has_method("get_player_buildings"):
		var all_buildings = get_player_buildings(1)
		DebugConfig.dprint("buildings", ["Checking connections for ", building.name, " at tile ", building_tile_coords, " - found ", all_buildings.size(), " total buildings"])
		
		for building_name in all_buildings:
			if building_name == building.name:
				continue
			
			var buildings_layer = building.get_parent()
			if buildings_layer and buildings_layer.has_node(NodePath(building_name)):
				var other_building = buildings_layer.get_node(NodePath(building_name))
				var other_type = other_building.get_meta("building_type", "unknown")
				var other_tile_coords = tilemap.local_to_map(other_building.position)
				
				var tile_distance = _hex_distance(building_tile_coords, other_tile_coords)
				
				if other_type in allowed_connections and tile_distance <= connection_range_tiles:
					connections.append({
						"name": other_building.name,
						"type": other_type,
						"distance": tile_distance,
						"object_type": "building",
						"tile_coords": other_tile_coords
					})
					DebugConfig.dprint("buildings", ["Added connection: ", building_name, " (", other_type, ") at ", tile_distance, " tiles away"])
	
	return connections

func _astar_pathfind_for_game(start: Vector2i, end: Vector2i) -> Array:
	"""A* pathfinding wrapper using the modal's algorithm"""
	var BuildingDetailsModalScript = preload("res://scripts/ui/building_details_modal.gd")
	var temp_modal = BuildingDetailsModalScript.new()
	var path = temp_modal._astar_pathfind(start, end, tilemap_layer)
	temp_modal.queue_free()
	return path

func _get_player_town_centre_position(player_id: int) -> Vector2:
	"""Get the world position of a player's town centre, used as idle-wander anchor"""
	if players_data.has(player_id):
		return players_data[player_id].get("town_centre_position", Vector2.ZERO)
	return Vector2.ZERO

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hexagonal distance between two tile coordinates"""
	# Convert offset coordinates to axial coordinates for distance calculation
	var ax = a.x - (a.y - (a.y & 1)) / 2
	var ay = a.y
	var az = -ax - ay
	
	var bx = b.x - (b.y - (b.y & 1)) / 2  
	var by = b.y
	var bz = -bx - by
	
	# Hexagonal distance in axial coordinates
	return (abs(ax - bx) + abs(ay - by) + abs(az - bz)) / 2

func _get_resource_position_by_connection(connection: Dictionary) -> Vector2:
	"""Get world position of a resource from connection data"""
	if connection.has("tile_coords"):
		return tilemap_layer.map_to_local(connection["tile_coords"])
	return Vector2.ZERO

func _get_path_between_positions(start_pos: Vector2, end_pos: Vector2) -> Array:
	"""Get pathfinding route between two world positions using building details modal system"""
	if not tilemap_layer:
		return [end_pos]  # Fallback to direct path
	
	# Create a temporary building details modal to access its pathfinding
	var BuildingDetailsModalScript = preload("res://scripts/ui/building_details_modal.gd")
	var temp_modal = BuildingDetailsModalScript.new()
	
	# Use the modal's pathfinding system
	var start_tile = tilemap_layer.local_to_map(start_pos)
	var end_tile = tilemap_layer.local_to_map(end_pos)
	
	var tile_path = temp_modal._astar_pathfind(start_tile, end_tile, tilemap_layer)
	temp_modal.queue_free()  # Clean up temp modal
	
	if tile_path.is_empty():
		return [end_pos]  # Fallback if pathfinding fails
	
	# Convert tile path to world positions
	var world_path = []
	for tile_coord in tile_path:
		world_path.append(tilemap_layer.map_to_local(tile_coord))
	
	return world_path

func _find_nearby_resources(building_tile: Vector2i, resource_type: String, max_count: int) -> Array:
	"""Find nearby resources using expanding search from building tile.
	Uses BFS-like expansion to check nearby tiles efficiently instead of checking all objects.
	Returns array of resource data (id, type, position, tile_coords) up to max_count."""
	var found_resources = []
	var visited = {}
	var queue = [building_tile]
	var max_radius = 20  # Maximum search radius in tiles
	
	DebugConfig.dprint("movement", ["Game: Searching for ", max_count, " nearby ", resource_type, " starting from tile ", building_tile])
	
	# Map building type to resource type if needed
	var search_resource_type = resource_type  # "mountains", "trees", "fish"
	
	while queue.size() > 0 and found_resources.size() < max_count:
		var current_tile = queue.pop_front()
		
		# Skip if already visited
		if visited.has(current_tile):
			continue
		visited[current_tile] = true
		
		# Check distance to avoid infinite search
		var dist = _hex_distance(building_tile, current_tile)
		if dist > max_radius:
			continue
		
		# Check if this tile has the requested resource
		var resource_data = get_resource_on_tile(current_tile)
		if not resource_data.is_empty():
			# Find the resource ID by searching all resources of this type
			var objects = get_environment_objects(search_resource_type)
			for obj_id in objects:
				var obj_data = objects[obj_id]
				if obj_data.get("tile_coords") == current_tile:
					# Skip resources already assigned to jobs (conflict avoidance)
					if obj_data.get("job") != null:
						DebugConfig.dprint("movement", ["Game: Resource ", obj_id, " already assigned to job, skipping"])
						continue
					
					found_resources.append({
						"id": obj_id,
						"type": search_resource_type,
						"data": obj_data,
						"position": obj_data.get("position"),
						"tile_coords": current_tile
					})
					DebugConfig.dprint("movement", ["Game: Found ", search_resource_type, " resource at tile ", current_tile])
					break
		
		# Add neighbors to queue for expansion (hex tiles have 6 neighbors)
		var neighbors = _get_hex_neighbors(current_tile)
		for neighbor in neighbors:
			if not visited.has(neighbor):
				queue.append(neighbor)
	
	DebugConfig.dprint("movement", ["Game: Found ", found_resources.size(), " resources of type ", search_resource_type])
	return found_resources

# ─── Farmhouse / farm-cycle system ───────────────────────────────────────────

const FARM_CYCLE := ["tilled", "sown", "growing", "grown"]
const FARM_TEXTURES := {
	"tilled":  "res://assets/buildings/human_farm_tilled.png",
	"sown":    "res://assets/buildings/human_farm_sown.png",
	"growing": "res://assets/buildings/human_farm_growing.png",
	"grown":   "res://assets/buildings/human_farm_grown.png",
}
const FARM_HARVEST_FOOD := 25

func _initialize_farmhouse_paths(farmhouse_node: Node2D) -> void:
	"""Find nearby unassigned farm tiles and create one job path per farm (max 1 worker/farm)."""
	if not is_instance_valid(farmhouse_node) or not is_instance_valid(map_objects_holder):
		return
	var jobs: Array = farmhouse_node.get_meta("resource_jobs", [])
	var max_workers: int = _get_worker_capacity("farmhouse")  # 6
	var assigned_farms: Array = []  # Track farm node names already pathed

	# Collect already-assigned farm targets from existing jobs
	for job in jobs:
		var rid: String = job.get("resource_id", "")
		if rid != "":
			assigned_farms.append(rid)

	var fh_tile: Vector2i = tilemap_layer.local_to_map(farmhouse_node.position)
	var max_radius := 30
	var slots_needed := max_workers - assigned_farms.size()

	# Walk the building list once instead of BFS-scanning every tile within range —
	# far cheaper since the map only has a handful of farms compared to hundreds of tiles.
	var candidates: Array = []
	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		if child.get_meta("building_type", "") != "farm":
			continue
		if child.name in assigned_farms:
			continue
		if child.get_meta("farm_worker_assigned", false):
			continue
		var child_tile: Vector2i = tilemap_layer.local_to_map(child.position)
		var dist := _hex_distance(fh_tile, child_tile)
		if dist > max_radius:
			continue
		candidates.append({"node": child, "dist": dist})

	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var found_farms: Array = []
	for candidate in candidates:
		if found_farms.size() >= slots_needed:
			break
		found_farms.append(candidate["node"])
		assigned_farms.append(candidate["node"].name)

	# Create job entries for each found farm
	for farm_node in found_farms:
		var farm_tile: Vector2i = tilemap_layer.local_to_map(farm_node.position)
		var tile_path: Array = _astar_pathfind_for_game(fh_tile, farm_tile)
		var world_path: Array = []
		for t in tile_path:
			world_path.append(tilemap_layer.map_to_local(t))

		var job_idx: int = jobs.size()
		var job := {
			"job_id":       "job_" + farmhouse_node.name + "_farm_" + str(job_idx),
			"path_id":      "path_" + farmhouse_node.name + "_farm_" + str(job_idx),
			"resource_id":  farm_node.name,
			"resource_type": "farm",
			"tile_path":    tile_path,
			"world_path":   world_path,
			"unit_assigned": null,
			"created_day":  0
		}
		jobs.append(job)
		farm_node.set_meta("farm_worker_assigned", true)
		DebugConfig.dprint("movement", ["Game: Farmhouse %s -> farm job to %s (%d tiles)" % [farmhouse_node.name, farm_node.name, tile_path.size()]])

	farmhouse_node.set_meta("resource_jobs", jobs)
	building_jobs_updated.emit(farmhouse_node.name)


func _register_farm_with_nearby_farmhouse(farm_node: Node2D) -> void:
	"""When a farm tile is placed, find the nearest farmhouse with a free job slot and add a path to it."""
	if not is_instance_valid(map_objects_holder):
		return
	var farm_tile: Vector2i = tilemap_layer.local_to_map(farm_node.position)
	var best_farmhouse: Node2D = null
	var best_dist: float = INF

	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		if child.get_meta("building_type", "") != "farmhouse":
			continue
		var jobs: Array = child.get_meta("resource_jobs", [])
		var max_cap: int = _get_worker_capacity("farmhouse")
		# Count only farm-type jobs (generic empty slots don't count against capacity)
		var farm_job_count := 0
		var already_claimed := false
		for j in jobs:
			if j.get("resource_type", "") == "farm":
				farm_job_count += 1
				if j.get("resource_id", "") == farm_node.name:
					already_claimed = true
		if already_claimed or farm_job_count >= max_cap:
			continue
		var dist: float = farm_node.position.distance_to(child.position)
		if dist < best_dist:
			best_dist = dist
			best_farmhouse = child

	if not is_instance_valid(best_farmhouse):
		DebugConfig.dprint("jobs", ["Game: No available farmhouse found for new farm ", farm_node.name])
		return

	var fh_tile: Vector2i = tilemap_layer.local_to_map(best_farmhouse.position)
	var tile_path: Array = _astar_pathfind_for_game(fh_tile, farm_tile)
	var world_path: Array = []
	for t in tile_path:
		world_path.append(tilemap_layer.map_to_local(t))

	var jobs: Array = best_farmhouse.get_meta("resource_jobs", [])
	# Replace the first empty non-farm slot, or append if none
	var inserted := false
	for i in range(jobs.size()):
		if jobs[i].get("resource_type", "") == "" and jobs[i].get("unit_assigned") == null:
			jobs[i] = {
				"job_id":        "job_" + best_farmhouse.name + "_farm_" + str(i),
				"path_id":       "path_" + best_farmhouse.name + "_farm_" + str(i),
				"resource_id":   farm_node.name,
				"resource_type": "farm",
				"tile_path":     tile_path,
				"world_path":    world_path,
				"unit_assigned": null,
				"created_day":   0
			}
			inserted = true
			break
	if not inserted:
		jobs.append({
			"job_id":        "job_" + best_farmhouse.name + "_farm_" + str(jobs.size()),
			"path_id":       "path_" + best_farmhouse.name + "_farm_" + str(jobs.size()),
			"resource_id":   farm_node.name,
			"resource_type": "farm",
			"tile_path":     tile_path,
			"world_path":    world_path,
			"unit_assigned": null,
			"created_day":   0
		})
	best_farmhouse.set_meta("resource_jobs", jobs)
	farm_node.set_meta("farm_worker_assigned", false)
	building_jobs_updated.emit(best_farmhouse.name)
	DebugConfig.dprint("jobs", ["Game: Registered farm %s with farmhouse %s (%d tiles)" % [farm_node.name, best_farmhouse.name, tile_path.size()]])


func _process_farm_states() -> void:
	"""Called each end-of-day. Advances farm tile states and harvests grown farms with workers."""
	if not is_instance_valid(map_objects_holder):
		return

	var total_food_harvested := 0

	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		if child.get_meta("building_type", "") != "farm":
			continue

		var state: String = child.get_meta("farm_state", "tilled")
		var has_worker: bool = child.get_meta("farm_worker_assigned", false)

		# Only cycle if a worker is assigned to this farm tile
		if not has_worker:
			continue

		if state == "grown":
			# Harvest!
			total_food_harvested += FARM_HARVEST_FOOD
			state = "tilled"
		else:
			var idx: int = FARM_CYCLE.find(state)
			if idx >= 0 and idx < FARM_CYCLE.size() - 1:
				state = FARM_CYCLE[idx + 1]

		child.set_meta("farm_state", state)
		_update_farm_texture(child, state)

	if total_food_harvested > 0:
		var res = players_data.get(1, {}).get("resources", {})
		res["food"] = res.get("food", 0) + total_food_harvested
		if is_instance_valid(game_log):
			var GL = preload("res://scripts/managers/game_log.gd")
			var day: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0
			game_log.add(day, GL.Category.INCOME,
				"🍞 Farms yielded +%d food this harvest." % total_food_harvested)
		DebugConfig.dprint("map_objects", ["Game: Farm harvest — +%d food" % total_food_harvested])


func _update_farm_texture(farm_node: Node2D, state: String) -> void:
	"""Swap the Sprite2D texture on a farm building to match its current state."""
	var tex_path: String = FARM_TEXTURES.get(state, FARM_TEXTURES["tilled"])
	if not ResourceLoader.exists(tex_path):
		return
	var sprite: Node = farm_node.get_node_or_null("Sprite2D")
	if is_instance_valid(sprite) and sprite is Sprite2D:
		sprite.texture = load(tex_path)
	elif farm_node is Sprite2D:
		farm_node.texture = load(tex_path)


func _get_farm_food_rate_for_player(player_id: int) -> int:
	"""Count grown farms with workers assigned to farmhouses owned by this player.
	Used to show a prospective harvest rate in the resource bar."""
	if not is_instance_valid(map_objects_holder):
		return 0
	var count := 0
	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		if child.get_meta("building_type", "") != "farm":
			continue
		if child.get_meta("owner_player", 1) != player_id:
			continue
		if child.get_meta("farm_worker_assigned", false) and child.get_meta("farm_state", "tilled") == "grown":
			count += 1
	return count * FARM_HARVEST_FOOD

func _get_hex_neighbors(tile: Vector2i) -> Array:
	"""Get the 6 neighboring hex tiles"""
	var neighbors = []
	
	# Hex grid offset coordinates neighbors depend on whether row is odd or even
	if tile.y % 2 == 0:  # Even rows
		neighbors = [
			Vector2i(tile.x + 1, tile.y),      # E
			Vector2i(tile.x - 1, tile.y),      # W
			Vector2i(tile.x, tile.y + 1),      # SE
			Vector2i(tile.x - 1, tile.y + 1),  # SW
			Vector2i(tile.x, tile.y - 1),      # NE
			Vector2i(tile.x - 1, tile.y - 1)   # NW
		]
	else:  # Odd rows
		neighbors = [
			Vector2i(tile.x + 1, tile.y),      # E
			Vector2i(tile.x - 1, tile.y),      # W
			Vector2i(tile.x + 1, tile.y + 1),  # SE
			Vector2i(tile.x, tile.y + 1),      # SW
			Vector2i(tile.x + 1, tile.y - 1),  # NE
			Vector2i(tile.x, tile.y - 1)       # NW
		]
	
	return neighbors

func _calculate_paths_to_resources(building_node: Node2D, resources: Array) -> Array:
	"""Calculate A* paths from building to each resource and return array of path objects"""
	var paths = []
	
	if not building_node or resources.is_empty():
		return paths
	
	var building_tile = tilemap_layer.local_to_map(building_node.position)
	
	for i in range(resources.size()):
		var resource = resources[i]
		var resource_tile = resource.get("tile_coords")
		
		# Calculate A* path from building to resource
		var path_tiles = _astar_pathfind_for_game(building_tile, resource_tile)
		
		if path_tiles.is_empty():
			DebugConfig.dprint("movement", ["Game: WARNING - No path found to resource at ", resource_tile])
			continue
		
		# Convert tile path to world coordinates
		var path_world = []
		for tile in path_tiles:
			path_world.append(tilemap_layer.map_to_local(tile))
		
		# Create unique path ID
		var path_id = "path_" + building_node.name + "_resource_" + str(i + 1)
		
		paths.append({
			"path_id": path_id,
			"resource_id": resource.get("id"),
			"resource_type": resource.get("type"),
			"tile_path": path_tiles,
			"world_path": path_world,
			"distance": path_tiles.size()
		})
		
		DebugConfig.dprint("movement", ["Game: Calculated path ", path_id, " to resource ", resource.get("id"), " (", path_tiles.size(), " tiles)"])
	
	return paths

func _start_world_creation_mode():
	DebugConfig.dprint("world_gen", ["Game: Starting world creation mode"])
	is_in_world_creation = true
	
	# Hide game header during world creation
	if game_header:
		game_header.visible = false
	if resource_bar:
		resource_bar.visible = false
	
	# Hide game footer during world creation
	if game_footer:
		game_footer.visible = false
	
	# Create world creator
	var WorldCreationModal = preload("res://scripts/main/world_creation_modal.gd")
	world_creator = WorldCreationModal.new()
	world_creator.name = "WorldCreationModal"
	add_child(world_creator)
	
	# Hide normal UI elements
	$UI_Layer/TurnControlsContainer.hide()
	
	# Setup world creator with direct UI control
	world_creator.setup_direct_ui(self, tilemap_layer, camera)
	
	DebugConfig.dprint("world_gen", ["Game: World creation mode active with direct UI control"])

func _setup_world_creation_delayed():
	# Remove this function - not needed with direct UI approach
	pass

func _connect_world_creation_buttons():
	# Remove this function - not needed with direct UI approach  
	pass

func _debug_print_ui_structure(node: Node, indent: int = 0):
	# Keep this for debugging if needed
	var indent_str = "  ".repeat(indent)
	DebugConfig.dprint("world_gen", ["%s%s" % [indent_str, node.name]])
	for child in node.get_children():
		_debug_print_ui_structure(child, indent + 1)

# Direct button handlers that call the world creator
func _on_world_creation_continue():
	DebugConfig.dprint("world_gen", ["Game: Continue button pressed!"])
	if world_creator and world_creator.has_method("_on_continue_pressed"):
		world_creator._on_continue_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _on_world_creation_back():
	DebugConfig.dprint("world_gen", ["Game: Back button pressed!"])
	if world_creator and world_creator.has_method("_on_back_pressed"):
		world_creator._on_back_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _finish_world_creation(generated_world_data: Dictionary):
	DebugConfig.dprint("world_gen", ["Game: Finishing world creation"])
	is_in_world_creation = false
	
	# Set start mode to new so units get created
	GameManager.start_mode = "new"
	unit_counter = 0  # Reset unit counter for new games
	
	# Use the generated world data
	world_data = generated_world_data.duplicate()
	current_save_path = ""
	
	# Close world creation modal
	ui_manager.close_world_creation_modal()
	
	# Clean up world creator
	if world_creator:
		world_creator.queue_free()
		world_creator = null
	
	# Proceed with normal game initialization first
	var loaded_day = 1
	turn_manager.set_day(loaded_day)
	_clear_and_draw_map()
	# Don't clear objects - they were placed during world creation
	# map_object_manager.clear_objects()
	# map_object_manager.place_objects(world_data)
	
	# Place the starting town center AFTER map objects are placed
	_place_starting_town_center()
	
	# Migrate any buildings with old naming (in case they were created during world creation)
	migrate_old_building_names()
	
	# Create initial units for new game from world creation
	_create_initial_units()

	# Auto-assign new units to available housing (town centre first)
	if GameManager.start_mode == "new" or GameManager.start_mode == "new_with_data":
		_auto_assign_all_units_to_housing()
	
	# Update population data after units are created
	for player_id in players_data.keys():
		if str(player_id) != "environment":
			update_player_population(player_id)
	
	# Show game header now that the game has started
	if game_header:
		game_header.visible = true
		DebugConfig.dprint("world_gen", ["Game: Game header now visible after world creation"])
	
	if resource_bar:
		resource_bar.visible = true
		resource_bar.refresh()
	
	# Show game footer now that the game has started
	if game_footer:
		game_footer.visible = true
		DebugConfig.dprint("world_gen", ["Game: Game footer now visible after world creation"])
	
	# Don't center camera - preserve current position from world creation
	# camera_controller.center_camera()
	DebugConfig.dprint("world_gen", ["Game: World creation complete, game ready."])

func _place_starting_town_center():
	# Get starting tile position from world data
	if not world_data.has("starting_tile"):
		DebugConfig.dprint("world_gen", ["Warning: No starting tile found in world data"])
		return
		
	var starting_tile = world_data["starting_tile"]
	var tile_coords = Vector2i(int(starting_tile.x), int(starting_tile.y))
	DebugConfig.dprint("world_gen", ["Game: Placing town center at tile: ", tile_coords])
	
	# Clear any existing terrain features at this tile
	_clear_tile_features(tile_coords)
	
	# Place the town center building
	_place_town_center_building(tile_coords)

func _clear_tile_features(tile_coords: Vector2i):
	# Remove any objects (trees, mountains) at this tile
	if map_object_manager and map_object_manager.has_method("remove_object_at_tile"):
		map_object_manager.remove_object_at_tile(tile_coords)
	
	# Clear any terrain modifiers from world_data
	var coord_key = tile_coords
	if world_data.has(coord_key):
		var tile_data = world_data[coord_key]
		if typeof(tile_data) == TYPE_DICTIONARY:
			# Keep the base terrain but remove any modifiers
			DebugConfig.dprint("world_gen", ["Game: Cleared features from tile: ", tile_coords])

func _place_town_center_building(tile_coords: Vector2i):
	# Get player race and building choice
	var player_data = world_data.get("player_data", {})
	var selected_race = player_data.get("race", "human")
	var starting_building = player_data.get("starting_building", "town_center")
	
	DebugConfig.dprint("world_gen", ["Game: Placing ", starting_building, " for race ", selected_race, " at ", tile_coords])
	
	# Load the town center texture
	var building_texture_path = "res://assets/buildings/human_towncentre-export.png"
	if starting_building == "fishing_hut":
		building_texture_path = "res://assets/buildings/human_finshinghut.png"
	elif starting_building == "barracks":
		building_texture_path = "res://assets/buildings/human_barracks.png"
	elif starting_building == "house":
		building_texture_path = "res://assets/buildings/human_house.png"
	
	# Create the building using proper scene
	if ResourceLoader.exists(building_texture_path):
		# Generate unique building name (town centers are special)
		var building_id = _get_next_building_id("town_center")
		var building_name = "town_center" + str(building_id)
		
		var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
		building_scene.name = building_name
		
		# Position it at the upside-down triangle meeting point (midpoint between the two tiles above)
		var tile_above_left = tilemap_layer.map_to_local(Vector2i(tile_coords.x - 1, tile_coords.y - 1))
		var tile_above_right = tilemap_layer.map_to_local(Vector2i(tile_coords.x, tile_coords.y - 1))
		var world_pos = (tile_above_left + tile_above_right) / 2.0
		building_scene.position = world_pos
		building_scene.z_index = 5  # Above terrain but below UI
		
		# Setup building with all data including texture
		var setup_data = {
			"type": starting_building,
			"texture_path": building_texture_path,
			"owner_player": 1,  # Player 1
			"building_type": starting_building,
			"construction_day": turn_manager.get_day()
		}
		
		if building_scene.has_method("setup"):
			building_scene.setup(setup_data)
		
		# Add to map objects holder
		map_objects_holder.add_child(building_scene)
		
		# Set the display name from settlement name if available
		var settlement_name = player_data.get("settlement_name", "")
		if not settlement_name.is_empty():
			building_scene.set_meta("display_name", settlement_name)
			DebugConfig.dprint("world_gen", ["Game: Set town center display name to: ", settlement_name])
		
		# Add building to player's buildings list
		var owner_player = setup_data.get("owner_player", 1)
		if players_data.has(owner_player):
			players_data[owner_player]["buildings"].append(building_name)
			# Track town centre world position so unassigned units can idle nearby
			players_data[owner_player]["town_centre_position"] = world_pos
			DebugConfig.dprint("world_gen", ["Game: Added town center ", building_name, " to player ", owner_player, " buildings list"])
		
		DebugConfig.dprint("world_gen", ["Game: Successfully placed ", starting_building, " at world position: ", world_pos])
	else:
		DebugConfig.dprint("world_gen", ["Warning: Could not find building texture: ", building_texture_path])

func _setup_game_header():
	# Create and setup the game header
	var GameHeaderScript = preload("res://scripts/managers/game_header.gd")
	game_header = GameHeaderScript.new()
	ui_layer.add_child(game_header)
	
	# Header is visible by default
	
	# Connect header signals to existing UI manager functions
	game_header.settings_pressed.connect(_on_header_settings_pressed)
	game_header.players_pressed.connect(_on_header_players_pressed)
	game_header.resources_pressed.connect(_on_header_resources_pressed)
	game_header.buildings_pressed.connect(_on_header_buildings_pressed)
	game_header.population_pressed.connect(_on_header_population_pressed)
	game_header.army_pressed.connect(_on_header_army_pressed)
	game_header.units_pressed.connect(_on_header_units_pressed)
	game_header.science_pressed.connect(_on_header_science_pressed)
	game_header.encyclopedia_pressed.connect(_on_header_encyclopedia_pressed)
	game_header.log_pressed.connect(_on_header_log_pressed)
	game_header.graphs_pressed.connect(_on_header_graphs_pressed)
	
	# No need to update values anymore
	DebugConfig.dprint("ui", ["Game: Game header created and connected"])
	
	# Setup resource bar (sits directly under header)
	var ResourceBarScript = preload("res://scripts/managers/resource_bar.gd")
	resource_bar = ResourceBarScript.new()
	resource_bar.game_ref = self
	ui_layer.add_child(resource_bar)
	# Refresh resource bar whenever any building's jobs change
	building_jobs_updated.connect(func(_bname: String): if is_instance_valid(resource_bar): resource_bar.refresh())
	
	# Setup info modals
	_setup_info_modals()
	
	# Setup game footer
	_setup_game_footer()

func _restore_buildings_with_proper_centering(buildings_data: Array):
	# Restore buildings from save data
	
	# Clear any existing buildings to avoid duplicates
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child):
				child.queue_free()
	
	# Reset building counters and rebuild them from saved data
	building_counter.clear()
	
	# Clear and rebuild player building lists
	for player_id in players_data:
		if str(player_id) != "environment":
			players_data[player_id]["buildings"].clear()
	
	# Restore each building using proper building scenes
	for building_info in buildings_data:
		if building_info.has("texture_path") and ResourceLoader.exists(building_info["texture_path"]):
			# Extract building type from saved building type or derive from name
			var building_type = building_info.get("building_type", "unknown")
			if building_type == "unknown":
				building_type = _extract_building_type_from_name(building_info.get("name", ""))
			
			# Generate proper building name and update counter
			var building_id = _get_next_building_id(building_type)
			var building_name = building_type + str(building_id)
			
			# Create building using proper scene
			var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
			building_scene.name = building_name
			
			# Extract tile coordinates from saved position
			var saved_pos = building_info.get("position", Vector2.ZERO)
			var tile_coords = tilemap_layer.local_to_map(saved_pos)
			
			# Position building at tile center (building script will handle sprite centering)
			var tile_center_pos = tilemap_layer.map_to_local(tile_coords)
			building_scene.position = tile_center_pos
			
			# Setup building with all data including texture and occupancy
			var setup_data = {
				"type": building_type,
				"texture_path": building_info["texture_path"],
				"owner_player": building_info.get("owner_player", 1),
				"building_type": building_type,
				"construction_day": building_info.get("construction_day", 0),
				"living_occupancy": building_info.get("living_occupancy", 0),
				"worker_occupancy": building_info.get("worker_occupancy", 0)
			}
			
			# Add barracks-specific occupancy if present (single job type: station)
			if building_type == "barracks":
				setup_data["station_occupancy"] = building_info.get("station_occupancy", 0)
			
			if building_scene.has_method("setup"):
				building_scene.setup(setup_data)
			
			# Set occupancy metadata on the building node
			building_scene.set_meta("living_occupancy", building_info.get("living_occupancy", 0))
			building_scene.set_meta("worker_occupancy", building_info.get("worker_occupancy", 0))
			
			# Set barracks-specific occupancy if present
			if building_type == "barracks":
				building_scene.set_meta("station_occupancy", building_info.get("station_occupancy", 0))
			
			# Restore farm state if it's a farm tile
			if building_type == "farm":
				var saved_state: String = building_info.get("farm_state", "tilled")
				if saved_state.is_empty():
					saved_state = "tilled"
				building_scene.set_meta("farm_state", saved_state)
				building_scene.set_meta("farm_worker_assigned", building_info.get("farm_worker_assigned", false))
				# Apply the correct texture for the restored state
				_update_farm_texture(building_scene, saved_state)
			
			# Initialize jobs array (load from save if available, otherwise create empty)
			var saved_jobs = building_info.get("resource_jobs", [])
			building_scene.set_meta("resource_jobs", saved_jobs)
			
			# Restore display name if it was saved (lore-based naming)
			if building_info.has("display_name") and not building_info["display_name"].is_empty():
				building_scene.set_meta("display_name", building_info["display_name"])
			
			# Restore marauder camp state (raid timer + defender HP) if present
			if building_type == "barracks":
				var saved_next_attack_day: int = building_info.get("next_attack_day", -1)
				if saved_next_attack_day >= 0:
					building_scene.set_meta("next_attack_day", saved_next_attack_day)
				var saved_enemy_hp: int = building_info.get("enemy_hp", -1)
				if saved_enemy_hp >= 0:
					building_scene.set_meta("enemy_hp", saved_enemy_hp)
			
			# Auto-create jobs if they're missing (use max capacity, not current occupancy)
			if saved_jobs.is_empty():
				var max_capacity = _get_worker_capacity(building_type)
				if max_capacity > 0:
					_create_jobs_for_worker_capacity(building_scene, max_capacity)
					_initialize_job_paths_on_load(building_scene)
			else:
				# Jobs were saved - only reinitialize paths if they're missing
				var jobs_need_paths = false
				for job in saved_jobs:
					if job.get("path_id", "").is_empty():
						jobs_need_paths = true
						break
				if jobs_need_paths:
					_initialize_job_paths_on_load(building_scene)
			
			building_scene.z_index = building_info.get("z_index", 5)
			map_objects_holder.add_child(building_scene)
			
			# Add building to player's buildings list
			var owner_player = setup_data.get("owner_player", 1)
			if players_data.has(owner_player):
				players_data[owner_player]["buildings"].append(building_name)
				if building_type == "town_center":
					players_data[owner_player]["town_centre_position"] = tile_center_pos
		else:
			push_warning("Could not restore building with texture: " + building_info.get("texture_path", "unknown"))

func _restore_environment_objects(environment_objects_data: Array):
	# Restore environment objects (mountains, trees, and fish) with their unique IDs.
	# Spawns nodes at exact saved positions, then rebuilds tracking dicts.

	if not tilemap_layer or not map_objects_holder:
		DebugConfig.dprint("save_load", ["Warning: Cannot restore environment objects - missing tilemap or objects holder"])
		return

	# Spawn nodes at saved positions (no RNG, no register_* side-effects)
	map_object_manager.place_objects_from_save(environment_objects_data)

	# Reset tracking dicts before repopulating
	players_data["environment"]["objects"]["mountains"] = {}
	players_data["environment"]["objects"]["trees"] = {}
	if not players_data["environment"]["objects"].has("fish"):
		players_data["environment"]["objects"]["fish"] = {}
	else:
		players_data["environment"]["objects"]["fish"] = {}
	players_data["environment"]["counts"]["mountains"] = 0
	players_data["environment"]["counts"]["trees"] = 0
	if not players_data["environment"]["counts"].has("fish"):
		players_data["environment"]["counts"]["fish"] = 0
	else:
		players_data["environment"]["counts"]["fish"] = 0

	for obj_info in environment_objects_data:
		var obj_position = obj_info.get("position", Vector2.ZERO)
		var environment_id = obj_info.get("environment_id", obj_info.get("name", ""))
		var object_type = obj_info.get("object_type", "unknown")

		# Find the node we just spawned at this position
		var existing_node: Node2D = null
		for child in map_objects_holder.get_children():
			if child.position.distance_to(obj_position) < 1.0 and not child.has_meta("environment_id"):
				existing_node = child
				break

		if not existing_node:
			push_warning("Could not find spawned node for environment object: " + environment_id)
			continue

		# Tag and rename
		existing_node.name = environment_id
		existing_node.set_meta("environment_id", environment_id)

		# Rebuild tracking entry
		var tile_coords = tilemap_layer.local_to_map(existing_node.position)
		var entry = {
			"name": environment_id,
			"position": existing_node.position,
			"tile_coords": tile_coords,
			"node_path": existing_node.get_path(),
			"job": null
		}

		match object_type:
			"mountain":
				players_data["environment"]["objects"]["mountains"][environment_id] = entry
				players_data["environment"]["counts"]["mountains"] += 1
			"tree":
				players_data["environment"]["objects"]["trees"][environment_id] = entry
				players_data["environment"]["counts"]["trees"] += 1
			"fish":
				players_data["environment"]["objects"]["fish"][environment_id] = entry
				players_data["environment"]["counts"]["fish"] += 1

	DebugConfig.dprint("save_load", ["Game: Restored %d environment objects." % environment_objects_data.size()])

func _auto_assign_jobs_on_load():
	"""Auto-assign units to jobs based on worker occupancy levels when loading a save"""
	DebugConfig.dprint("jobs", ["Game: Starting auto-assign jobs on load"])
	
	# Clear all resource job markers before pathfinding (prevents stale job assignments from interfering)
	_clear_all_resource_job_markers()
	
	# Work building types that have jobs
	var work_buildings = ["lumberjack", "stoneworker", "fishing_hut", "research", "lumber_mill"]
	
	# Iterate through all buildings in map_objects_holder
	for building_node in map_objects_holder.get_children():
		if not _is_building_node(building_node):
			continue
		
		var building_type = building_node.get_meta("building_type", "unknown")
		if not building_type in work_buildings:
			continue
		
		var worker_occupancy = building_node.get_meta("worker_occupancy", 0)
		if worker_occupancy == 0:
			continue
		
		# Get existing jobs or create them if missing (use max capacity, not current occupancy)
		var jobs = building_node.get_meta("resource_jobs", [])
		if jobs.is_empty():
			var max_capacity = _get_worker_capacity(building_type)
			if max_capacity > 0:
				_create_jobs_for_worker_capacity(building_node, max_capacity)
				jobs = building_node.get_meta("resource_jobs", [])
		
		# Initialize paths to resources for jobs on load - BUT ONLY if they don't already have paths
		# This prevents recalculation on each reload which causes resources to shift
		var needs_path_init = false
		for job in jobs:
			if job.get("tile_path", []).is_empty():
				needs_path_init = true
				break
		
		if needs_path_init:
			DebugConfig.dprint("jobs", ["DEBUG: Jobs missing paths - initializing paths on load"])
			_initialize_job_paths_on_load(building_node)
		else:
			DebugConfig.dprint("jobs", ["DEBUG: Jobs already have paths - skipping path initialization"])
		
		# Re-get jobs after potential path initialization
		jobs = building_node.get_meta("resource_jobs", [])
		
		# Now auto-assign units to any unassigned job slots
		var owner_player = building_node.get_meta("owner_player", 1)
		if not players_data.has(owner_player):
			continue
		
		var player_units = players_data[owner_player].get("units", [])
		var jobs_assigned = 0
		
		# FIRST: Sync existing unit assignments to job objects
		# Units that already have job = building_name should have their corresponding job marked
		for unit in player_units:
			if unit.get("job") == building_node.name:
				# This unit is already assigned to this building
				# Check if job object tracks this unit
				var unit_tracked = false
				for job in jobs:
					if job.get("unit_assigned") == unit["unique_id"]:
						unit_tracked = true
						break
				
				# If not tracked, mark the first unassigned job with this unit
				if not unit_tracked:
					for job in jobs:
						if job.get("unit_assigned") == null:
							job["unit_assigned"] = unit["unique_id"]
							jobs_assigned += 1
							DebugConfig.dprint("jobs", ["Game: Synced existing unit ", unit["unique_id"], " to job at ", building_node.name, " on load"])
							break
		
		# SECOND: Assign remaining unassigned units to remaining unassigned jobs
		var remaining_slots = worker_occupancy - jobs_assigned
		if remaining_slots > 0:
			for unit in player_units:
				if remaining_slots <= 0:
					break
				
				# Skip units that already have jobs
				if unit.get("job") != null:
					continue
				
				# Find an unassigned job slot
				for job in jobs:
					if job.get("unit_assigned") == null:
						# Assign unit to this job
						unit["job"] = building_node.name
						job["unit_assigned"] = unit["unique_id"]
						
						# Cache building connections for the unit
						if buildings_connections_cache.has(building_node.name):
							unit["job_connections"] = buildings_connections_cache[building_node.name]
						else:
							var connections = _find_building_connections_for_unit(building_node)
							unit["job_connections"] = connections
							buildings_connections_cache[building_node.name] = connections
						
						# If unit now has both assignments, start the work cycle
						if unit.get("living_quarters", null) != null:
							unit["movement_state"] = "idle"
							unit["movement_cycle_step"] = 0
							unit["current_path"] = []
							unit["work_timer"] = 0.0
						
						remaining_slots -= 1
						DebugConfig.dprint("jobs", ["Game: Auto-assigned unit ", unit["unique_id"], " to job at ", building_node.name, " on load"])
						break
		
		# Persist the updated jobs back to building metadata
		building_node.set_meta("resource_jobs", jobs)
		
		# Check if this workplace needs to be renamed (if it has workers assigned and hasn't been renamed yet)
		# Get the first assigned unit to use its surname
		var first_assigned_unit = null
		for job in jobs:
			if job.get("unit_assigned") != null:
				# Find the unit with this unique_id
				for unit in player_units:
					if unit["unique_id"] == job.get("unit_assigned"):
						first_assigned_unit = unit
						break
				if first_assigned_unit:
					break
		
		if first_assigned_unit:
			_rename_workplace_on_first_assignment(building_node, first_assigned_unit)
		
		DebugConfig.dprint("jobs", ["Game: Assigned ", jobs_assigned, " units to jobs at ", building_node.name, " on load"])

func _setup_game_footer():
	# Create and setup the game footer
	var GameFooterScript = preload("res://scripts/managers/game_footer.gd")
	game_footer = GameFooterScript.new()
	ui_layer.add_child(game_footer)
	
	# Connect footer signals
	game_footer.build_pressed.connect(_on_build_pressed)
	game_footer.slow_pressed.connect(_on_slow_pressed)
	game_footer.pause_pressed.connect(_on_pause_pressed)
	game_footer.speedup_pressed.connect(_on_speedup_pressed)
	game_footer.end_day_pressed.connect(_on_end_day_pressed)
	game_footer.end_day_blocked_pressed.connect(_on_end_day_blocked_pressed)
	
	# Set initial day label
	if game_footer:
		game_footer.set_day_text(1)
	
	DebugConfig.dprint("ui", ["Game: Game footer created and connected"])

func _setup_info_modals():
	# Create info modals with different starting positions
	var PlayersModalScript = preload("res://scripts/ui/players_modal.gd")
	var ResourcesModalScript = preload("res://scripts/ui/resources_modal.gd")
	var BuildingsModalScript = preload("res://scripts/ui/buildings_modal.gd")
	var PopulationModalScript = preload("res://scripts/ui/population_modal.gd")
	var ArmyModalScript = preload("res://scripts/ui/army_modal.gd")
	var UnitsModalScript = preload("res://scripts/ui/units_modal.gd")
	var ScienceModalScript = preload("res://scripts/ui/science_modal.gd")
	var SettingsModalScript = preload("res://scripts/ui/settings_modal.gd")
	var EncyclopediaModalScript = preload("res://scripts/ui/encyclopedia_modal.gd")
	
	# Calculate positions to prevent overlap
	var base_pos = Vector2(10, 60)  # Base position under header
	var modal_offset = Vector2(50, 50)  # Offset for each new modal
	
	players_modal = PlayersModalScript.new(self, base_pos)
	resources_modal = ResourcesModalScript.new(self, base_pos + modal_offset)
	buildings_modal = BuildingsModalScript.new(self, base_pos + modal_offset * 2)
	population_modal = PopulationModalScript.new(self, base_pos + modal_offset * 3)
	army_modal = ArmyModalScript.new(self, base_pos + modal_offset * 4)
	units_modal = UnitsModalScript.new(self, base_pos + modal_offset * 5)
	science_modal = ScienceModalScript.new(self, base_pos + modal_offset * 6)
	settings_modal = SettingsModalScript.new(self, base_pos + modal_offset * 7)
	encyclopedia_modal = EncyclopediaModalScript.new()
	var LogModalScript = preload("res://scripts/ui/log_modal.gd")
	log_modal = LogModalScript.new(game_log, self)
	var GraphsModalScript = preload("res://scripts/ui/graphs_modal.gd")
	graphs_modal = GraphsModalScript.new(game_log)
	
	# Add modals to UI layer
	ui_layer.add_child(players_modal)
	ui_layer.add_child(resources_modal)
	ui_layer.add_child(buildings_modal)
	ui_layer.add_child(population_modal)
	ui_layer.add_child(army_modal)
	ui_layer.add_child(units_modal)
	ui_layer.add_child(science_modal)
	ui_layer.add_child(settings_modal)
	ui_layer.add_child(encyclopedia_modal)
	ui_layer.add_child(log_modal)
	ui_layer.add_child(graphs_modal)

	# Day transition overlay — added last so it renders above everything
	var DayTransitionScript = preload("res://scripts/ui/day_transition.gd")
	day_transition = DayTransitionScript.new()
	ui_layer.add_child(day_transition)

	# Game over modal — full-screen overlay, added last so it renders on top
	var GameOverModalScript = preload("res://scripts/ui/game_over_modal.gd")
	game_over_modal = GameOverModalScript.new(self)
	ui_layer.add_child(game_over_modal)

	# Turn events modal — sits just above the footer
	var TurnEventsModalScript = preload("res://scripts/ui/turn_events_modal.gd")
	turn_events_modal = TurnEventsModalScript.new(turn_event_manager)
	ui_layer.add_child(turn_events_modal)

	# Notification panel — right-side vertical card stack above the footer
	var NotificationPanelScript = preload("res://scripts/ui/notification_panel.gd")
	notification_panel = NotificationPanelScript.new()
	ui_layer.add_child(notification_panel)
	notification_panel.notification_clicked.connect(_on_notification_clicked)

	# World event modal — presents random events with choices
	var WorldEventModalScript = preload("res://scripts/ui/world_event_modal.gd")
	world_event_modal = WorldEventModalScript.new(self)
	ui_layer.add_child(world_event_modal)
	
	# Connect modal close signals (optional)
	players_modal.modal_closed.connect(_on_modal_closed)
	resources_modal.modal_closed.connect(_on_modal_closed)
	buildings_modal.modal_closed.connect(_on_modal_closed)
	population_modal.modal_closed.connect(_on_modal_closed)
	army_modal.modal_closed.connect(_on_modal_closed)
	units_modal.modal_closed.connect(_on_modal_closed)
	science_modal.modal_closed.connect(_on_modal_closed)
	settings_modal.modal_closed.connect(_on_modal_closed)
	
	DebugConfig.dprint("ui", ["Game: Info modals setup complete"])

func _on_modal_closed(modal_type: String):
	DebugConfig.dprint("ui", ["Game: Modal closed: ", modal_type])

func _on_end_day_blocked_pressed():
	"""Show a small popup reminding the player to resolve the pending event."""
	var dialog = AcceptDialog.new()
	dialog.title = "Event Pending"
	dialog.dialog_text = "You must resolve the pending event before ending the day."
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _on_end_day_pressed():
	DebugConfig.dprint("ui", ["Game: End day pressed"])
	# Play the day wipe transition
	if is_instance_valid(day_transition):
		day_transition.play()
	# Call turn manager to end the turn
	if is_instance_valid(turn_manager):
		# Clear stale events from the previous turn before processing this one
		if is_instance_valid(turn_event_manager):
			turn_event_manager.clear()
		# Forget yesterday's resolved event ids so a repeat of the same event type isn't stuck "already resolved"
		if is_instance_valid(world_event_modal):
			world_event_modal.clear_resolved_events()

		var day_before: int = turn_manager.get_day()
		turn_manager.end_turn()
		# Update the footer day label with new day
		if game_footer:
			game_footer.set_day_text(turn_manager.get_day())
		
		# Process farm state cycle and harvest grown farms
		_process_farm_states()
		
		# Log resource income for the day that just ended
		if is_instance_valid(game_log):
			var rates = get_resource_rates(1)
			var GL = preload("res://scripts/managers/game_log.gd")
			var ICONS = {
				"gold":    "[color=#C8A400]●[/color]",
				"food":    "🍞",
				"wood":    "🌲",
				"stone":   "[color=#8C8C8C]■[/color]",
				"science": "🔬"
			}
			var parts: Array = []
			for key in ["gold", "food", "wood", "stone", "science"]:
				var val: int = int(rates.get(key, 0))
				if val != 0:
					var sign := "+" if val > 0 else ""
					parts.append("%s%s%d" % [ICONS.get(key, key), sign, val])
			var totals: Array = []
			var res = players_data.get(1, {}).get("resources", {})
			for key in ["gold", "food", "wood", "stone", "science"]:
				totals.append("%s%d" % [ICONS.get(key, key), int(res.get(key, 0))])
			var msg := ""
			if parts.is_empty():
				msg = "📈 No income this turn.   Totals: " + "  ".join(totals)
			else:
				msg = "📈 Income: " + "  ".join(parts) + "   |   Totals: " + "  ".join(totals)
			# Snapshot of current resource totals for the graphs modal
			var snap := {}
			for rk in ["food", "wood", "stone", "gold", "science"]:
				snap[rk] = int(res.get(rk, 0))
			game_log.add(day_before, GL.Category.INCOME, msg, {"bbcode": true, "resource_snapshot": snap})
		
		# Process training progress for all units
		_process_training_progress()
		
		# Refresh open modals to show updated data
		if resources_modal and resources_modal.is_open:
			resources_modal.refresh_content()
		if population_modal and population_modal.is_open:
			population_modal.refresh_content()
		if buildings_modal and buildings_modal.is_open:
			buildings_modal.refresh_content()
		if building_details_modal and is_instance_valid(building_details_modal):
			if building_details_modal.building_node and is_instance_valid(building_details_modal.building_node):
				building_details_modal.setup_building_details(building_details_modal.building_node)
		# Always refresh the resource bar
		if resource_bar:
			resource_bar.refresh()

		# Tick wave spawner — may trigger a new enemy wave
		if is_instance_valid(wave_spawner):
			wave_spawner.on_day_end(turn_manager.get_day())

		# Keep an open combat modal's raid countdown in sync with the new day
		if is_instance_valid(active_combat_modal) and active_combat_modal.visible:
			active_combat_modal.refresh_raid_timer()

		# Fire a random world event each turn
		_fire_random_world_event()

		# Fire pop growth notification after the world event
		if _pending_pop_growth > 0:
			var grew := _pending_pop_growth
			_pending_pop_growth = 0
			var new_total: int = players_data.get(1, {}).get("population", {}).get("total", 0)
			var citizen_word := "citizen" if grew == 1 else "citizens"
			if is_instance_valid(notification_panel):
				notification_panel.push(
					"Population Boom! +%d %s" % [grew, citizen_word],
					"Population is now %d. Build more housing to keep growing." % new_total,
					"👶",
					Color(0.35, 0.75, 1.0)
				)
			check_population_achievements()

		# Daily achievement checks
		check_day_achievements()

func _on_notification_clicked(data: Dictionary):
	var action = data.get("action", "")
	match action:
		"pan_to":
			# Pan camera to the stored world position
			var world_pos: Vector2 = data.get("world_pos", Vector2.ZERO)
			if world_pos != Vector2.ZERO and is_instance_valid(camera_controller):
				camera_controller.pan_to(world_pos, 2.5)
		"open_event":
			# Show the world event modal with the stored event data
			var event_data: Dictionary = data.get("event_data", {})
			if not event_data.is_empty() and is_instance_valid(world_event_modal):
				world_event_modal.show_event(event_data, true)
		_:
			# Generic: open turn events modal
			if is_instance_valid(turn_events_modal) and not turn_events_modal.is_open:
				turn_events_modal.toggle()

func trigger_wave_from_event():
	"""Spawn an unscheduled marauder barracks immediately (called from world event effects)."""
	if is_instance_valid(wave_spawner):
		wave_spawner.wave_number += 1
		wave_spawner._spawn_wave(wave_spawner.wave_number)

# ─── Achievements ─────────────────────────────────────────────────────────────

func _try_unlock_achievement(id: String) -> void:
	"""Unlock an achievement, log it, and show a notification if newly achieved."""
	if AchievementManager.is_unlocked(id):
		return
	if not AchievementManager.unlock(id):
		return

	var ach_data: Dictionary = {}
	for ach in AchievementManager.ACHIEVEMENTS:
		if ach["id"] == id:
			ach_data = ach
			break

	var title: String = ach_data.get("title", id)
	var icon: String  = ach_data.get("icon", "🏆")
	var desc: String  = ach_data.get("desc", "")
	var day: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0

	# Log entry
	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(day, GL.Category.EVENT,
			"%s 🏆 Achievement Unlocked: %s — %s" % [icon, title, desc])

	# Notification card
	if is_instance_valid(notification_panel):
		notification_panel.push(
			"🏆 Achievement Unlocked!",
			"%s — %s" % [title, desc],
			icon,
			Color(0.85, 0.72, 0.10)  # gold
		)

func check_day_achievements() -> void:
	var day: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0
	if day >= 50:
		_try_unlock_achievement("survive_50_days")
	if day >= 100:
		_try_unlock_achievement("survive_100_days")

func check_population_achievements() -> void:
	var pop: int = players_data.get(1, {}).get("population", {}).get("total", 0)
	if pop >= 25:
		_try_unlock_achievement("pop_25")
	if pop >= 50:
		_try_unlock_achievement("pop_50")

func check_workforce_achievements() -> void:
	"""Check lumberjack/stoneworker/fisher/farmer workforce milestones."""
	if not players_data.has(1) or not map_objects_holder:
		return
	var units: Array = players_data[1].get("units", [])

	# Count workers and buildings per type
	var type_workers := {"lumberjack": 0, "lumber_mill": 0, "stoneworker": 0, "fishing_hut": 0, "farmhouse": 0}
	var type_buildings := {"lumberjack": 0, "lumber_mill": 0, "stoneworker": 0, "fishing_hut": 0, "farmhouse": 0}

	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		var btype: String = child.get_meta("building_type", "")
		if type_buildings.has(btype):
			type_buildings[btype] += 1

	for unit in units:
		if unit.get("is_pet", false) or unit.get("job") == null:
			continue
		var job: String = unit["job"]
		for btype in type_workers.keys():
			if job.begins_with(btype):
				type_workers[btype] += 1
				break

	var lumber_workers: int = type_workers["lumberjack"] + type_workers["lumber_mill"]
	var lumber_buildings: int = type_buildings["lumberjack"] + type_buildings["lumber_mill"]
	if lumber_workers >= 25 and lumber_buildings >= 5:
		_try_unlock_achievement("lumber_workforce")

	if type_workers["stoneworker"] >= 25 and type_buildings["stoneworker"] >= 5:
		_try_unlock_achievement("stone_workforce")

	if type_workers["fishing_hut"] >= 25 and type_buildings["fishing_hut"] >= 5:
		_try_unlock_achievement("fish_workforce")

	if type_workers["farmhouse"] >= 25 and type_buildings["farmhouse"] >= 5:
		_try_unlock_achievement("farm_workforce")

func check_building_achievements() -> void:
	if not map_objects_holder:
		return
	var house_count: int = 0
	var wonder_count: int = 0
	for child in map_objects_holder.get_children():
		if not _is_building_node(child):
			continue
		match child.get_meta("building_type", ""):
			"house":   house_count += 1
			"wonder":  wonder_count += 1
	if house_count >= 5:
		_try_unlock_achievement("build_5_houses")
	if wonder_count >= 1:
		_try_unlock_achievement("build_wonder")

func check_research_achievements() -> void:
	var techs: Dictionary = players_data.get(1, {}).get("technologies", {})
	var any_unlocked := false
	var all_unlocked := true
	for val in techs.values():
		if int(val) > 0:
			any_unlocked = true
		else:
			all_unlocked = false
	if any_unlocked:
		_try_unlock_achievement("research_any")
	if all_unlocked and not techs.is_empty():
		_try_unlock_achievement("research_all")

# ─── Pet system ───────────────────────────────────────────────────────────────

const PET_NAMES := {
	"dog": ["Rex", "Buddy", "Max", "Charlie", "Daisy", "Duke", "Rusty", "Bella"],
	"cat": ["Whiskers", "Shadow", "Mittens", "Simba", "Luna", "Oreo", "Salem", "Tom"]
}

func add_pet_companion(player_id: int, pet_type: String = "cat"):
	"""Spawn an additional wandering companion pet for a player (used by world events)."""
	if not players_data.has(player_id):
		return
	if not players_data[player_id].has("units"):
		players_data[player_id]["units"] = []
	var uid: String = _get_next_unit_id()
	var anchor: Vector2 = _get_player_town_centre_position(player_id)
	var scatter_angle: float = randf() * TAU
	var scatter_dist: float = randf_range(20.0, 60.0)
	var spawn_pos: Vector2 = anchor + Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_dist
	var names: Array = PET_NAMES.get(pet_type, PET_NAMES["cat"])
	var pet_name: String = names[randi() % names.size()]
	var unit_data: Dictionary = {
		"unique_id": uid,
		"name": pet_name,
		"type": "peasant",
		"is_pet": true,
		"pet_type": pet_type,
		"race": players_data[player_id].get("race", "human"),
		"gender": "male",
		"player_id": player_id,
		"position": spawn_pos,
		"living_quarters": null,
		"job": null,
		"assigned_job_index": -1,
		"previous_job": null,
		"job_connections": [],
		"current_path": [],
		"path_index": 0,
		"movement_state": "idle_wander",
		"movement_target": null,
		"movement_cycle_step": 0,
		"work_timer": randf_range(0.0, 3.0),
		"wander_wait_time": randf_range(1.0, 4.0),
		"movement_speed": 20.0,
		"speed_multiplier": randf_range(0.85, 0.95),
		"sprite_id": uid,
		"specialties": [],
		"training": null,
		"pet_cooldown_day": 0
	}
	players_data[player_id]["units"].append(unit_data)
	_spawn_event_unit_sprite(unit_data)
	DebugConfig.dprint("general", ["Game: Event added new %s companion '%s' for player %d" % [pet_type, pet_name, player_id]])

func _on_pet_clicked(pet: Dictionary) -> void:
	"""Open the pet interaction prompt when the player clicks their companion."""
	# Always look up the live dict from players_data so cooldown reads/writes persist
	var uid: String = pet.get("unique_id", "")
	var live_pet: Dictionary = pet
	for unit in players_data.get(1, {}).get("units", []):
		if unit.get("unique_id", "") == uid:
			live_pet = unit
			break
	
	var pet_name: String = live_pet.get("name", "your companion")
	var today: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0
	var last_petted: int = live_pet.get("pet_cooldown_day", 0)
	
	# Build popup on UI layer
	var popup = PanelContainer.new()
	popup.name = "PetPopup"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	style.border_color = Color(0.7, 0.5, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	var title = Label.new()
	title.text = "🐾  %s is nearby!" % pet_name
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var already_today = (last_petted == today and today > 0)
	var msg_label = Label.new()
	if already_today:
		msg_label.text = "%s already had enough attention today.\nCome back tomorrow!" % pet_name
	else:
		msg_label.text = "Take a moment to pet %s?" % pet_name
	msg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	msg_label.add_theme_font_size_override("font_size", 13)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(msg_label)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)
	
	if not already_today:
		var yes_btn = Button.new()
		yes_btn.text = "🐾 Pet %s" % pet_name
		yes_btn.custom_minimum_size = Vector2(130, 32)
		btn_row.add_child(yes_btn)
		yes_btn.pressed.connect(func():
			_pet_the_companion(live_pet)
			popup.queue_free()
		)
	
	var no_btn = Button.new()
	no_btn.text = "Not now"
	no_btn.custom_minimum_size = Vector2(90, 32)
	btn_row.add_child(no_btn)
	no_btn.pressed.connect(func(): popup.queue_free())
	
	# Center on screen
	ui_layer.add_child(popup)
	await get_tree().process_frame
	var vp = get_viewport().get_visible_rect().size
	popup.position = (vp - popup.size) / 2.0

func _pet_the_companion(pet: Dictionary) -> void:
	"""Grant secret resources and log the petting. One reward per day."""
	var today: int = turn_manager.get_day() if is_instance_valid(turn_manager) else 0
	pet["pet_cooldown_day"] = today
	
	# Secret resource bundle — undocumented, players discover it
	var reward_gold  = randi_range(5, 20)
	var reward_food  = randi_range(10, 30)
	var reward_wood  = randi_range(5, 15)
	
	var res = players_data[1]["resources"]
	res["gold"]  = res.get("gold",  0) + reward_gold
	res["food"]  = res.get("food",  0) + reward_food
	res["wood"]  = res.get("wood",  0) + reward_wood
	
	var pet_name: String = pet.get("name", "your companion")
	
	# Flash the pet sprite with a warm glow
	var sprite: Node2D = unit_sprite_map.get(pet.get("unique_id", ""))
	if is_instance_valid(sprite):
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 1.6, 2.0), 0.2)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)
	
	# Notification — uses undefined flavour text so it feels like a secret
	if is_instance_valid(notification_panel):
		notification_panel.push(
			"Favour of the Feline",
			"You spent a moment with %s.\nThe city took care of itself." % pet_name,
			"🐾",
			Color(0.6, 0.4, 0.9)
		)
	
	# Silent log entry — no big announcement
	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(today, GL.Category.SYSTEM,
			"🐾 A quiet moment with %s. Something feels a little better." % pet_name)

# ─── Combat helpers ───────────────────────────────────────────────────────────

func get_unit_army_role(unit: Dictionary) -> String:
	"""Classify a unit for army reference-stat purposes (see ARMY_UNIT_STATS)."""
	var unit_type = unit.get("type", "peasant")
	if unit_type == "soldier":
		return "soldier"
	if unit_type == "marauder":
		return "marauder"
	var training = unit.get("training", null)
	if training != null and training.get("type", "") == "soldier":
		return "soldier_training"
	return "peasant"

func is_role_locked_in_army(role: String) -> bool:
	"""Everyone except plain villagers is automatically part of the army."""
	return role != "peasant"

func get_army_units(player_id: int) -> Array:
	"""Return the actual unit dicts that count toward a player's army (for combat/targeting)."""
	var result: Array = []
	if not players_data.has(player_id):
		return result
	for unit in players_data[player_id].get("units", []):
		if unit.get("is_pet", false):
			continue
		var role = get_unit_army_role(unit)
		if not is_role_locked_in_army(role) and not unit.get("in_army", false):
			continue
		result.append(unit)
	return result

func _get_unit_by_uid(player_id: int, uid: String) -> Dictionary:
	"""Look up a unit dict by unique_id within a player's unit list."""
	if not players_data.has(player_id) or uid == "":
		return {}
	for unit in players_data[player_id].get("units", []):
		if unit.get("unique_id", "") == uid:
			return unit
	return {}

func calculate_army_totals(player_id: int) -> Dictionary:
	"""Sum unit count / hp pool / strength for a player's army using ARMY_UNIT_STATS."""
	var totals = {"count": 0, "hp": 0, "atk": 0}
	for unit in get_army_units(player_id):
		var stats = ARMY_UNIT_STATS.get(get_unit_army_role(unit), ARMY_UNIT_STATS["peasant"])
		totals["count"] += 1
		totals["hp"] += stats["hp"]
		totals["atk"] += stats["atk"]
	return totals

func _open_combat_modal(enemy_building: Node2D) -> void:
	"""Open the combat modal when the player clicks an enemy barracks."""
	if calculate_army_totals(1)["count"] == 0:
		if is_instance_valid(notification_panel):
			notification_panel.push("No Army", "You have no units to send into battle!", "⚔", Color(0.7, 0.3, 0.1))
		return

	var CombatModalScript = preload("res://scripts/ui/combat_modal.gd")
	var modal = CombatModalScript.new(self)
	ui_layer.add_child(modal)
	modal.modal_closed.connect(func(_type): modal.queue_free())
	active_combat_modal = modal
	modal.start_combat(1, enemy_building)

func remove_enemy_barracks_node(building_node: Node2D) -> void:
	"""Remove an enemy barracks from the map and player data after combat victory."""
	if not is_instance_valid(building_node):
		return
	var owner_player: int = building_node.get_meta("owner_player", -1)
	var bname: String = building_node.name
	remove_building_from_player(bname, owner_player)
	building_node.queue_free()

	# Wipe out the rest of the camp — its marauders don't survive the barracks
	var units_killed: int = 0
	if players_data.has(owner_player):
		var camp_units: Array = players_data[owner_player].get("units", [])
		for unit in camp_units:
			var uid: String = unit.get("unique_id", "")
			if uid != "" and is_instance_valid(map_objects_holder):
				var sprite = map_objects_holder.get_node_or_null(uid)
				if is_instance_valid(sprite):
					sprite.queue_free()
			unit_sprite_map.erase(uid)
			units_killed += 1
		players_data.erase(owner_player)  # Whole camp is gone — barracks was its only building

	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(turn_manager.get_day() if is_instance_valid(turn_manager) else 0,
			GL.Category.COMBAT, "⚔ Enemy barracks '%s' destroyed, along with %d marauder(s)." % [bname, units_killed])
	# Track cumulative camp kills for achievements
	var camps_killed: int = players_data.get(1, {}).get("camps_killed", 0) + 1
	if players_data.has(1):
		players_data[1]["camps_killed"] = camps_killed
	_try_unlock_achievement("destroy_camp")
	if camps_killed >= 3:
		_try_unlock_achievement("destroy_3_camps")

func wipe_army(player_id: int) -> int:
	"""Kill every unit currently counted in a player's army (used when an army loses a battle).
	Returns the number of units killed."""
	var army_units: Array = get_army_units(player_id)
	for unit in army_units:
		remove_unit_from_combat(unit)
	return army_units.size()

func remove_unit_from_combat(unit: Dictionary) -> void:
	"""Remove a player unit that was killed in combat."""
	var player_id: int = unit.get("player_id", 1)
	if not players_data.has(player_id):
		return
	var player_units: Array = players_data[player_id].get("units", [])
	var uid: String = unit.get("unique_id", "")
	# Remove sprite
	if uid != "" and is_instance_valid(map_objects_holder):
		var sprite = map_objects_holder.get_node_or_null(uid)
		if is_instance_valid(sprite):
			sprite.queue_free()
	unit_sprite_map.erase(uid)
	player_units.erase(unit)
	players_data[player_id]["units"] = player_units
	var pop = players_data[player_id].get("population", {})
	pop["current"] = player_units.size()
	players_data[player_id]["population"] = pop
	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(turn_manager.get_day() if is_instance_valid(turn_manager) else 0,
			GL.Category.COMBAT, "☠ %s fell in combat." % unit.get("name", "Unit"))

func _on_wave_spawned(wave_num: int, enemy_player_id: int, tile: Vector2i):
	"""Push a red notification card that pans to the camp when clicked."""
	var world_pos: Vector2 = tilemap_layer.map_to_local(tile)
	var title = "Marauders %d Spotted!" % wave_num
	var body  = "Click to locate the enemy camp."
	if is_instance_valid(turn_event_manager):
		turn_event_manager.push_event(title, body, "⚔")
	if is_instance_valid(notification_panel):
		notification_panel.push(title, body, "⚔", Color(0.85, 0.18, 0.10),
			{"action": "pan_to", "world_pos": world_pos})
	DebugConfig.dprint("wave", ["Game: Wave %d spawned as player %d at %s" % [wave_num, enemy_player_id, str(tile)]])
	if is_instance_valid(game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game_log.add(turn_manager.get_day() if is_instance_valid(turn_manager) else 0,
			GL.Category.COMBAT,
			"⚔ Marauders wave %d spotted at tile %s. Prepare for attack!" % [wave_num, str(tile)])

func tag_event_instance(event_data: Dictionary) -> Dictionary:
	"""Give this specific firing of an event a unique instance id (mutates and returns event_data).
	Resolving one occurrence must never mark a later occurrence of the same event type as done —
	without this, a repeat of the same event type would show up permanently "already resolved"
	and softlock End Day, since it would never trigger the choice buttons that unblock it."""
	_event_instance_seq += 1
	event_data["instance_id"] = "%s#%d" % [event_data.get("id", "event"), _event_instance_seq]
	return event_data

func _fire_random_world_event():
	"""Pick a weighted random human world event and show it as a notification + modal."""
	var HumanEvents = preload("res://data/events/events_human.gd")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var event_data: Dictionary = HumanEvents.get_random_event_weighted(rng)
	if event_data.is_empty():
		return
	tag_event_instance(event_data)
	var tier: String = event_data.get("tier", "C")
	var tier_label: String = HumanEvents.get_tier_label(tier)
	# Colour-code the card by tier significance
	var card_color: Color
	match tier:
		"S+": card_color = Color(0.85, 0.20, 0.85)   # purple
		"S":  card_color = Color(0.90, 0.20, 0.20)   # red
		"A":  card_color = Color(0.90, 0.55, 0.10)   # orange
		"B":  card_color = Color(0.85, 0.80, 0.10)   # gold
		"C":  card_color = Color(0.30, 0.60, 0.90)   # blue
		"D":  card_color = Color(0.40, 0.75, 0.40)   # green
		_:    card_color = Color(0.55, 0.55, 0.55)   # grey  (F)
	if is_instance_valid(turn_event_manager):
		turn_event_manager.push_event(event_data["title"], event_data["body"], event_data.get("icon", "📜"))
	if is_instance_valid(notification_panel):
		notification_panel.push(
			"%s — %s" % [tier_label, event_data["title"]],
			"Click to respond.",
			event_data.get("icon", "📜"),
			card_color,
			{"action": "open_event", "event_data": event_data}
		)
	# Block End Day until the player resolves the event
	if is_instance_valid(game_footer):
		game_footer.set_end_day_blocked(true)
	# End-day blocked until event resolved — no log entry yet (logged on resolve with choice)

func _start_unit_training(unit: Dictionary, training_type: String) -> bool:
	"""Begin training for a unit. Returns false if prerequisites aren't met."""
	if not TRAINING_DEFINITIONS.has(training_type):
		push_warning("Game: Unknown training type: " + training_type)
		return false
	
	# Allow stacking — a unit can train a type they already have for a refresher,
	# but don't start a new training if one is already in progress.
	if unit.get("training") != null:
		DebugConfig.dprint("wave", ["Game: Unit %s is already in training" % unit.get("name", "?")])
		return false
	
	# Soldier training has a one-time gold cost, paid by the unit's owner
	if training_type == "soldier":
		var owner_player: int = unit.get("player_id", 1)
		var resources: Dictionary = players_data.get(owner_player, {}).get("resources", {})
		var gold: int = resources.get("gold", 0)
		if gold < SOLDIER_TRAINING_COST:
			DebugConfig.dprint("wave", ["Game: Not enough gold to train %s as a soldier (need %d, have %d)" % [unit.get("name", "?"), SOLDIER_TRAINING_COST, gold]])
			if owner_player == 1 and is_instance_valid(notification_panel):
				notification_panel.push("Not Enough Gold", "Training a soldier costs %d gold." % SOLDIER_TRAINING_COST, "⚔", Color(0.7, 0.3, 0.1))
			return false
		resources["gold"] = gold - SOLDIER_TRAINING_COST
		players_data[owner_player]["resources"] = resources
		if owner_player == 1 and is_instance_valid(resource_bar):
			resource_bar.refresh()
	
	var def = TRAINING_DEFINITIONS[training_type]
	unit["training"] = {
		"type": training_type,
		"progress": 0,
		"days_required": def["days_required"]
	}
	if training_type == "soldier":
		unit["in_army"] = true  # Recruits join the army the moment training begins
	DebugConfig.dprint("wave", ["Game: Started %s training for %s (%d days)" % [training_type, unit.get("name", "?"), def["days_required"]]])
	return true

func _cancel_unit_training(unit: Dictionary):
	"""Cancel in-progress training without granting the specialty."""
	unit["training"] = null
	DebugConfig.dprint("wave", ["Game: Cancelled training for %s" % unit.get("name", "?")])

func _process_training_progress():
	"""Advance training progress by 1 day for all units currently training."""
	for player_id in players_data.keys():
		if str(player_id) == "environment":
			continue
		for unit in players_data[player_id].get("units", []):
			var training = unit.get("training")
			if training == null:
				continue
			training["progress"] += 1
			var days_req = training.get("days_required", 5)
			if training["progress"] >= days_req:
				# Training complete — award specialty
				var t_type = training.get("type", "")
				if t_type != "" and not (t_type in unit.get("specialties", [])):
					unit["specialties"].append(t_type)
				unit["training"] = null
				# Update unit type to reflect their highest specialty
				_update_unit_type_from_specialties(unit)
				_update_unit_sprite_texture(unit)
				if unit.get("type", "") == "soldier":
					unit["in_army"] = true  # Promoted soldiers stay in the army
				DebugConfig.dprint("wave", ["Game: %s completed %s training! Specialties: %s, Type: %s" % [unit.get("name", "?"), t_type, str(unit.get("specialties", [])), unit.get("type", "?")]])
				if is_instance_valid(game_log):
					var GL = preload("res://scripts/managers/game_log.gd")
					game_log.add(turn_manager.get_day(), GL.Category.TRAINING,
						"%s completed %s training." % [unit.get("name", "?"), t_type.capitalize()])

func _update_unit_type_from_specialties(unit: Dictionary):
	"""Set unit type based on their specialties (last specialty wins, peasant if none)."""
	var specialties = unit.get("specialties", [])
	if specialties.is_empty():
		unit["type"] = "peasant"
	elif "soldier" in specialties:
		unit["type"] = "soldier"
	elif "scholar" in specialties:
		unit["type"] = "scholar"
	else:
		# Fallback: use the first specialty name
		unit["type"] = specialties[0]

func _update_unit_sprite_texture(unit: Dictionary) -> void:
	"""Refresh a unit's sprite texture to match its current type (e.g. after training completes)."""
	var uid: String = unit.get("unique_id", "")
	if uid == "" or not is_instance_valid(map_objects_holder):
		return
	var sprite = unit_sprite_map.get(uid)
	if not is_instance_valid(sprite):
		sprite = map_objects_holder.get_node_or_null(uid)
	if not is_instance_valid(sprite):
		return
	var texture_path = _get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"))
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		sprite.scale = _get_unit_sprite_scale(unit)

# Footer button handlers
func _on_build_pressed():
	DebugConfig.dprint("ui", ["Game: Build button pressed"])
	_open_build_selection_modal()

func _on_pause_pressed():
	unit_movement_paused = !unit_movement_paused
	if unit_movement_paused:
		game_footer.pause_button.text = "▶"
		DebugConfig.dprint("movement", ["Game: Unit movement paused"])
	else:
		game_footer.pause_button.text = "II"
		DebugConfig.dprint("movement", ["Game: Unit movement resumed"])

func _on_slow_pressed():
	# Decrease speed by 0.25x, minimum 0.25x
	unit_movement_speed = maxf(unit_movement_speed - 0.25, 0.25)
	DebugConfig.dprint("movement", ["Game: Unit movement speed adjusted to %.2fx" % unit_movement_speed])

func _on_speedup_pressed():
	# Increase speed by 0.25x, maximum 4.0x
	unit_movement_speed = minf(unit_movement_speed + 0.25, 4.0)
	DebugConfig.dprint("movement", ["Game: Unit movement speed adjusted to %.2fx" % unit_movement_speed])

func _on_unit_control_gui_input(event: InputEvent, unit: Dictionary):
	"""Handle unit control GUI input - open unit details on left click, but
	   yield to building selection if a building is at the same position."""
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# If a building exists under the cursor, let it take priority
	if camera:
		var world_pos = camera.get_global_mouse_position()
		var building = _get_building_at_position(world_pos)
		if building:
			_select_building(building)
			get_tree().root.set_input_as_handled()
			return
	
	# Pets get a special interaction instead of a unit details modal
	if unit.get("is_pet", false):
		_on_pet_clicked(unit)
		get_tree().root.set_input_as_handled()
		return
	
	_open_unit_details_modal(unit)
	get_tree().root.set_input_as_handled()

func _on_unit_mouse_entered(_unit: Dictionary):
	"""Visual feedback when mouse enters unit clickable area"""
	pass

func _on_unit_mouse_exited(_unit: Dictionary):
	"""Visual feedback when mouse leaves unit clickable area"""
	pass

func _on_unit_sprite_input(event: InputEvent, unit: Dictionary):
	"""Handle unit sprite input - open unit details modal on left click"""
	DebugConfig.dprint("ui", ["DEBUG: Unit sprite input event detected for %s: %s" % [unit.get("name", "unknown"), event]])
	
	# Only handle mouse button click events
	if not event is InputEventMouseButton:
		DebugConfig.dprint("ui", ["DEBUG: Event is not a mouse button event, ignoring"])
		return
	
	DebugConfig.dprint("ui", ["DEBUG: Mouse button event detected for %s - button: %d, pressed: %s" % [unit.get("name", "unknown"), event.button_index, event.pressed]])
	
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		DebugConfig.dprint("ui", ["DEBUG: Not a left mouse button press, ignoring"])
		return
	
	DebugConfig.dprint("ui", ["Game: Unit sprite clicked: %s" % unit.get("name", "unknown")])
	_open_unit_details_modal(unit)
	get_tree().root.set_input_as_handled()

func _open_unit_details_modal(unit: Dictionary):
	"""Open the unit details modal for the specified unit"""
	DebugConfig.dprint("ui", ["Game: Opening unit details modal for: %s" % unit.get("name", "unknown")])
	
	# Create unit view modal if it doesn't exist yet
	var unit_view_modal
	if not has_meta("unit_view_modal"):
		unit_view_modal = preload("res://scripts/ui/unit_view_modal.gd").new(self, Vector2(200, 100))
		set_meta("unit_view_modal", unit_view_modal)
		ui_layer.add_child(unit_view_modal)
		DebugConfig.dprint("ui", ["Game: Unit view modal created"])
	else:
		unit_view_modal = get_meta("unit_view_modal")
		# Close the old modal to clear its paths before showing new unit
		if unit_view_modal.has_method("close_modal"):
			unit_view_modal.close_modal()
	
	# Update modal with unit data and display it
	if unit_view_modal.has_method("display_unit"):
		unit_view_modal.display_unit(unit)
		unit_view_modal.show()
		
		# Register with UI manager for ESC key handling
		if ui_manager and ui_manager.has_method("push_modal"):
			ui_manager.push_modal(unit_view_modal)
		
		DebugConfig.dprint("ui", ["Game: Unit details modal displayed for: %s" % unit.get("name", "unknown")])
	else:
		DebugConfig.dprint("ui", ["Game: ERROR - unit_view_modal has no display_unit method!"])

func _open_build_selection_modal():
	# Create build selection modal if it doesn't exist
	if not build_selection_modal:
		var BuildSelectionScript = preload("res://scripts/ui/build_selection_modal.gd")
		build_selection_modal = BuildSelectionScript.new(self, Vector2(200, 100))
		ui_layer.add_child(build_selection_modal)
		# Connect to the new unified signal that includes placement
		build_selection_modal.place_building_confirmed.connect(_on_building_placement_confirmed_with_type)
		# Cancel any active ghost preview when the modal is closed without confirming
		build_selection_modal.placement_cancelled.connect(_cancel_building_placement)
	
	# Toggle the modal
	build_selection_modal.toggle()

func _on_building_placement_confirmed_with_type(build_more: bool, building_type: String):
	DebugConfig.dprint("buildings", ["Game: Building placement confirmed for: ", building_type, " build_more: ", build_more])
	# Store the build_more state for use after placement
	building_placement_build_more = build_more
	# Start building placement preview mode
	_start_building_placement(building_type)
	# Store the build_more state for use after placement
	building_placement_build_more = build_more
	# Start building placement preview mode
	_start_building_placement(building_type)

func _on_building_placement_cancelled():
	DebugConfig.dprint("buildings", ["Game: Building placement cancelled"])

# Header button handlers
func _on_header_settings_pressed():
	if is_instance_valid(ui_manager):
		ui_manager.handle_escape()

func _on_header_players_pressed():
	if players_modal:
		players_modal.toggle()

func _on_header_resources_pressed():
	if resources_modal:
		resources_modal.toggle()

func _on_header_buildings_pressed():
	if buildings_modal:
		buildings_modal.toggle()

func _on_header_population_pressed():
	if population_modal:
		population_modal.toggle()

func _on_header_army_pressed():
	if army_modal:
		army_modal.toggle()

func _on_header_units_pressed():
	if units_modal:
		units_modal.toggle()

func _on_header_science_pressed():
	if science_modal:
		science_modal.toggle()

func _on_header_encyclopedia_pressed():
	if encyclopedia_modal:
		encyclopedia_modal.toggle()

func _on_header_log_pressed():
	if log_modal:
		if not log_modal.is_open:
			log_modal.refresh_content()
		log_modal.toggle()

func _on_header_graphs_pressed():
	if graphs_modal:
		if not graphs_modal.is_open:
			graphs_modal.refresh_content()
		graphs_modal.toggle()

func _cancel_world_creation():
	DebugConfig.dprint("world_gen", ["Game: Cancelling world creation"])
	is_in_world_creation = false
	
	# Clean up world creator
	if world_creator:
		world_creator.queue_free()
		world_creator = null
	
	# Close world creation modal
	ui_manager.close_world_creation_modal()
	
	# Return to main menu
	var error = get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")
	if error != OK:
		push_error("Failed to return to main menu. Error code: %d" % error)

# --- Map Generation Functions ---

func generate_world_data() -> bool:
	DebugConfig.dprint("world_gen", ["Game: Generating world data..."]); var generator = WorldGenerator.new()
	world_data = generator.generate_world_data(MAP_WIDTH, MAP_HEIGHT)
	if world_data.is_empty(): push_error("Game: World generator returned empty data."); return false
	DebugConfig.dprint("world_gen", ["Game: Generation complete."]); return true


func _clear_and_draw_map():
	DebugConfig.dprint("world_gen", ["Game: Drawing game map..."]);
	if not is_instance_valid(tilemap_layer): push_error("Game: Cannot draw, TileMapLayer is invalid."); return
	tilemap_layer.clear()
	if world_data.is_empty(): DebugConfig.dprint("world_gen", ["Game: No world data loaded to draw."]); return
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])
		else: push_warning("Game: Skipping invalid tile data at coords: %s" % str(coords))
	DebugConfig.dprint("world_gen", ["Game: Map drawing complete."])


# --- Save/Load Wrappers & UI Callbacks ---

func _on_save_requested():
	DebugConfig.dprint("save_load", ["Game: Save requested by UI button."])
	_execute_save()


func _on_save_requested_from_ui(pending_action: String):
	DebugConfig.dprint("save_load", ["Game: _on_save_requested_from_ui called for action: ", pending_action]) # DEBUG
	if _execute_save():
		DebugConfig.dprint("save_load", ["Game: Save successful, telling UIManager to perform action."]) # DEBUG
		if is_instance_valid(ui_manager):
			ui_manager.perform_pending_action_after_save()
	else:
		DebugConfig.dprint("save_load", ["Game: Save failed, UI manager should handle reopening menu."]) # DEBUG
		# UIManager's _on_confirm_save already handles reopening main menu on failure


func _execute_save() -> bool:
	# Collect building data
	var buildings_data = []
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child):
				var texture_path = ""
				# Get texture path from the Sprite2D child if it's a building scene
				if child.has_node("Sprite2D"):
					var sprite = child.get_node("Sprite2D")
					if sprite.texture:
						texture_path = sprite.texture.resource_path
				
				var building_info = {
					"name": child.name,
					"position": child.position,
					"texture_path": texture_path,
					"z_index": child.z_index,
					"owner_player": child.get_meta("owner_player", 1),
					"building_type": child.get_meta("building_type", "unknown"),
					"construction_day": child.get_meta("construction_day", 0),
					"living_occupancy": child.get_meta("living_occupancy", 0),
					"worker_occupancy": child.get_meta("worker_occupancy", 0),
					"station_occupancy": child.get_meta("station_occupancy", 0),
					"resource_jobs": child.get_meta("resource_jobs", []),
					"display_name": child.get_meta("display_name", ""),
					"farm_state": child.get_meta("farm_state", ""),
					"farm_worker_assigned": child.get_meta("farm_worker_assigned", false),
					"next_attack_day": child.get_meta("next_attack_day", -1),
					"enemy_hp": child.get_meta("enemy_hp", -1)
				}
				
				buildings_data.append(building_info)
	
	# Collect environment objects data
	var environment_objects_data = []
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			# Check if it's an environment object (mountain, tree, or fish)
			if child.name.begins_with("mountain_") or child.name.begins_with("tree_") or child.name.begins_with("fish_"):
				var object_type = "mountain" if child.name.begins_with("mountain_") else ("tree" if child.name.begins_with("tree_") else "fish")
				var env_obj_info = {
					"name": child.name,
					"position": child.position,
					"environment_id": child.get_meta("environment_id", child.name),
					"object_type": object_type
				}
				environment_objects_data.append(env_obj_info)
	
	var game_state = { 
		"map_data": world_data, 
		"buildings_data": buildings_data,
		"environment_objects_data": environment_objects_data,
		"players_data": players_data,
		"current_day": turn_manager.get_day(),
		"wave_state": _get_wave_state_for_save(),
		"current_save_path": current_save_path,
		"log_entries": game_log.entries.duplicate() if is_instance_valid(game_log) else []
	}
	var saved_path = SaveLoadManager.save_game(game_state, current_save_path)
	if not saved_path.is_empty():
		current_save_path = saved_path; return true
	else: DebugConfig.dprint("save_load", ["Game: Save failed in SaveLoadManager."]); return false


func _on_action_confirmed_from_ui(action_name: String):
	DebugConfig.dprint("save_load", ["Game: _on_action_confirmed_from_ui called for action: ", action_name]) # DEBUG
	if is_instance_valid(ui_manager):
		ui_manager._perform_action(action_name) # Tell UI Manager to proceed


# Placeholder for simple load button (Needs replacing with UI Manager integration)
func _on_load_pressed():
	push_warning("Game: Simple Load button pressed - functionality should be moved to UIManager Load Modal.")
	var first_save_path = ""
	var dir = DirAccess.open(SaveLoadManager.SAVE_DIR);
	if dir: dir.list_dir_begin(); var f=dir.get_next(); while f!="": if !dir.current_is_dir() and f.ends_with(".save"): first_save_path = SaveLoadManager.SAVE_DIR.path_join(f); break; f=dir.get_next()
	if first_save_path.is_empty(): push_warning("Game: No save file found for simple load."); return
	DebugConfig.dprint("save_load", ["Game: Attempting simple load of: ", first_save_path])
	var loaded_state = SaveLoadManager.load_game(first_save_path)
	if not loaded_state.is_empty():
		world_data = loaded_state["map_data"]; current_save_path = loaded_state["current_save_path"]
		turn_manager.set_day(loaded_state["current_day"]); _clear_and_draw_map(); map_object_manager.clear_objects()
		map_object_manager.place_objects(world_data); camera_controller.center_camera()
		# Header is visible by default for loaded games
		DebugConfig.dprint("save_load", ["Game: Loaded successfully via simple load."])
	else: 
		DebugConfig.dprint("save_load", ["Game: Failed simple load."])

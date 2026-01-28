# scripts/main/game.gd - Orchestrator (with Debug Prints)
extends Node

# --- Constants ---
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

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

# Info Modals
var players_modal: Control
var resources_modal: Control
var buildings_modal: Control
var population_modal: Control
var army_modal: Control
var units_modal: Control
var modal_positions: Dictionary = {}  # Track modal positions to prevent overlap

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
			"food": 50,
			"wood": 25,
			"stone": 0
		},
		"resource_rates": {
			# Per-day production/consumption rates
			"gold": 0,
			"food": 0,
			"wood": 0,
			"stone": 0
		},
		"population": {
			"total": 10,  # Base starting population
			"housed": 0,  # Number of people currently housed
			"working": 0,  # Number of people currently working
			"unhoused": 10,  # total - housed
			"unemployed": 10,  # total - working
			"growth_accumulator": 0.0  # Fractional growth accumulation (adds 1 when >= 1.0)
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
		print("Cannot place building at this location")

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
		
		if building_scene.has_method("setup"):
			building_scene.setup(setup_data)
		
		# Set initial occupancy metadata on the building node
		building_scene.set_meta("living_occupancy", 0)
		building_scene.set_meta("worker_occupancy", 0)
		
		print("Game: Placing building at tile ", tile_coords, " world pos ", world_pos)
		
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
			print("Game: Added building ", building_name, " to player ", owner_player, " buildings list")
		
		print("Game: Successfully placed ", building_type, " at world position: ", world_pos)
		
		# Calculate and cache connections for the new building (one-time, with bidirectional paths)
		_calculate_and_cache_building_connections(building_scene)
		
		# Auto-save after placing building
		print("Game: Auto-saving after building placement...")
		if _execute_save():
			print("Game: Auto-save successful!")
		else:
			print("Game: Auto-save failed, but continuing game...")
	else:
		print("Warning: Could not find building texture: ", building_texture_path)

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
		"town_center":
			return "res://assets/buildings/human_towncentre-export.png"
		"farmhouse":
			return "res://assets/buildings/human_farmhouse.png"
		"farm":
			return "res://assets/buildings/human_farm_tilled.png"  # Start with tilled state
		_:
			return "res://assets/buildings/human_towncentre-export.png"

func _get_next_building_id(building_type: String) -> int:
	# Initialize counter for this building type if it doesn't exist
	if not building_counter.has(building_type):
		building_counter[building_type] = 0
	
	# Increment and return the next ID
	building_counter[building_type] += 1
	return building_counter[building_type]

func _is_building_node(node: Node) -> bool:
	# Check if node is a building by looking for common building types in the name
	var building_types = ["house", "fishing_hut", "town_center", "barracks", "farm", "farmhouse", "stoneworker", "lumberjack", "lumber_mill"]
	for building_type in building_types:
		if node.name.begins_with(building_type):
			return true
	return false

func _extract_building_type_from_name(building_name: String) -> String:
	# Extract building type from name (e.g., "house1" -> "house")
	var building_types = ["fishing_hut", "town_center", "lumber_mill", "lumberjack", "stoneworker", "house", "barracks", "farm", "farmhouse"]  # Order matters - check longer names first
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
			print("Game: Removed building ", building_name, " from player ", player_id, " buildings list")

func debug_print_all_buildings():
	# Debug function to print all buildings and their status
	print("=== BUILDING DEBUG INFO ===")
	print("Player 1 buildings list: ", players_data.get(1, {}).get("buildings", []))
	
	if map_objects_holder:
		print("All objects in map_objects_holder:")
		for child in map_objects_holder.get_children():
			print("  - Name: ", child.name, " | Is Building: ", _is_building_node(child))
			if _is_building_node(child):
				var building_type = _extract_building_type_from_name(child.name)
				print("    Type: ", building_type, " | Position: ", child.position)
	
	print("Building counters: ", building_counter)
	print("===========================")

func calculate_resource_rates(player_id: int) -> Dictionary:
	"""Calculate per-day resource production/consumption rates based on buildings and workers"""
	var rates = {
		"gold": 0,
		"food": 0,
		"wood": 0,
		"stone": 0
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
		var worker_count = child.get_meta("worker_occupancy", 0)
		
		# Each building type produces different resources based on worker count
		match building_type:
			"lumberjack":
				rates["wood"] += worker_count * 1  # +1 wood per worker
			"stoneworker":
				rates["stone"] += worker_count * 1  # +1 stone per worker
			"fishing_hut":
				rates["food"] += worker_count * 5  # +5 food per worker
			"farm":
				# Farms are special - will implement later
				pass
			"barracks":
				# Barracks don't produce resources
				pass
			"house", "farmhouse":
				# Housing doesn't produce resources
				pass
			"town_center":
				# Town center doesn't produce resources
				pass
	
	# Update player data
	if players_data.has(player_id):
		players_data[player_id]["resource_rates"] = rates
	
	return rates

func get_resource_rates(player_id: int) -> Dictionary:
	"""Get current resource rates for a player"""
	if players_data.has(player_id):
		return players_data[player_id].get("resource_rates", {
			"gold": 0,
			"food": 0,
			"wood": 0,
			"stone": 0
		})
	return {"gold": 0, "food": 0, "wood": 0, "stone": 0}

func apply_resource_production(player_id: int):
	"""Apply resource production based on current rates"""
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
			print("Player ", player_id, " produced +", rates[resource_type], " ", resource_type)

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
		print("Player ", player_id, " paid -", costs[resource_type], " ", resource_type, " for ", building_type)

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
		"node_path": mountain_node.get_path()
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
		"node_path": tree_node.get_path()
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
		"node_path": fish_node.get_path()
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

func update_building_occupancy(building_node: Node2D, capacity_type: String, new_value: int) -> bool:
	# Update building occupancy and validate against available population
	if not building_node:
		return false
	
	var owner_player = building_node.get_meta("owner_player", 1)
	var current_occupancy = building_node.get_meta(capacity_type + "_occupancy", 0)
	var difference = new_value - current_occupancy
	
	# Check if we have enough available population for increases
	if difference > 0:
		var pop_data = get_player_population_data(owner_player)
		var available = 0
		if capacity_type == "living":
			available = pop_data.get("unhoused", 0)
		elif capacity_type == "worker":
			available = pop_data.get("unemployed", 0)
		
		if available < difference:
			print("Not enough ", capacity_type, " population available. Need ", difference, ", have ", available)
			return false
	
	# Update building occupancy
	building_node.set_meta(capacity_type + "_occupancy", new_value)
	
	# Auto-assign units to this building if capacity increased
	if difference > 0:
		_auto_assign_units_to_building(building_node, capacity_type, difference)
	elif difference < 0:
		# Capacity decreased - need to remove some unit assignments
		_remove_excess_unit_assignments(building_node, capacity_type, abs(difference), owner_player)
	
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

	# Calculate housed and working population from actual building data
	var total_housed = 0
	var total_working = 0	# Get all buildings for this player and sum their occupancy
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if _is_building_node(child) and child.get_meta("owner_player", 1) == player_id:
				# Get building occupancy from metadata
				var building_living_occupancy = child.get_meta("living_occupancy", 0)
				var building_worker_occupancy = child.get_meta("worker_occupancy", 0)
				total_housed += building_living_occupancy
				total_working += building_worker_occupancy
	
	# Update population data
	pop_data["housed"] = total_housed
	pop_data["working"] = total_working
	pop_data["unhoused"] = pop_data.get("total", 10) - total_housed
	pop_data["unemployed"] = pop_data.get("total", 10) - total_working
	
	player_data["population"] = pop_data
	
	# Ensure values don't go negative
	pop_data["unhoused"] = max(0, pop_data["unhoused"])
	pop_data["unemployed"] = max(0, pop_data["unemployed"])
	
	# Ensure sprites exist for fully assigned units after population updates
	_check_and_create_missing_sprites(player_id)

func apply_population_growth(player_id: int):
	"""Apply population growth per turn (current_total * 0.1)"""
	if not players_data.has(player_id):
		return
	
	var player_data = players_data[player_id]
	var pop_data = player_data.get("population", {})
	
	if pop_data.is_empty():
		return
	
	var current_total = pop_data.get("total", 10)
	var growth_accumulator = pop_data.get("growth_accumulator", 0.0)
	
	# Calculate growth: 1% of current population per turn
	var daily_growth = current_total * 0.01
	growth_accumulator += daily_growth
	
	# Convert accumulated growth to actual population increase
	var pop_to_add = int(growth_accumulator)
	if pop_to_add > 0:
		pop_data["total"] = current_total + pop_to_add
		growth_accumulator -= pop_to_add  # Keep the fractional part
		print("Player ", player_id, " population grew by ", pop_to_add, " (total: ", pop_data["total"], ")")
	
	# Store updated accumulator
	pop_data["growth_accumulator"] = growth_accumulator
	
	# Recalculate unhoused/unemployed with new total
	pop_data["unhoused"] = pop_data.get("total", 10) - pop_data.get("housed", 0)
	pop_data["unemployed"] = pop_data.get("total", 10) - pop_data.get("working", 0)

func _check_and_create_missing_sprites(player_id: int):
	"""Check for units with both assignments but no sprites and create them"""
	if not players_data.has(player_id) or not map_objects_holder:
		return
	
	var player_data = players_data[player_id]
	var player_units = player_data.get("units", [])
	
	for unit in player_units:
		var living_quarters = unit.get("living_quarters", null)
		var job = unit.get("job", null)
		
		# CRITICAL: Only create sprites for units with BOTH assignments
		if living_quarters != null and job != null:
			var unit_id = unit["unique_id"]
			var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
			
			if not existing_sprite:
				print("Creating missing sprite for fully assigned unit: ", unit_id, " (living: ", living_quarters, ", job: ", job, ")")
				_create_unit_sprite_and_start_cycle(unit)
			else:
				# Sprite exists, ensure it's tracked in sprite_id
				if not unit.has("sprite_id") or unit.get("sprite_id") == "":
					unit["sprite_id"] = unit_id
					unit_sprite_map[unit_id] = existing_sprite
					print("Unit %s: Sprite already existed, added to tracking" % unit_id)

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
			# Unit should not have a sprite - remove if it exists
			var unit_id = unit["unique_id"]
			var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
			if existing_sprite:
				print("Removing sprite for unit with incomplete assignments: ", unit_id)
				# Clean up sprite tracking
				unit_sprite_map.erase(unit_id)
				unit["sprite_id"] = ""
				existing_sprite.queue_free()
				
				# Reset movement state since unit is no longer active
				unit["movement_state"] = "idle"
				unit["movement_cycle_step"] = 0

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
			print("Removed living assignment for unit ", unit_id, " from demolished building ", building_name)
		
		# Check if unit was working in this building
		if unit.get("job", null) == building_name:
			unit["job"] = null
			assignments_removed = true
			print("Removed job assignment for unit ", unit_id, " from demolished building ", building_name)
		
		# If assignments were removed, the sprite cleanup will happen in update_player_population
		if assignments_removed:
			# Reset movement state
			unit["movement_state"] = "idle"
			unit["movement_cycle_step"] = 0

func _remove_excess_unit_assignments(building_node: Node2D, capacity_type: String, excess_count: int, owner_player: int):
	"""Remove assignments when building capacity is reduced"""
	if not players_data.has(owner_player):
		return
	
	var building_name = building_node.name
	var player_data = players_data[owner_player]
	var player_units = player_data.get("units", [])
	var assignments_removed = 0
	
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
		
		if should_remove:
			# Remove the specific assignment
			if capacity_type == "living":
				unit["living_quarters"] = null
			elif capacity_type == "worker":
				unit["job"] = null
			
			assignments_removed += 1
			print("Removed ", capacity_type, " assignment for unit ", unit_id, " due to capacity reduction at ", building_name)
			
			# Reset movement state - sprite cleanup will happen in update_player_population
			unit["movement_state"] = "idle"
			unit["movement_cycle_step"] = 0

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
	print("=== ENVIRONMENT DEBUG INFO ===")
	if players_data.has("environment"):
		var env_data = players_data["environment"]
		print("Mountain count: ", env_data["counts"]["mountains"])
		print("Tree count: ", env_data["counts"]["trees"])
		print("Mountains: ", env_data["objects"]["mountains"].keys())
		print("Trees: ", env_data["objects"]["trees"].keys())
	else:
		print("No environment data found!")
	print("===============================")

func _migrate_players_data_structure():
	# Migrate old save files to include the environment player structure
	print("Game: Migrating players_data structure...")
	
	# Check for duplicate unit IDs first
	_fix_duplicate_unit_ids()
	
	# Check if environment player exists
	if not players_data.has("environment"):
		print("Game: Adding missing environment player to save data")
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
				print("Game: Migrated player ", player_id, " population to new structure")
			elif not pop_data.has("total"):
				# New structure but missing fields
				pop_data["total"] = pop_data.get("total", 10)
				pop_data["housed"] = pop_data.get("housed", 0)
				pop_data["working"] = pop_data.get("working", 0)
				pop_data["unhoused"] = pop_data["total"] - pop_data["housed"]
				pop_data["unemployed"] = pop_data["total"] - pop_data["working"]
				print("Game: Updated player ", player_id, " population structure")
			
			player_data["population"] = pop_data
	
	# Validate existing players have required structures
	for player_id in players_data:
		var player_data = players_data[player_id]
		if str(player_id) != "environment":
			# Ensure regular players have all required fields
			if not player_data.has("buildings"):
				player_data["buildings"] = []
			if not player_data.has("resources"):
				player_data["resources"] = {"gold": 100, "food": 50, "wood": 25, "stone": 0}
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
			if not player_data.has("name"):
				player_data["name"] = "Player " + str(player_id)
			if not player_data.has("race"):
				player_data["race"] = "human"
	
	# Update all players' population calculations after migration
	for player_id in players_data.keys():
		if typeof(player_id) == TYPE_INT:
			update_player_population(player_id)
	
	print("Game: Players data migration complete")

func migrate_old_building_names():
	# Migrate buildings with old coordinate-based names to new system
	print("Game: Checking for buildings with old naming system...")
	
	var buildings_to_migrate = []
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			var old_name = child.name
			# Check if this is an old-style building name
			if old_name.begins_with("TownCenter_") or old_name.begins_with("Building_"):
				buildings_to_migrate.append(child)
	
	if buildings_to_migrate.size() > 0:
		print("Game: Found ", buildings_to_migrate.size(), " buildings with old names, migrating...")
		
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
				print("Warning: Could not determine building type for: ", old_name)
				continue
			
			# Generate new name
			var building_id = _get_next_building_id(building_type)
			var new_name = building_type + str(building_id)
			
			# Update building name
			building.name = new_name
			
			# Add to player's buildings list
			if players_data.has(1):
				players_data[1]["buildings"].append(new_name)
			
			print("Game: Migrated building: ", old_name, " -> ", new_name)
		
		print("Game: Migration complete, auto-saving...")
		_execute_save()
	else:
		print("Game: No buildings need migration")

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
		
		print("Game: Building texture size: ", building_texture.get_size())
		print("Game: Tile size: ", str(tilemap_layer.tile_set.tile_size) if tilemap_layer.tile_set else "No tileset")
		
		# Calculate scale to fit tile if needed
		if tilemap_layer.tile_set:
			var tile_size = tilemap_layer.tile_set.tile_size
			var texture_size = building_texture.get_size()
			print("Game: Texture vs Tile size ratio: ", texture_size.x / tile_size.x, ", ", texture_size.y / tile_size.y)
	
	print("Game: Started building placement mode for: ", building_type)

func _cancel_building_placement():
	is_placing_building = false
	building_to_place = ""
	building_placement_build_more = false  # Reset build more mode
	
	# Clean up preview sprites
	if building_preview_sprite:
		building_preview_sprite.queue_free()
		building_preview_sprite = null
	
	print("Game: Cancelled building placement mode")

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
	# Close existing modal if open
	if building_details_modal:
		building_details_modal.queue_free()
	
	# Create new building details modal properly
	var BuildingDetailsModalScript = preload("res://scripts/ui/building_details_modal.gd")
	building_details_modal = BuildingDetailsModalScript.new()
	
	print("Game: Created building details modal: ", building_details_modal)
	
	# Add to UI layer first so it can get proper positioning
	ui_layer.add_child(building_details_modal)
	
	print("Game: Added modal to UI layer, calling setup...")
	
	# Then setup the building details
	building_details_modal.setup_building_details(building)
	
	# Connect close signal
	building_details_modal.close_requested.connect(_on_building_details_closed)
	
	# Connect demolish signal
	building_details_modal.demolish_confirmed.connect(_on_building_demolish_confirmed)
	
	print("Game: Building details modal setup complete")

func _on_building_details_closed():
	_clear_building_selection()
	building_details_modal = null

func _on_building_demolish_confirmed(building_data_to_delete: Dictionary):
	print("Game: Demolishing building: ", building_data_to_delete)
	
	# Find the building node to delete
	var building_name = building_data_to_delete.get("name", "")
	if building_name == "":
		print("Error: No building name provided for demolish")
		return
	
	# Find building in the map objects holder
	if not map_objects_holder:
		print("Error: MapObjects holder not found")
		return
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(building_name))
	if not building_node:
		print("Error: Building node not found: ", building_name)
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
	
	# TODO: Return some resources to player based on building type
	# Could return 50% of building cost or similar
	
	print("Game: Building demolished successfully: ", building_name)
	
	# Clear selection and close modal (modal should already be closed by demolish handler)
	_clear_building_selection()

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
	print("game.gd: _ready started.")
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
	print("Game: Checking TileSet...") # Debug Print
	if is_instance_valid(tilemap_layer) and is_instance_valid(tilemap_layer.tile_set):
		var tile_size = tilemap_layer.tile_set.tile_size
		print("Game: Found TileSet, Tile Size: ", tile_size) # Debug Print
		if tile_size.x > 0 and tile_size.y > 0:
			map_pixel_width = MAP_WIDTH * tile_size.x
			map_pixel_height = MAP_HEIGHT * tile_size.y
			print("Game: Calculated map pixel dimensions: %d x %d" % [map_pixel_width, map_pixel_height]) # Debug Print
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
	print("Game: Setting up CameraController...")
	camera_controller.setup(camera, map_pixel_width, map_pixel_height)

	print("Game: Setting up UIManager...")
	var ui_nodes = { # Verify these paths carefully!
		"open_menu_button": $UI_Layer/MenuButtonContainer/OpenMenuButton,
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

	print("Game: Setting up MapObjectManager...")
	var forest_coords = Vector2i(0, 4); var mountain_coords = Vector2i(0, 3); var ocean_coords = Vector2i(0, 2) # Corrected coords
	print("Game: fish_scene before setup = %s" % fish_scene)
	
	# Fallback: if fish_scene is not assigned, load it
	if not fish_scene:
		fish_scene = preload("res://scenes/objects/fish.tscn")
		print("Game: Fish scene was null, loaded via preload: %s" % fish_scene)
	
	map_object_manager.setup(map_objects_holder, tilemap_layer, tree_scene, mountain_scene, forest_coords, mountain_coords, self, fish_scene, ocean_coords)
	print("Game: map_object_manager.fish_scene after setup = %s" % map_object_manager.fish_scene)

	print("Game: Setting up TurnManager...")
	var day_label = $UI_Layer/TurnControlsContainer/TurnVBox/DayCounterLabel
	if not is_instance_valid(day_label): push_error("Game: Day counter label node not found!")
	turn_manager.setup(day_label)
	
	# Hide the old turn controls container since controls are now in resources modal footer
	$UI_Layer/TurnControlsContainer.hide()
	
	# Load preview textures for building placement
	# Create simple colored rectangles for overlays since we don't have overlay assets
	print("Game: Setting up building placement preview system")


	# --- Connect Signals ---
	print("Game: Connecting signals...")
	# Connect UI buttons to UIManager requests / TurnManager
	# Using get_node for safety in case @onready vars haven't resolved (unlikely but safe)
	var open_btn = get_node_or_null("UI_Layer/MenuButtonContainer/OpenMenuButton")
	if open_btn: open_btn.pressed.connect(ui_manager.open_main_modal)
	else: push_error("Game: OpenMenuButton not found for connection.")

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
	print("Game: Connecting signals FROM UIManager...")
	if is_instance_valid(ui_manager):
		if not ui_manager.is_connected("save_requested", Callable(self, "_on_save_requested_from_ui")):
			var err_save_req = ui_manager.save_requested.connect(_on_save_requested_from_ui)
			if err_save_req == OK: print("Game: Connected ui_manager.save_requested to _on_save_requested_from_ui")
			else: push_error("Game: FAILED to connect ui_manager.save_requested. Error: %d" % err_save_req)
		else: print("Game: ui_manager.save_requested ALREADY connected.")

		if not ui_manager.is_connected("action_confirmed", Callable(self, "_on_action_confirmed_from_ui")):
			var err_action_conf = ui_manager.action_confirmed.connect(_on_action_confirmed_from_ui)
			if err_action_conf == OK: print("Game: Connected ui_manager.action_confirmed to _on_action_confirmed_from_ui")
			else: push_error("Game: FAILED to connect ui_manager.action_confirmed. Error: %d" % err_action_conf)
		else: print("Game: ui_manager.action_confirmed ALREADY connected.")
	else:
		push_error("Game: Cannot connect UIManager signals, ui_manager node is invalid!")
	# --- END DEBUG ---

	print("Game: Connecting signals complete.")

	# --- Setup Game Header ---
	_setup_game_header()

	# --- Initialize Map ---
	initialize_map()
	print("game.gd: _ready finished.")


func _process(delta: float):
	if is_instance_valid(camera_controller):
		camera_controller.process_movement(delta, get_tree().paused)
	
	# Update unit movements
	_update_unit_movements(delta)


# --- Map Initialization ---
func initialize_map():
	print("Game: Initializing Map..."); print("Game: Start Mode: %s" % GameManager.start_mode)
	var success = false; var loaded_day = 1
	
	if GameManager.start_mode == "world_creation":
		print("Game: Mode: World Creation")
		_start_world_creation_mode()
		return  # Don't proceed with normal map initialization
	elif GameManager.start_mode == "new":
		print("Game: Mode: New Game"); current_save_path = ""
		unit_counter = 0  # Reset unit counter for new games
		if generate_world_data(): 
			success = true
			# Initialize population data for new games
			_migrate_players_data_structure()
			# Create initial units based on population total
			_create_initial_units_from_population()
		else: push_error("Game: Failed to generate world data.")
	elif GameManager.start_mode == "new_with_data":
		print("Game: Mode: New Game with Generated Data")
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
		print("Game: Mode: Load Game from Path: ", GameManager.load_file_path)
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
					print("Game: Restored player data for ", players_data.size(), " players")
			else: push_error("Game: Failed to load state from %s. Starting new game." % GameManager.load_file_path); GameManager.start_mode = "new"; initialize_map(); return
	else: push_error("Game: Invalid start mode: %s. Starting new game." % GameManager.start_mode); GameManager.start_mode = "new"; initialize_map(); return
	if success:
		print("Game: Map state ready. Updating managers...")
		# Reset environment data for new games (not loaded games)
		if GameManager.start_mode == "new" or loaded_environment_objects_data.is_empty():
			_reset_environment_data()
		
		turn_manager.set_day(loaded_day); _clear_and_draw_map(); map_object_manager.clear_objects()
		# Update footer to display loaded day
		if game_footer:
			game_footer.set_day_text(loaded_day)
		map_object_manager.place_objects(world_data)
		map_object_manager.place_fish(world_data)
		# Restore buildings if loading from save
		if not loaded_buildings_data.is_empty():
			_restore_buildings_with_proper_centering(loaded_buildings_data)
			loaded_buildings_data = []  # Clear after restoration
		
		# Restore environment objects if loading from save
		if not loaded_environment_objects_data.is_empty():
			_restore_environment_objects(loaded_environment_objects_data)
			loaded_environment_objects_data = []  # Clear after restoration
		else:
			print("Game: No environment objects to restore (new game or empty save)")
		
		# Migrate any old building names to new system
		migrate_old_building_names()
		
		# Create initial units (cosmetic)
		_create_initial_units()
		
		# CRITICAL: Ensure unit sprites are restored after buildings
		# This is especially important for loaded games where units exist but have no sprites yet
		if GameManager.start_mode == "load":
			call_deferred("_restore_unit_sprites_on_load")
			print("Game: Queued unit sprite restoration for loaded game")
		
		camera_controller.center_camera()
		print("Game: Map ready.")
	else: print("Game: Map initialization failed.")
	print("Game: --- Map Initialization Finished ---")


# --- World Creation Functions ---

func _reset_environment_data():
	# Reset environment object tracking for new games
	print("Game: Resetting environment data for new game")
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
			print("Game: Found %d units with duplicate ID: %s" % [occurrences.size(), unit_id])
			duplicates_found += occurrences.size() - 1  # Count extras
			
			# Keep the first one, reassign the others
			for i in range(1, occurrences.size()):
				var duplicate_unit = occurrences[i]["unit"]
				var old_id = duplicate_unit["unique_id"]
				var new_id = _get_next_unit_id()
				
				duplicate_unit["unique_id"] = new_id
				print("Game: Fixed duplicate unit - reassigned %s -> %s (name: %s)" % [old_id, new_id, duplicate_unit.get("name", "Unknown")])
	
	if duplicates_found > 0:
		print("Game: Fixed %d duplicate unit IDs" % duplicates_found)
	else:
		print("Game: No duplicate unit IDs found")

func _create_initial_units():
	print("Game: Skipping initial unit creation - units will be created dynamically when buildings get capacity")
	
	# Don't create any initial units - let the dynamic system handle all unit creation
	# This ensures unlimited unit generation based on building capacity
	
	# Only restore units if loading from save data
	if not loaded_units_data.is_empty():
		# Restore units from save data
		for unit_data in loaded_units_data:
			_spawn_unit(unit_data)
		loaded_units_data = []  # Clear after restoration
		print("Game: Restored ", loaded_units_data.size(), " units from save data")
		
		# Restore sprites for units that should be visible
		_restore_unit_sprites_on_load()
	else:
		# If loading from save (units exist in players_data), restore their sprites
		if GameManager.start_mode == "load":
			_restore_unit_sprites_on_load()
		else:
			print("Game: Starting with no sprites - they will be created when buildings gain capacity")

func _clear_existing_unit_sprites():
	"""Clear any existing unit sprites before restoration"""
	if not map_objects_holder:
		return
	
	# Remove any existing unit sprites (nodes with unit_X names)
	for child in map_objects_holder.get_children():
		if child.name.begins_with("unit_"):
			print("Removing existing unit sprite: ", child.name)
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
			# Check if unit has both assignments
			var living_quarters = unit.get("living_quarters", null)
			var job = unit.get("job", null)
			
			if living_quarters != null and job != null:
				units_with_assignments += 1
				# Unit should be visible - check if sprite exists
				var unit_id = unit["unique_id"]
				var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
				
				if not existing_sprite:
					units_without_sprites += 1
					# Create sprite for this fully assigned unit
					print("Restoring sprite for unit %s (%s): Living=%s, Job=%s" % [unit_id, unit.get("name", "Unknown"), living_quarters, job])
					_create_unit_sprite_and_start_cycle(unit)
					sprites_created += 1
				else:
					units_already_have_sprites += 1
	
	print("Unit sprite restoration complete: %d created, %d checked, %d with assignments, %d without sprites, %d already had sprites" % [sprites_created, units_checked, units_with_assignments, units_without_sprites, units_already_have_sprites])

func _ensure_unit_movement_properties(unit: Dictionary):
	"""Ensure unit has all required movement properties for backward compatibility"""
	if not unit.has("current_path"):
		unit["current_path"] = []
	if not unit.has("path_index"):
		unit["path_index"] = 0
	if not unit.has("movement_state"):
		unit["movement_state"] = "idle"
	if not unit.has("movement_target"):
		unit["movement_target"] = null
	if not unit.has("movement_cycle_step"):
		unit["movement_cycle_step"] = 0
	if not unit.has("work_timer"):
		unit["work_timer"] = 0.0
	if not unit.has("movement_speed"):
		unit["movement_speed"] = 25.0
	if not unit.has("speed_multiplier"):
		unit["speed_multiplier"] = randf_range(0.85, 1.15)  # Random speed variation for older saves
	
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
		
		# Load appropriate texture based on race and type
		var texture_path = "res://assets/units/human_peasant_side.png"  # Default for now
		if ResourceLoader.exists(texture_path):
			unit_sprite.texture = load(texture_path)
		else:
			print("Warning: Unit texture not found: ", texture_path)
		
		# Add to map objects holder
		map_objects_holder.add_child(unit_sprite)
		print("Game: Spawned unit sprite: ", unit_data["unique_id"], " (both living and job assigned)")
	else:
		print("Game: Unit created but no sprite (missing living or job assignment): ", unit_data["unique_id"])
	
	# Store unit in player data
	var player_id = unit_data.get("player_id", 1)
	if players_data.has(player_id) and not players_data[player_id].has("units"):
		players_data[player_id]["units"] = []
	if players_data.has(player_id):
		players_data[player_id]["units"].append(unit_data)
	
	print("Game: Spawned unit: ", unit_data["unique_id"], " (", unit_data["name"], ") at ", unit_data["position"])

func _get_next_unit_id() -> String:
	# Generate unique unit ID
	unit_counter += 1
	return "unit_" + str(unit_counter)

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
	print("Game: Updated unit_counter to %d (next unit will be unit_%d)" % [unit_counter, unit_counter + 1])

func _cache_job_connections_for_unit(unit: Dictionary):
	"""Cache or recache the job connections for a unit after a new building is placed.
	This updates the unit's cached paths to include any newly available buildings."""
	var job = unit.get("job")
	if not job:
		return  # Unit doesn't have a job, nothing to do
	
	# Check if job building's connections are already cached
	if buildings_connections_cache.has(job):
		unit["job_connections"] = buildings_connections_cache[job]
		print("Game: Used cached connections for unit ", unit.get("unique_id"), " at job ", job)
	else:
		var job_building_node = map_objects_holder.get_node_or_null(NodePath(job))
		if job_building_node:
			# Fallback: calculate if not cached (shouldn't happen in normal flow)
			var connections = _find_building_connections_for_unit(job_building_node)
			unit["job_connections"] = connections
			# Also cache it for future use
			buildings_connections_cache[job] = connections
			print("Game: Calculated and cached connections for unit ", unit.get("unique_id"), " at job ", job)
		else:
			print("Game: Warning - could not find job building node: ", job)

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
		print("Game: Updated paths for ", units_updated, " units after building ", new_building_name, " was placed")

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
	
	print("Game: Cached connections for building ", building_name, " (", connections.size(), " connections)")

func _auto_assign_units_to_building(building_node: Node2D, capacity_type: String, slots_to_fill: int):
	"""Automatically assign available units to a building when capacity is increased"""
	if not building_node:
		return
	
	var owner_player = building_node.get_meta("owner_player", 1)
	var building_id = building_node.name
	
	print("Auto-assigning ", slots_to_fill, " units to ", capacity_type, " capacity at ", building_id)
	
	# Get all unassigned units for this player
	var player_units = players_data.get(owner_player, {}).get("units", [])
	var units_assigned = 0
	
	print("Player ", owner_player, " has ", player_units.size(), " total units")
	
	# First, try to assign existing unassigned units
	for unit in player_units:
		if units_assigned >= slots_to_fill:
			break
		
		# Check if unit can be assigned to this capacity type
		var can_assign = false
		var living_quarters = unit.get("living_quarters", null)
		var job = unit.get("job", null)
		
		if capacity_type == "living" and living_quarters == null:
			can_assign = true
		elif capacity_type == "worker" and job == null:
			can_assign = true
		
		if can_assign:
			# Assign unit to this building
			if capacity_type == "living":
				unit["living_quarters"] = building_id
			elif capacity_type == "worker":
				unit["job"] = building_id
				# Use cached building connections if available, otherwise calculate
				if buildings_connections_cache.has(building_id):
					unit["job_connections"] = buildings_connections_cache[building_id]
				else:
					var job_building_node = map_objects_holder.get_node_or_null(NodePath(building_id))
					if job_building_node:
						var connections = _find_building_connections_for_unit(job_building_node)
						unit["job_connections"] = connections
						buildings_connections_cache[building_id] = connections  # Cache for future
			
			units_assigned += 1
			print("Auto-assigned existing unit ", unit["unique_id"], " to ", capacity_type, " at building ", building_id)
	
	# If we still need more units, create new ones
	var remaining_slots = slots_to_fill - units_assigned
	if remaining_slots > 0:
		print("Creating ", remaining_slots, " new units for ", capacity_type, " capacity")
		_create_new_units_for_capacity(building_node, capacity_type, remaining_slots, owner_player)
	
	# After all assignments, check for units that now have both living quarters and jobs
	_check_and_create_missing_sprites(owner_player)
	
	print("Auto-assigned ", units_assigned, " existing units and created ", remaining_slots, " new units for ", capacity_type, " capacity at ", building_id)

func _create_unit_sprite_and_start_cycle(unit: Dictionary):
	"""Create sprite for a fully assigned unit and start its movement cycle"""
	var unit_id = unit["unique_id"]
	var existing_sprite = map_objects_holder.get_node_or_null(unit_id)
	
	# Cache building connections if unit has a job (calculate once, reuse in cycle)
	var job_building = unit.get("job", null)
	if job_building and not unit.has("job_connections"):
		var building_node = map_objects_holder.get_node_or_null(NodePath(job_building))
		if building_node:
			unit["job_connections"] = _find_building_connections_for_unit(building_node)
	
	if not existing_sprite:
		# Create new sprite since unit is now fully assigned
		var unit_sprite = Sprite2D.new()
		unit_sprite.name = unit_id
		
		# Position unit at their living quarters (home) building
		var living_quarters_id = unit.get("living_quarters", null)
		if living_quarters_id and map_objects_holder:
			var home_building = map_objects_holder.get_node_or_null(NodePath(living_quarters_id))
			if home_building:
				# Scatter units around the building to avoid overlap
				var base_position = home_building.position
				var scatter_radius = 40.0
				var random_angle = randf() * TAU  # Random angle in radians
				var random_distance = randf() * scatter_radius
				var offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
				unit_sprite.position = base_position + offset
				# Update unit's stored position to match their scattered position
				unit["position"] = unit_sprite.position
			else:
				unit_sprite.position = unit["position"]
		else:
			unit_sprite.position = unit["position"]
		
		unit_sprite.z_index = 6
		unit_sprite.centered = true  # Center the sprite on its position
		
		# Load texture
		var texture_path = "res://assets/units/human_peasant_side.png"
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			unit_sprite.texture = texture
			print("Unit %s: Loaded texture %s (size: %s)" % [unit_id, texture_path, str(texture.get_size())])
		else:
			print("Unit %s: Texture not found at %s - using fallback" % [unit_id, texture_path])
			# Create a colored rectangle as fallback
			var rect = ColorRect.new()
			rect.size = Vector2(16, 16)
			rect.color = Color.YELLOW
			unit_sprite.add_child(rect)
		
		# Track bidirectional mapping
		unit_sprite.set_meta("unit_id", unit_id)  # Sprite knows which unit it belongs to
		
		if map_objects_holder:
			map_objects_holder.add_child(unit_sprite)
			print("Unit %s sprite added to scene at position: %s" % [unit_id, str(unit_sprite.position)])
		else:
			print("ERROR: map_objects_holder is null, cannot add sprite")
		
		existing_sprite = unit_sprite  # Store reference for tracking below
	
	# ALWAYS set sprite_id in unit data, whether sprite was just created or already existed
	unit["sprite_id"] = unit_id  # Unit data tracks its sprite ID
	unit_sprite_map[unit_id] = existing_sprite  # Game tracks unit -> sprite mapping
	print("Unit %s: Sprite tracking added to map" % unit_id)
	
	# Initialize unit at home and start movement cycle
	unit["movement_cycle_step"] = 0  # Start at home
	unit["movement_state"] = "idle"
	_start_unit_movement_cycle(unit)

func _create_new_units_for_capacity(building_node: Node2D, capacity_type: String, count: int, owner_player: int):
	"""Create new units when capacity is added but no existing units are available"""
	for i in range(count):
		# Create unit near the building that triggered the capacity increase
		var spawn_position = _get_unit_spawn_position_near_building(building_node)
		
		var unit_data = {
			"unique_id": _get_next_unit_id(),
			"name": "Peasant " + str(unit_counter),
			"type": "peasant",
			"race": "human",
			"player_id": owner_player,
			"position": spawn_position,
			"living_quarters": null,
			"job": null,
			# Movement properties
			"current_path": [],
			"path_index": 0,
			"movement_state": "idle",
			"movement_target": null,
			"movement_cycle_step": 0,
			"work_timer": 0.0,
			"movement_speed": 25.0,
			"speed_multiplier": randf_range(0.85, 1.15)  # 85% to 115% speed variation
		}
		
		# Assign to the appropriate capacity immediately
		if capacity_type == "living":
			unit_data["living_quarters"] = building_node.name
		elif capacity_type == "worker":
			unit_data["job"] = building_node.name
		
		# Add unit to player data
		if not players_data[owner_player].has("units"):
			players_data[owner_player]["units"] = []
		players_data[owner_player]["units"].append(unit_data)
		
		# Note: Unit will only get sprite when it has both living quarters AND job
		# No automatic assignment completion - units must be manually assigned to both types
		
		print("Created new unit: ", unit_data["unique_id"], " assigned to ", capacity_type, " at ", building_node.name)

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
			
			print("Auto-matched unit ", unit_data["unique_id"], " to ", needed_capacity_type, " at ", child.name)
			return
	
	print("No available ", needed_capacity_type, " capacity found for unit ", unit_data["unique_id"])

func _create_initial_units_from_population():
	"""Dynamically create units based on population total for new games and loaded games"""
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		var pop_data = player_data.get("population", {})
		var total_population = pop_data.get("total", 10)
		
		# Clear existing units array and create new ones based on population
		player_data["units"] = []
		
		print("Creating ", total_population, " units for player ", player_id, " based on population total")
		
		# Create unassigned units at default spawn position
		for i in range(total_population):
			var unit_data = {
				"unique_id": _get_next_unit_id(),
				"name": "Peasant " + str(unit_counter),
				"type": "peasant",
				"race": "human",
				"player_id": player_id,
				"position": Vector2(200 + (i * 15), 200 + (i * 10)),  # Spread them out slightly
				"living_quarters": null,
				"job": null,
				# Movement properties
				"current_path": [],
				"path_index": 0,
				"movement_state": "idle",
				"movement_target": null,
				"movement_cycle_step": 0,
				"work_timer": 0.0,
				"movement_speed": 25.0,
				"speed_multiplier": randf_range(0.85, 1.15)  # 85% to 115% speed variation
			}
			
			player_data["units"].append(unit_data)
		
		print("Created ", total_population, " unassigned units for player ", player_id)

func _building_provides_capacity(building_type: String, capacity_type: String) -> bool:
	"""Check if a building type provides a specific capacity type"""
	match capacity_type:
		"living":
			return building_type in ["house", "town_center", "farmhouse"]
		"worker":
			return building_type in ["barracks", "fishing_hut", "farmhouse", "stoneworker", "lumber_mill", "lumberjack"]
	return false

func _get_building_max_capacity(building_type: String, capacity_type: String) -> int:
	"""Get the maximum capacity for a building type"""
	# Define capacity limits for different building types
	var capacity_limits = {
		"house": {"living": 7, "worker": 0},
		"farmhouse": {"living": 2, "worker": 6},
		"town_center": {"living": 20, "worker": 0},
		"barracks": {"living": 0, "worker": 8},
		"fishing_hut": {"living": 0, "worker": 5},
		"stoneworker": {"living": 0, "worker": 10},
		"lumber_mill": {"living": 0, "worker": 10},
		"lumberjack": {"living": 0, "worker": 10}
	}
	
	return capacity_limits.get(building_type, {}).get(capacity_type, 0)

func _update_unit_movements(delta: float):
	"""Update all unit movements each frame"""
	for player_id in players_data:
		if str(player_id) == "environment":
			continue
		
		var player_data = players_data[player_id]
		if not player_data.has("units"):
			continue
		
		for unit in player_data["units"]:
			# Only process units that have both assignments and are visible
			if unit.get("living_quarters", null) == null or unit.get("job", null) == null:
				continue
			
			var unit_sprite = map_objects_holder.get_node_or_null(unit["unique_id"])
			if not unit_sprite:
				continue
			
			_process_unit_movement(unit, unit_sprite, delta)

func _process_unit_movement(unit: Dictionary, sprite: Node2D, delta: float):
	"""Process movement for a single unit"""
	var movement_state = unit.get("movement_state", "idle")
	
	match movement_state:
		"idle":
			# Check if it's time to start moving
			unit["work_timer"] += delta
			if unit["work_timer"] >= 2.0:  # Stay idle for 2 seconds
				unit["work_timer"] = 0.0
				_start_unit_movement_cycle(unit)
		
		"moving":
			# Follow current path
			var current_path = unit.get("current_path", [])
			if current_path.is_empty():
				# No path - switch to idle
				unit["movement_state"] = "idle"
				return
			
			var path_index = unit.get("path_index", 0)
			if path_index >= current_path.size():
				# Reached end of path
				unit["movement_state"] = "idle"
				unit["current_path"] = []
				unit["path_index"] = 0
				_on_unit_reached_destination(unit)
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
				sprite.flip_h = direction.x > 0  # Flip when moving right
			
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
	
	print("Starting movement cycle for unit ", unit["unique_id"], " step: ", cycle_step)
	
	match cycle_step:
		0:  # At home - go to work
			_move_unit_to_building(unit, job, 1)
		1:  # At work - find resource connection and go there
			_move_unit_to_resource(unit, 2)
		2:  # At resource - go back to work
			_move_unit_to_building(unit, job, 3)
		3:  # Back at work - go home
			_move_unit_to_building(unit, living_quarters, 4)
		4:  # Back home - cycle complete, start over
			unit["movement_cycle_step"] = 0
			_start_unit_movement_cycle(unit)

func _on_unit_reached_destination(unit: Dictionary):
	"""Called when unit reaches its movement target"""
	var cycle_step = unit.get("movement_cycle_step", 0)
	print("Unit ", unit["unique_id"], " reached destination, cycle step: ", cycle_step)
	
	# Clear movement state
	unit["movement_state"] = "idle"
	unit["current_path"] = []
	unit["path_index"] = 0
	
	# Advance to next step in cycle
	unit["movement_cycle_step"] = (cycle_step + 1) % 5
	
	# Reset work timer for next phase
	unit["work_timer"] = 0.0
	
	# Immediately start the next part of the movement cycle
	_start_unit_movement_cycle(unit)

func _move_unit_to_building(unit: Dictionary, building_name: String, next_step: int):
	"""Move unit to a specific building using pre-calculated paths from connections"""
	if building_name == null:
		return
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(building_name))
	if not building_node:
		print("Building not found: ", building_name)
		return
	
	# Try to find the pre-calculated path from job connections
	var connections = unit.get("job_connections", [])
	var path = []
	
	# Look for a connection to this building
	for connection in connections:
		if connection.get("name") == building_name and connection.has("path"):
			path = connection.get("path", [])
			break
	
	# Fallback: if no pre-calculated path found, calculate it
	if path.is_empty():
		var unit_pos = unit["position"]
		var target_pos = building_node.position
		
		# Get actual path using existing pathfinding system
		path = _get_path_between_positions(unit_pos, target_pos)
		if path.is_empty():
			# Fallback to direct path if pathfinding fails
			path = [target_pos]
	
	unit["current_path"] = path
	unit["path_index"] = 0
	unit["movement_state"] = "moving"
	unit["movement_target"] = building_name
	unit["movement_cycle_step"] = next_step - 1  # Will be incremented when reached
	
	print("Unit ", unit["unique_id"], " moving to building: ", building_name, " with ", path.size(), " waypoints")

func _move_unit_to_resource(unit: Dictionary, next_step: int):
	"""Move unit to a resource connected to their workplace"""
	var job_building = unit.get("job", null)
	if job_building == null:
		print("Unit has no job building, skipping resource step")
		# Skip to next step if no job
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	var building_node = map_objects_holder.get_node_or_null(NodePath(job_building))
	if not building_node:
		print("Job building node not found: ", job_building)
		# Skip to next step if building not found
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	# Get building connections using cached data if available
	var connections = unit.get("job_connections", [])
	if connections.is_empty():
		# Fallback: calculate if not cached
		connections = _find_building_connections_for_unit(building_node)
		unit["job_connections"] = connections  # Cache for future use
	
	var resource_connections = []
	
	# Filter for resource connections (trees, mountains, fish) from the pre-calculated connections
	for connection in connections:
		var conn_type = connection.get("type", "")
		if conn_type in ["tree", "mountain", "fish"]:  # These are resource types with pre-calculated paths
			resource_connections.append(connection)
	
	# Find nearest farm as a resource (farms don't have pre-calculated paths)
	var farm_resource = _find_nearest_farm(unit["position"])
	if farm_resource:
		# Check if this farm is connected to the job building (within range and path-findable)
		# For now, include all farms as potential resources
		resource_connections.append(farm_resource)
	
	if resource_connections.is_empty():
		# No resource connection - skip resource step and go to next part of cycle
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	# Find the closest resource connection (shortest distance)
	var closest_connection = null
	var shortest_distance = INF
	
	for connection in resource_connections:
		var distance = connection.get("distance", INF)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_connection = connection
	
	if closest_connection == null:
		# No valid resource found
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	# Use the existing path from the building connection, or calculate for farms and fish
	var existing_path = closest_connection.get("path", [])
	
	# For farms and fish, we need to calculate the path since it wasn't pre-calculated
	if existing_path.is_empty() and closest_connection.get("type") == "farm":
		var farm_node = map_objects_holder.get_node_or_null(NodePath(closest_connection.get("name")))
		if farm_node:
			# Calculate path from unit's current position to farm
			existing_path = _get_path_between_positions(unit["position"], farm_node.position)
	elif existing_path.is_empty() and closest_connection.get("type") == "fish":
		# For fish, use the tile_coords stored in the connection
		if closest_connection.has("tile_coords"):
			var fish_world_pos = tilemap_layer.map_to_local(closest_connection.get("tile_coords"))
			# Calculate path from unit's current position to fish
			existing_path = _get_path_between_positions(unit["position"], fish_world_pos)
	
	if existing_path.is_empty():
		# No path available - skip to next step
		print("No path available to resource: ", closest_connection.get("name"))
		unit["movement_cycle_step"] = next_step
		unit["movement_state"] = "idle"
		return
	
	unit["current_path"] = existing_path
	unit["path_index"] = 0
	unit["movement_state"] = "moving"
	unit["movement_target"] = closest_connection.get("name", "unknown")
	unit["movement_cycle_step"] = next_step - 1  # Will be incremented when reached
	
	print("Unit ", unit["unique_id"], " moving to resource: ", closest_connection.get("name"), " (", closest_connection.get("type"), ")")

func _find_nearest_mountain(from_position: Vector2) -> Dictionary:
	"""Find the nearest mountain and return connection data"""
	var mountains = get_environment_objects("mountains")
	var nearest = null
	var nearest_distance = INF
	
	for mountain_id in mountains:
		var mountain_data = mountains[mountain_id]
		var mountain_pos = tilemap_layer.map_to_local(mountain_data["tile_coords"])
		var distance = from_position.distance_to(mountain_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = {
				"name": mountain_id,
				"type": "mountain",
				"distance": nearest_distance,
				"object_type": "mountain"
			}
	
	return nearest

func _find_nearest_tree(from_position: Vector2) -> Dictionary:
	"""Find the nearest tree and return connection data"""
	var trees = get_environment_objects("trees")
	var nearest = null
	var nearest_distance = INF
	
	for tree_id in trees:
		var tree_data = trees[tree_id]
		var tree_pos = tilemap_layer.map_to_local(tree_data["tile_coords"])
		var distance = from_position.distance_to(tree_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = {
				"name": tree_id,
				"type": "tree",
				"distance": nearest_distance,
				"object_type": "tree"
			}
	
	return nearest

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
	"""Get building connections using the exact same system as building details modal"""
	# Create a temporary building details modal to access its connection finding
	var BuildingDetailsModalScript = preload("res://scripts/ui/building_details_modal.gd")
	var temp_modal = BuildingDetailsModalScript.new()
	
	# Use the modal's connection finding system
	var connections = temp_modal._find_building_connections(building, self)
	temp_modal.queue_free()  # Clean up temp modal
	
	return connections

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


func _start_world_creation_mode():
	print("Game: Starting world creation mode")
	is_in_world_creation = true
	
	# Hide game header during world creation
	if game_header:
		game_header.visible = false
	
	# Hide game footer during world creation
	if game_footer:
		game_footer.visible = false
	
	# Create world creator
	var WorldCreationModal = preload("res://scripts/main/world_creation_modal.gd")
	world_creator = WorldCreationModal.new()
	world_creator.name = "WorldCreationModal"
	add_child(world_creator)
	
	# Hide normal UI elements
	$UI_Layer/MenuButtonContainer.hide()
	$UI_Layer/TurnControlsContainer.hide()
	
	# Setup world creator with direct UI control
	world_creator.setup_direct_ui(self, tilemap_layer, camera)
	
	print("Game: World creation mode active with direct UI control")

func _setup_world_creation_delayed():
	# Remove this function - not needed with direct UI approach
	pass

func _connect_world_creation_buttons():
	# Remove this function - not needed with direct UI approach  
	pass

func _debug_print_ui_structure(node: Node, indent: int = 0):
	# Keep this for debugging if needed
	var indent_str = "  ".repeat(indent)
	print("%s%s" % [indent_str, node.name])
	for child in node.get_children():
		_debug_print_ui_structure(child, indent + 1)

# Direct button handlers that call the world creator
func _on_world_creation_continue():
	print("Game: Continue button pressed!")
	if world_creator and world_creator.has_method("_on_continue_pressed"):
		world_creator._on_continue_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _on_world_creation_back():
	print("Game: Back button pressed!")
	if world_creator and world_creator.has_method("_on_back_pressed"):
		world_creator._on_back_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _finish_world_creation(generated_world_data: Dictionary):
	print("Game: Finishing world creation")
	is_in_world_creation = false
	
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
	
	# Show game header now that the game has started
	if game_header:
		game_header.visible = true
		print("Game: Game header now visible after world creation")
	
	# Show game footer now that the game has started
	if game_footer:
		game_footer.visible = true
		print("Game: Game footer now visible after world creation")
	
	# Don't center camera - preserve current position from world creation
	# camera_controller.center_camera()
	print("Game: World creation complete, game ready.")

func _place_starting_town_center():
	# Get starting tile position from world data
	if not world_data.has("starting_tile"):
		print("Warning: No starting tile found in world data")
		return
		
	var starting_tile = world_data["starting_tile"]
	var tile_coords = Vector2i(int(starting_tile.x), int(starting_tile.y))
	print("Game: Placing town center at tile: ", tile_coords)
	
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
			print("Game: Cleared features from tile: ", tile_coords)

func _place_town_center_building(tile_coords: Vector2i):
	# Get player race and building choice
	var player_data = world_data.get("player_data", {})
	var selected_race = player_data.get("race", "human")
	var starting_building = player_data.get("starting_building", "town_center")
	
	print("Game: Placing ", starting_building, " for race ", selected_race, " at ", tile_coords)
	
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
		
		# Position it at tile center (building script will handle sprite centering)
		var world_pos = tilemap_layer.map_to_local(tile_coords)
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
		
		# Add building to player's buildings list
		var owner_player = setup_data.get("owner_player", 1)
		if players_data.has(owner_player):
			players_data[owner_player]["buildings"].append(building_name)
			print("Game: Added town center ", building_name, " to player ", owner_player, " buildings list")
		
		print("Game: Successfully placed ", starting_building, " at world position: ", world_pos)
		
		# Auto-save after placing town center
		print("Game: Auto-saving after town center placement...")
		if _execute_save():
			print("Game: Auto-save successful!")
		else:
			print("Game: Auto-save failed, but continuing game...")
	else:
		print("Warning: Could not find building texture: ", building_texture_path)

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
	
	# No need to update values anymore
	print("Game: Game header created and connected")
	
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
			
			if building_scene.has_method("setup"):
				building_scene.setup(setup_data)
			
			# Set occupancy metadata on the building node
			building_scene.set_meta("living_occupancy", building_info.get("living_occupancy", 0))
			building_scene.set_meta("worker_occupancy", building_info.get("worker_occupancy", 0))
			
			building_scene.z_index = building_info.get("z_index", 5)
			map_objects_holder.add_child(building_scene)
			
			# Add building to player's buildings list
			var owner_player = setup_data.get("owner_player", 1)
			if players_data.has(owner_player):
				players_data[owner_player]["buildings"].append(building_name)
		else:
			push_warning("Could not restore building with texture: " + building_info.get("texture_path", "unknown"))

func _restore_environment_objects(environment_objects_data: Array):
	# Restore environment objects (mountains, trees, and fish) with their unique IDs
	
	if not tilemap_layer or not map_objects_holder:
		print("Warning: Cannot restore environment objects - missing tilemap or objects holder")
		return
	
	for obj_info in environment_objects_data:
		var obj_name = obj_info.get("name", "")
		var obj_position = obj_info.get("position", Vector2.ZERO)
		var environment_id = obj_info.get("environment_id", obj_name)
		var object_type = obj_info.get("object_type", "unknown")
		
		# Find the corresponding scene node that was placed during map generation
		var existing_node = null
		for child in map_objects_holder.get_children():
			# Check if position matches (within small tolerance)
			if child.position.distance_to(obj_position) < 5.0:
				existing_node = child
				break
		
		if existing_node:
			# Update the node with saved data
			existing_node.name = environment_id
			existing_node.set_meta("environment_id", environment_id)
			
			# Re-register with environment system to restore proper tracking
			if object_type == "mountain":
				register_mountain(existing_node)
			elif object_type == "tree":
				register_tree(existing_node)
			elif object_type == "fish":
				register_fish(existing_node)
			
			# print("Game: Restored environment object ", environment_id, " at ", obj_position)
		else:
			push_warning("Could not find existing node to restore environment object: " + environment_id)

func _setup_game_footer():
	# Create and setup the game footer
	var GameFooterScript = preload("res://scripts/managers/game_footer.gd")
	game_footer = GameFooterScript.new()
	ui_layer.add_child(game_footer)
	
	# Connect footer signals
	game_footer.build_pressed.connect(_on_build_pressed)
	game_footer.end_day_pressed.connect(_on_end_day_pressed)
	
	# Set initial day label
	if game_footer:
		game_footer.set_day_text(1)
	
	print("Game: Game footer created and connected")

func _setup_info_modals():
	# Create info modals with different starting positions
	var PlayersModalScript = preload("res://scripts/ui/players_modal.gd")
	var ResourcesModalScript = preload("res://scripts/ui/resources_modal.gd")
	var BuildingsModalScript = preload("res://scripts/ui/buildings_modal.gd")
	var PopulationModalScript = preload("res://scripts/ui/population_modal.gd")
	var ArmyModalScript = preload("res://scripts/ui/army_modal.gd")
	var UnitsModalScript = preload("res://scripts/ui/units_modal.gd")
	
	# Calculate positions to prevent overlap
	var base_pos = Vector2(10, 60)  # Base position under header
	var modal_offset = Vector2(50, 50)  # Offset for each new modal
	
	players_modal = PlayersModalScript.new(self, base_pos)
	resources_modal = ResourcesModalScript.new(self, base_pos + modal_offset)
	buildings_modal = BuildingsModalScript.new(self, base_pos + modal_offset * 2)
	population_modal = PopulationModalScript.new(self, base_pos + modal_offset * 3)
	army_modal = ArmyModalScript.new(self, base_pos + modal_offset * 4)
	units_modal = UnitsModalScript.new(self, base_pos + modal_offset * 5)
	
	# Add modals to UI layer
	ui_layer.add_child(players_modal)
	ui_layer.add_child(resources_modal)
	ui_layer.add_child(buildings_modal)
	ui_layer.add_child(population_modal)
	ui_layer.add_child(army_modal)
	ui_layer.add_child(units_modal)
	
	# Connect modal close signals (optional)
	players_modal.modal_closed.connect(_on_modal_closed)
	resources_modal.modal_closed.connect(_on_modal_closed)
	buildings_modal.modal_closed.connect(_on_modal_closed)
	population_modal.modal_closed.connect(_on_modal_closed)
	army_modal.modal_closed.connect(_on_modal_closed)
	units_modal.modal_closed.connect(_on_modal_closed)
	
	print("Game: Info modals setup complete")

func _on_modal_closed(modal_type: String):
	print("Game: Modal closed: ", modal_type)

func _on_end_day_pressed():
	print("Game: End day pressed")
	# Call turn manager to end the turn
	if is_instance_valid(turn_manager):
		turn_manager.end_turn()
		# Update the footer day label with new day
		if game_footer:
			game_footer.set_day_text(turn_manager.get_day())
		
		# Refresh open modals to show updated data
		if resources_modal and resources_modal.is_open:
			resources_modal.refresh_content()
		if population_modal and population_modal.is_open:
			population_modal.refresh_content()
		if buildings_modal and buildings_modal.is_open:
			buildings_modal.refresh_content()

# Footer button handlers
func _on_build_pressed():
	print("Game: Build button pressed")
	_open_build_selection_modal()

func _open_build_selection_modal():
	# Create build selection modal if it doesn't exist
	if not build_selection_modal:
		var BuildSelectionScript = preload("res://scripts/ui/build_selection_modal.gd")
		build_selection_modal = BuildSelectionScript.new(self, Vector2(200, 100))
		ui_layer.add_child(build_selection_modal)
		build_selection_modal.building_selected.connect(_on_building_selected_for_placement)
	
	# Toggle the modal
	build_selection_modal.toggle()

func _on_building_selected_for_placement(building_type: String, building_name: String):
	print("Game: Building selected for placement: ", building_name)
	_open_building_placement_modal(building_type, building_name)

func _open_building_placement_modal(building_type: String, building_name: String):
	# Close existing placement modal if open
	if building_placement_modal:
		building_placement_modal.queue_free()
	
	# Create new placement modal
	var PlacementScript = preload("res://scripts/ui/building_placement_modal.gd")
	building_placement_modal = PlacementScript.new(self, building_type, building_name, Vector2(300, 150))
	ui_layer.add_child(building_placement_modal)
	
	# Connect placement signals  
	building_placement_modal.place_building_confirmed.connect(_on_building_placement_confirmed_with_type.bind(building_type))
	building_placement_modal.placement_cancelled.connect(_on_building_placement_cancelled)
	
	# Show the modal
	building_placement_modal.toggle()

func _on_building_placement_confirmed_with_type(build_more: bool, building_type: String):
	print("Game: Building placement confirmed for: ", building_type, " build_more: ", build_more)
	# Store the build_more state for use after placement
	building_placement_build_more = build_more
	# Start building placement preview mode
	_start_building_placement(building_type)

func _on_building_placement_confirmed(building_type: String, build_more: bool = false):
	print("Game: Building placement confirmed for: ", building_type, " build_more: ", build_more)
	# Store the build_more state for use after placement
	building_placement_build_more = build_more
	# Start building placement preview mode
	_start_building_placement(building_type)

func _on_building_placement_cancelled():
	print("Game: Building placement cancelled")

# Header button handlers
func _on_header_settings_pressed():
	# Delegate to existing UI manager settings functionality
	if ui_manager and ui_manager.has_method("open_main_modal"):
		ui_manager.open_main_modal()

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

func _cancel_world_creation():
	print("Game: Cancelling world creation")
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
	print("Game: Generating world data..."); var generator = WorldGenerator.new()
	world_data = generator.generate_world_data(MAP_WIDTH, MAP_HEIGHT)
	if world_data.is_empty(): push_error("Game: World generator returned empty data."); return false
	print("Game: Generation complete."); return true


func _clear_and_draw_map():
	print("Game: Drawing game map...");
	if not is_instance_valid(tilemap_layer): push_error("Game: Cannot draw, TileMapLayer is invalid."); return
	tilemap_layer.clear()
	if world_data.is_empty(): print("Game: No world data loaded to draw."); return
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])
		else: push_warning("Game: Skipping invalid tile data at coords: %s" % str(coords))
	print("Game: Map drawing complete.")


# --- Save/Load Wrappers & UI Callbacks ---

func _on_save_requested():
	print("Game: Save requested by UI button.")
	_execute_save()


func _on_save_requested_from_ui(pending_action: String):
	print("Game: _on_save_requested_from_ui called for action: ", pending_action) # DEBUG
	if _execute_save():
		print("Game: Save successful, telling UIManager to perform action.") # DEBUG
		if is_instance_valid(ui_manager):
			ui_manager.perform_pending_action_after_save()
	else:
		print("Game: Save failed, UI manager should handle reopening menu.") # DEBUG
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
					"worker_occupancy": child.get_meta("worker_occupancy", 0)
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
		"current_save_path": current_save_path 
	}
	var saved_path = SaveLoadManager.save_game(game_state, current_save_path)
	if not saved_path.is_empty():
		current_save_path = saved_path; return true
	else: print("Game: Save failed in SaveLoadManager."); return false


func _on_action_confirmed_from_ui(action_name: String):
	print("Game: _on_action_confirmed_from_ui called for action: ", action_name) # DEBUG
	if is_instance_valid(ui_manager):
		ui_manager._perform_action(action_name) # Tell UI Manager to proceed


# Placeholder for simple load button (Needs replacing with UI Manager integration)
func _on_load_pressed():
	push_warning("Game: Simple Load button pressed - functionality should be moved to UIManager Load Modal.")
	var first_save_path = ""
	var dir = DirAccess.open(SaveLoadManager.SAVE_DIR);
	if dir: dir.list_dir_begin(); var f=dir.get_next(); while f!="": if !dir.current_is_dir() and f.ends_with(".save"): first_save_path = SaveLoadManager.SAVE_DIR.path_join(f); break; f=dir.get_next()
	if first_save_path.is_empty(): push_warning("Game: No save file found for simple load."); return
	print("Game: Attempting simple load of: ", first_save_path)
	var loaded_state = SaveLoadManager.load_game(first_save_path)
	if not loaded_state.is_empty():
		world_data = loaded_state["map_data"]; current_save_path = loaded_state["current_save_path"]
		turn_manager.set_day(loaded_state["current_day"]); _clear_and_draw_map(); map_object_manager.clear_objects()
		map_object_manager.place_objects(world_data); camera_controller.center_camera()
		# Header is visible by default for loaded games
		print("Game: Loaded successfully via simple load.")
	else: 
		print("Game: Failed simple load.")

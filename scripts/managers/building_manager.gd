# scripts/managers/building_manager.gd
extends Node

# Handles building-related operations such as placement, validation, and updates

# References
@export var tilemap_layer: TileMapLayer
@export var map_objects_holder: Node2D
@export var turn_manager: Node
@export var players_data: Dictionary
var game_node: Node  # Reference to main game node for path recalculation

var building_counter: Dictionary = {}

func set_game_node(game: Node):
	"""Set reference to main game node for path recalculation after building placement"""
	game_node = game

func update_building_preview(building_preview_sprite: Sprite2D, _mouse_pos: Vector2, building_type: String):
	var world_pos = tilemap_layer.local_to_map(_mouse_pos)
	var tile_coords = tilemap_layer.local_to_map(world_pos)

	if building_preview_sprite and building_preview_sprite.texture:
		var tile_center_pos = tilemap_layer.map_to_local(tile_coords)
		building_preview_sprite.position = tile_center_pos
		var can_place = can_place_building_at_tile(tile_coords)
		building_preview_sprite.modulate = Color(0.7, 1.0, 0.7, 0.7) if can_place else Color(1.0, 0.7, 0.7, 0.7)

func can_place_building_at_tile(tile_coords: Vector2i) -> bool:
	var used_rect = tilemap_layer.get_used_rect()
	if not used_rect.has_point(tile_coords):
		return false

	for child in map_objects_holder.get_children():
		if is_building_node(child):
			var building_tile = tilemap_layer.local_to_map(child.position)
			if building_tile == tile_coords:
				return false
	return true

func place_building_at_tile(tile_coords: Vector2i, building_type: String):
	var building_texture_path = get_building_texture_path(building_type)
	if ResourceLoader.exists(building_texture_path):
		var building_id = get_next_building_id(building_type)
		var building_name = building_type + str(building_id)
		var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
		building_scene.name = building_name
		building_scene.position = tilemap_layer.map_to_local(tile_coords)
		building_scene.z_index = 5
		var setup_data = {
			"type": building_type,
			"texture_path": building_texture_path,
			"owner_player": 1,
			"construction_day": turn_manager.get_day(),
			"living_occupancy": 0,
			"worker_occupancy": 0
		}
		if building_type == "farm":
			setup_data["farm_state"] = "tilled"
		if building_scene.has_method("setup"):
			building_scene.setup(setup_data)
		building_scene.set_meta("living_occupancy", 0)
		building_scene.set_meta("worker_occupancy", 0)
		map_objects_holder.add_child(building_scene)
		var owner_player = setup_data.get("owner_player", 1)
		if players_data.has(owner_player):
			var player_data = players_data[owner_player]
			if not player_data.has("buildings"):
				player_data["buildings"] = []
			player_data["buildings"].append(building_name)
		print("Building placed successfully.")
		
		# Recalculate paths for all units with jobs that might be affected by the new building
		if game_node:
			_recalculate_affected_unit_paths(building_name, owner_player)
	else:
		print("Building texture not found.")

func get_building_texture_path(building_type: String) -> String:
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
			return "res://assets/buildings/human_farm_tilled.png"
		_:
			return "res://assets/buildings/human_towncentre-export.png"

func get_next_building_id(building_type: String) -> int:
	if not building_counter.has(building_type):
		building_counter[building_type] = 0
	building_counter[building_type] += 1
	return building_counter[building_type]

func is_building_node(node: Node) -> bool:
	var building_types = ["house", "fishing_hut", "town_center", "barracks", "farm", "farmhouse", "stoneworker", "lumberjack"]
	for building_type in building_types:
		if node.name.begins_with(building_type):
			return true
	return false
func _recalculate_affected_unit_paths(new_building_name: String, owner_player: int):
	"""Recalculate paths for all units with jobs, since a new building might be in range"""
	if not game_node or not players_data.has(owner_player):
		return
	
	var player_data = players_data[owner_player]
	var units = player_data.get("units", [])
	
	# Check all units with jobs - they might need path updates
	for unit in units:
		var job = unit.get("job")
		if job:  # Unit has a job assignment
			# Re-cache the job connections to include the new building
			game_node._cache_job_connections_for_unit(unit)
			print("BuildingManager: Recalculated paths for unit ", unit.get("unique_id"), " after building ", new_building_name, " was placed")

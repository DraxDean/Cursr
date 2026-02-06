# scripts/ui/buildings_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("buildings", "Buildings", start_position)

func refresh_content():
	clear_content()
	
	# Ensure resource rates are calculated before displaying
	var player_id = 1
	if game_ref and game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(player_id)
	
	var buildings_label = Label.new()
	buildings_label.text = "Player Buildings:"
	buildings_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(buildings_label)
	
	# Get buildings using the new player data system
	var player_buildings = []
	if game_ref and game_ref.has_method("get_player_buildings"):
		var player_building_names = game_ref.get_player_buildings(1)  # Player 1
		
		# Get detailed info for each building
		if game_ref.map_objects_holder:
			for child in game_ref.map_objects_holder.get_children():
				if child.name in player_building_names:
					var building_info = {
						"name": child.name,
						"position": child.position,
						"type": game_ref._extract_building_type_from_name(child.name),
						"living_occupancy": child.get_meta("living_occupancy", 0),
						"worker_occupancy": child.get_meta("worker_occupancy", 0)
					}
					player_buildings.append(building_info)
	
	if player_buildings.is_empty():
		var no_buildings = Label.new()
		no_buildings.text = "No buildings constructed yet"
		no_buildings.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(no_buildings)
	else:
		for building in player_buildings:
			var building_container = HBoxContainer.new()
			add_content_child(building_container)
			
			var building_icon = Label.new()
			building_icon.text = _get_building_icon(building["type"])
			building_icon.custom_minimum_size = Vector2(25, 20)
			building_container.add_child(building_icon)
			
			var building_info_container = VBoxContainer.new()
			building_container.add_child(building_info_container)
			
			var building_name = Label.new()
			building_name.text = building["name"] + " (" + building["type"].replace("_", " ").capitalize() + ")"
			building_name.add_theme_color_override("font_color", Color.CYAN)
			building_info_container.add_child(building_name)
			
			var building_coords = Label.new()
			var tile_coords = game_ref.tilemap_layer.local_to_map(building["position"])
			building_coords.text = "Location: (" + str(tile_coords.x) + ", " + str(tile_coords.y) + ")"
			building_coords.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			building_info_container.add_child(building_coords)
			
			# Add production/occupancy info
			var production_text = _get_building_production_text(building["type"], building["worker_occupancy"])
			if production_text != "":
				var production_label = Label.new()
				production_label.text = production_text
				production_label.add_theme_color_override("font_color", Color.GREEN)
				building_info_container.add_child(production_label)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Building summary with type breakdown
	var summary_label = Label.new()
	summary_label.text = "Total Buildings: " + str(player_buildings.size())
	summary_label.add_theme_color_override("font_color", Color.YELLOW)
	add_content_child(summary_label)
	
	# Building type counts
	var building_counts = {}
	for building in player_buildings:
		var type = building["type"]
		building_counts[type] = building_counts.get(type, 0) + 1
	
	for type in building_counts:
		var count_label = Label.new()
		count_label.text = "  " + type.replace("_", " ").capitalize() + ": " + str(building_counts[type])
		count_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		add_content_child(count_label)

func _get_building_type(building_name: String) -> String:
	if building_name.begins_with("TownCenter"):
		return "town_center"
	elif building_name.contains("House"):
		return "house"
	elif building_name.contains("Barracks"):
		return "barracks"
	elif building_name.contains("FishingHut"):
		return "fishing_hut"
	elif building_name.contains("Farmhouse"):
		return "farmhouse"
	elif building_name.contains("Farm"):
		return "farm"
	else:
		return "unknown_building"

func _get_building_icon(building_type: String) -> String:
	match building_type:
		"town_center":
			return "🏛️"
		"house":
			return "🏠"
		"barracks":
			return "⚔️"
		"fishing_hut":
			return "🎣"
		"farmhouse":
			return "🏘️"
		"farm":
			return "🌾"
		_:
			return "🏗️"

func _get_building_production_text(building_type: String, worker_count: int) -> String:
	"""Get production text for a building based on type and workers"""
	match building_type:
		"fishing_hut":
			var food = worker_count * 5
			return "Produces: +" + str(food) + " Food/day"
		"lumberjack", "lumber_mill":
			var wood = worker_count * 1
			return "Produces: +" + str(wood) + " Wood/day"
		"stoneworker":
			var stone = worker_count * 1
			return "Produces: +" + str(stone) + " Stone/day"
		"town_center":
			var science = worker_count * 3
			return "Produces: +" + str(science) + " Science/day"
		_:
			return ""
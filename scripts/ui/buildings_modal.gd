# scripts/ui/buildings_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("buildings", "Buildings", start_position)

func refresh_content():
	clear_content()
	
	var buildings_label = Label.new()
	buildings_label.text = "Player Buildings:"
	buildings_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(buildings_label)
	
	# Count and list buildings owned by player
	var player_buildings = []
	if game_ref and game_ref.map_objects_holder:
		for child in game_ref.map_objects_holder.get_children():
			if child.name.begins_with("TownCenter_") or child.name.contains("Building_"):
				var building_info = {
					"name": child.name,
					"position": child.position,
					"type": _get_building_type(child.name)
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
			building_name.text = building["type"].replace("_", " ").capitalize()
			building_name.add_theme_color_override("font_color", Color.CYAN)
			building_info_container.add_child(building_name)
			
			var building_coords = Label.new()
			var tile_coords = game_ref.tilemap_layer.local_to_map(building["position"])
			building_coords.text = "Location: (" + str(tile_coords.x) + ", " + str(tile_coords.y) + ")"
			building_coords.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			building_info_container.add_child(building_coords)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Building summary
	var summary_label = Label.new()
	summary_label.text = "Total Buildings: " + str(player_buildings.size())
	summary_label.add_theme_color_override("font_color", Color.YELLOW)
	add_content_child(summary_label)

func _get_building_type(building_name: String) -> String:
	if building_name.begins_with("TownCenter"):
		return "town_center"
	elif building_name.contains("House"):
		return "house"
	elif building_name.contains("Barracks"):
		return "barracks"
	elif building_name.contains("FishingHut"):
		return "fishing_hut"
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
		_:
			return "🏗️"
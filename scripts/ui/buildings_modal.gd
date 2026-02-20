# scripts/ui/buildings_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("buildings", "Buildings", start_position)

func _ready() -> void:
	# Call parent _ready() first
	super._ready()
	
	# Customize size for buildings list - wider and taller to accommodate many buildings
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(viewport_size.x * 0.32, viewport_size.y * 0.65)
		size = custom_minimum_size
		# Position it to the right of other modals
		if position == Vector2.ZERO:
			position = Vector2(viewport_size.x * 0.26, 60)  # Right of other modals

func refresh_content():
	clear_content()
	
	# Ensure resource rates are calculated before displaying
	var player_id = 1
	if game_ref and game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(player_id)
	
	# Header section
	var header_label = Label.new()
	header_label.text = "Player Buildings:"
	header_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(header_label)
	
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
	
	# Total buildings summary (before scroll area)
	var summary_label = Label.new()
	summary_label.text = "Total: " + str(player_buildings.size())
	summary_label.add_theme_color_override("font_color", Color.YELLOW)
	summary_label.add_theme_font_size_override("font_size", 12)
	add_content_child(summary_label)
	
	# Scrollable container for building list
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 200)  # Height for scrolling
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Style the scroll container with a subtle background
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0, 0, 0, 0.3)
	scroll_style.border_width_left = 1
	scroll_style.border_width_right = 1
	scroll_style.border_width_top = 1
	scroll_style.border_width_bottom = 1
	scroll_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	scroll_container.add_theme_stylebox_override("bg", scroll_style)
	
	add_content_child(scroll_container)
	
	# VBox inside the scroll container for building list
	var list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(list_container)
	
	if player_buildings.is_empty():
		var no_buildings = Label.new()
		no_buildings.text = "No buildings constructed yet"
		no_buildings.add_theme_color_override("font_color", Color.GRAY)
		list_container.add_child(no_buildings)
	else:
		for building in player_buildings:
			# Create a subtle background panel for each building item
			var item_panel = Panel.new()
			item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_panel.custom_minimum_size = Vector2(0, 65)  # Minimum height for each item
			var item_style = StyleBoxFlat.new()
			item_style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
			item_style.border_width_left = 1
			item_style.border_width_right = 1
			item_style.border_width_top = 1
			item_style.border_width_bottom = 1
			item_style.border_color = Color(0.2, 0.4, 0.6, 0.4)
			item_style.set_corner_radius_all(2)
			item_style.set_content_margin_all(5)
			item_panel.add_theme_stylebox_override("panel", item_style)
			list_container.add_child(item_panel)
			
			var building_container = HBoxContainer.new()
			building_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			building_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			building_container.add_theme_constant_override("separation", 8)
			item_panel.add_child(building_container)
			
			var building_icon = Label.new()
			building_icon.text = _get_building_icon(building["type"])
			building_icon.custom_minimum_size = Vector2(35, 35)
			building_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			building_container.add_child(building_icon)
			
			var building_info_container = VBoxContainer.new()
			building_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			building_info_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			building_info_container.add_theme_constant_override("separation", 2)
			building_container.add_child(building_info_container)
			
			var building_name = Label.new()
			building_name.text = building["name"] + " (" + building["type"].replace("_", " ").capitalize() + ")"
			building_name.add_theme_color_override("font_color", Color.CYAN)
			building_name.add_theme_font_size_override("font_size", 12)
			building_info_container.add_child(building_name)
			
			var building_coords = Label.new()
			var tile_coords = game_ref.tilemap_layer.local_to_map(building["position"])
			building_coords.text = "Location: (" + str(tile_coords.x) + ", " + str(tile_coords.y) + ")"
			building_coords.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			building_coords.add_theme_font_size_override("font_size", 11)
			building_info_container.add_child(building_coords)
			
			# Add production/occupancy info
			var production_text = _get_building_production_text(building["type"], building["worker_occupancy"])
			if production_text != "":
				var production_label = Label.new()
				production_label.text = production_text
				production_label.add_theme_color_override("font_color", Color.GREEN)
				production_label.add_theme_font_size_override("font_size", 11)
				building_info_container.add_child(production_label)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Building type counts (footer section)
	var building_counts = {}
	for building in player_buildings:
		var type = building["type"]
		building_counts[type] = building_counts.get(type, 0) + 1
	
	var type_breakdown_label = Label.new()
	type_breakdown_label.text = "By Type:"
	type_breakdown_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	type_breakdown_label.add_theme_font_size_override("font_size", 11)
	add_content_child(type_breakdown_label)
	
	for type in building_counts:
		var count_label = Label.new()
		count_label.text = "  " + type.replace("_", " ").capitalize() + ": " + str(building_counts[type])
		count_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		count_label.add_theme_font_size_override("font_size", 10)
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
		"research":
			return "🔬"
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
		"research":
			var science = worker_count * 3
			return "Produces: +" + str(science) + " Science/day"
		_:
			return ""
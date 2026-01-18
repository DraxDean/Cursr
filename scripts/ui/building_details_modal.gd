extends Control

signal close_requested

var building_node: Node2D
var building_data: Dictionary
var is_dragging: bool = false
var drag_offset: Vector2

func _ready():
	print("Building Details Modal: _ready() called")
	_setup_modal()
	print("Building Details Modal: _setup_modal() completed")

func _setup_modal():
	# Make sure modal is visible and on top
	visible = true
	z_index = 100
	
	# Set initial position and size like other modals
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(viewport_size.x * 0.3, viewport_size.y * 0.4)
		size = custom_minimum_size
		position = Vector2(50, 80)  # Below header
	
	# Semi-transparent background panel with border
	var background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)  # Semi-transparent black
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	background_panel.add_theme_stylebox_override("panel", style_box)
	add_child(background_panel)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Header container with title and close button (draggable area)
	var header_container = HBoxContainer.new()
	header_container.custom_minimum_size.y = 30
	header_container.mouse_filter = Control.MOUSE_FILTER_PASS
	main_container.add_child(header_container)
	
	# Title label (draggable area)
	var title_label = Label.new()
	title_label.text = "Building Details"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header_container.add_child(title_label)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.flat = false
	close_button.pressed.connect(_on_close_pressed)
	header_container.add_child(close_button)
	
	# Content area with scroll
	var content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_scroll)
	
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 15)
	content_scroll.add_child(content_container)
	
	# Add padding to main container
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	
	# Building image section
	var image_section = _create_image_section()
	content_container.add_child(image_section)
	
	# Building info section
	var info_section = _create_info_section()
	content_container.add_child(info_section)
	
	# Building stats section
	var stats_section = _create_stats_section()
	content_container.add_child(stats_section)
	
	# Actions section
	var actions_section = _create_actions_section()
	content_container.add_child(actions_section)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is in header area (first 40 pixels)
				if event.position.y <= 40:
					is_dragging = true
					drag_offset = event.position
					move_to_front()  # Bring to front when starting drag
			else:
				is_dragging = false
	elif event is InputEventMouseMotion:
		if is_dragging:
			position += event.relative

func _create_image_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Building Image"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var image_container = CenterContainer.new()
	image_container.custom_minimum_size = Vector2(0, 100)
	section.add_child(image_container)
	
	var building_image = TextureRect.new()
	building_image.name = "BuildingImage"  # Explicit name for find_child
	building_image.custom_minimum_size = Vector2(64, 64)
	building_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.add_child(building_image)
	
	return section

func _create_info_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Building Information"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"  # Set explicit name
	info_container.add_theme_constant_override("separation", 5)
	section.add_child(info_container)
	
	return section

func _create_stats_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Building Statistics"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"  # Set explicit name
	stats_container.add_theme_constant_override("separation", 5)
	section.add_child(stats_container)
	
	return section

func _create_actions_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Actions"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var actions_container = HBoxContainer.new()
	actions_container.add_theme_constant_override("separation", 10)
	section.add_child(actions_container)
	
	# Dynamic actions based on building type
	var building_type = building_data.get("building_type", "unknown") if building_data else "unknown"
	
	if building_type == "barracks":
		var train_button = Button.new()
		train_button.text = "Train Units"
		train_button.pressed.connect(_on_train_units_pressed)
		actions_container.add_child(train_button)
	elif building_type in ["fishing_hut", "farm", "mine", "lumber_mill"]:
		var collect_button = Button.new()
		collect_button.text = "Collect Resources"
		collect_button.pressed.connect(_on_collect_resources_pressed)
		actions_container.add_child(collect_button)
	
	if building_type != "town_center":  # Can't demolish town center
		var demolish_button = Button.new()
		demolish_button.text = "Demolish"
		demolish_button.modulate = Color(1.0, 0.7, 0.7)  # Light red tint
		demolish_button.pressed.connect(_on_demolish_pressed)
		actions_container.add_child(demolish_button)
	
	# Universal upgrade button (if not max level)
	var upgrade_button = Button.new()
	upgrade_button.text = "Upgrade"
	upgrade_button.modulate = Color(0.7, 1.0, 0.7)  # Light green tint
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	actions_container.add_child(upgrade_button)
	
	return section

func setup_building_details(building: Node2D):
	building_node = building
	building_data = _extract_building_data(building)
	
	_populate_building_info()

func _extract_building_data(building: Node2D) -> Dictionary:
	var data = {}
	
	# Basic info
	data["name"] = building.name
	data["position"] = building.position
	data["owner_player"] = building.get_meta("owner_player", 1)
	data["building_type"] = building.get_meta("building_type", "unknown")
	data["construction_day"] = building.get_meta("construction_day", 0)
	
	# Get texture from sprite child if available
	if building.has_node("Sprite2D"):
		var sprite = building.get_node("Sprite2D")
		if sprite.texture:
			data["texture"] = sprite.texture
			data["texture_path"] = sprite.texture.resource_path
	
	# Get additional game context data
	if building.get_parent() and building.get_parent().get_parent():
		var game_node = building.get_parent().get_parent()
		
		# Get current turn/day information
		if game_node.has_method("get_node"):
			var turn_manager = game_node.get_node("TurnManager")
			if turn_manager and turn_manager.has_method("get_day"):
				data["current_day"] = turn_manager.get_day()
				data["days_built"] = data["current_day"] - data["construction_day"]
		
		# Get tile coordinates
		var tilemap_layer = game_node.get_node("TileMapLayer")
		if tilemap_layer:
			data["tile_coords"] = tilemap_layer.local_to_map(building.position)
	
	return data

func _populate_building_info():
	# The main VBoxContainer should be the second child (first is Panel background)
	var main_vbox = null
	if get_child_count() > 1:
		main_vbox = get_child(1)  # Skip the Panel background
		
	if not main_vbox or not main_vbox is VBoxContainer:
		# Try to find it by class
		for child in get_children():
			if child is VBoxContainer:
				main_vbox = child
				break
		if not main_vbox:
			print("Building Details: Could not find any VBoxContainer")
			return
		
	var scroll_container = main_vbox.get_node_or_null("ScrollContainer")
	if not scroll_container:
		# Try to find ScrollContainer by type
		for child in main_vbox.get_children():
			if child is ScrollContainer:
				scroll_container = child
				break
		if not scroll_container:
			print("Building Details: No ScrollContainer found")
			return
		
	var content_vbox = scroll_container.get_node_or_null("ContentContainer")
	if not content_vbox:
		# Try to find by type
		for child in scroll_container.get_children():
			if child is VBoxContainer:
				content_vbox = child
				break
		if not content_vbox:
			print("Building Details: Could not find content VBoxContainer")
			return
	
	# Find nodes by walking the tree directly
	var building_image = null
	var info_container = null
	var stats_container = null
	
	for section in content_vbox.get_children():
		if not section:
			continue
			
		for child in section.get_children():
			if not child:
				continue
				
			if child.name == "InfoContainer":
				info_container = child
			elif child.name == "StatsContainer":
				stats_container = child
			elif child is CenterContainer:
				for grandchild in child.get_children():
					if grandchild and grandchild.name == "BuildingImage":
						building_image = grandchild
	
	if building_data.has("texture") and building_image:
		building_image.texture = building_data["texture"]
	
	if info_container:
		# Clear existing info
		for info_child in info_container.get_children():
			info_child.queue_free()
		
		# Building identification
		var building_type = building_data.get("building_type", "unknown")
		var display_name = _get_building_display_name(building_type)
		_add_info_row(info_container, "Building Type:", display_name)
		_add_info_row(info_container, "Owner:", "Player " + str(building_data.get("owner_player", 1)))
		
		# Construction information
		var construction_day = building_data.get("construction_day", 0)
		var current_day = building_data.get("current_day", construction_day)
		var days_built = current_day - construction_day
		
		_add_info_row(info_container, "Built on Day:", str(construction_day))
		if days_built >= 0:
			_add_info_row(info_container, "Days Active:", str(days_built))
		
		# Location information
		if building_data.has("tile_coords"):
			var coords = building_data["tile_coords"]
			_add_info_row(info_container, "Coordinates:", "(" + str(coords.x) + ", " + str(coords.y) + ")")
		
		# Building ID (from name) - now uses clean naming like house1, town_center1
		var building_id = building_data.get("name", "Unknown")
		_add_info_row(info_container, "Building ID:", building_id)
	
	# Populate stats section
	if stats_container:
		# Clear existing stats
		for child in stats_container.get_children():
			child.queue_free()
		
		var building_type = building_data.get("building_type", "unknown")
		
		# Health/Durability
		_add_info_row(stats_container, "Health:", "100/100 (Perfect)")
		
		# Production based on building type and age
		var production = _get_building_production()
		if production != "None":
			_add_info_row(stats_container, "Production:", production)
		
		# Maintenance costs
		var maintenance = _get_building_maintenance()
		_add_info_row(stats_container, "Maintenance:", maintenance)
		
		# Population impact
		var population_effect = _get_population_effect(building_type)
		if population_effect != "None":
			_add_info_row(stats_container, "Population:", population_effect)
		
		# Special effects
		var special_effects = _get_special_effects(building_type)
		if special_effects != "None":
			_add_info_row(stats_container, "Special:", special_effects)

func _debug_print_tree(node: Node, indent: int):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	print(indent_str + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_debug_print_tree(child, indent + 1)

func _add_info_row(container: Control, label_text: String, value_text: String):
	var row = HBoxContainer.new()
	container.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)

func _get_building_display_name(building_type: String) -> String:
	match building_type:
		"fishing_hut":
			return "Fishing Hut"
		"house":
			return "House"
		"town_center":
			return "Town Center"
		"barracks":
			return "Barracks"
		"farm":
			return "Farm"
		"mine":
			return "Mine"
		"lumber_mill":
			return "Lumber Mill"
		_:
			return building_type.capitalize().replace("_", " ")

func _get_building_production() -> String:
	var building_type = building_data.get("building_type", "unknown")
	var days_active = building_data.get("days_built", 0)
	
	match building_type:
		"fishing_hut":
			var base_food = 2
			var bonus = max(0, (days_active / 10))  # Bonus every 10 days
			return "+" + str(base_food + bonus) + " Food/turn"
		"house":
			return "+1 Population capacity"
		"town_center":
			return "+1 to all resources/turn"
		"barracks":
			return "Trains military units"
		"farm":
			var base_food = 3
			var bonus = max(0, (days_active / 15))
			return "+" + str(base_food + bonus) + " Food/turn"
		"mine":
			var base_stone = 2
			var bonus = max(0, (days_active / 20))
			return "+" + str(base_stone + bonus) + " Stone/turn"
		"lumber_mill":
			var base_wood = 2
			var bonus = max(0, (days_active / 12))
			return "+" + str(base_wood + bonus) + " Wood/turn"
		_:
			return "None"

func _get_building_maintenance() -> String:
	var building_type = building_data.get("building_type", "unknown")
	match building_type:
		"fishing_hut":
			return "1 Gold/turn"
		"house":
			return "0.5 Gold/turn"
		"town_center":
			return "2 Gold/turn"
		"barracks":
			return "3 Gold/turn"
		"farm":
			return "1.5 Gold/turn"
		"mine":
			return "2 Gold/turn"
		"lumber_mill":
			return "1.5 Gold/turn"
		_:
			return "0 Gold/turn"

func _get_population_effect(building_type: String) -> String:
	match building_type:
		"house":
			return "+4 capacity"
		"town_center":
			return "+2 capacity"
		"barracks":
			return "Houses 5 units"
		_:
			return "None"

func _get_special_effects(building_type: String) -> String:
	match building_type:
		"town_center":
			return "Administrative center, enables other buildings"
		"barracks":
			return "Military training, +10% unit combat effectiveness"
		"fishing_hut":
			return "Must be near water"
		"mine":
			return "Must be near stone deposits"
		"lumber_mill":
			return "Must be near forest"
		_:
			return "None"

func _on_close_pressed():
	close_requested.emit()
	queue_free()

func _on_upgrade_pressed():
	var building_name = building_data.get("name", "Unknown")
	var building_type = building_data.get("building_type", "unknown")
	print("Upgrade building: ", building_name, " (", building_type, ")")
	# TODO: Implement upgrade functionality
	# Could show upgrade options modal or directly upgrade if resources available

func _on_demolish_pressed():
	var building_name = building_data.get("name", "Unknown")
	var coords = building_data.get("tile_coords", Vector2i(0, 0))
	print("Demolish building: ", building_name, " at coordinates (", coords.x, ", ", coords.y, ")")
	# TODO: Implement demolish confirmation dialog and functionality
	# Should return some resources and remove building from game

func _on_train_units_pressed():
	var building_name = building_data.get("name", "Unknown")
	print("Train units at: ", building_name)
	# TODO: Open unit training interface

func _on_collect_resources_pressed():
	var building_name = building_data.get("name", "Unknown")
	var building_type = building_data.get("building_type", "unknown")
	print("Collect resources from: ", building_name, " (", building_type, ")")
	# TODO: Implement manual resource collection with bonus
extends Control

signal close_requested
signal demolish_confirmed(building_data: Dictionary)

var building_node: Node2D
var building_data: Dictionary
var is_dragging: bool = false
var drag_offset: Vector2
var title_label: Label
var connection_lines: Array = []  # Store Line2D nodes for visual connections
var is_showing_connections: bool = false
var camera_controller: Node
var connection_paths: Array = []  # Store path data for redrawing
var demolish_warning_modal: ConfirmationDialog

func _ready():
	print("Building Details Modal: _ready() called")
	_setup_modal()
	print("Building Details Modal: _setup_modal() completed")
	
	# Connect visibility changes to clear lines when hidden
	visibility_changed.connect(_on_visibility_changed)

func _process(_delta):
	# Only check for redraw needs, don't update every frame
	if visible and building_node and is_showing_connections:
		# Check if we need to redraw connections (if lines were lost)
		if connection_lines.size() == 0 and connection_paths.size() > 0:
			_redraw_connections()

func _on_visibility_changed():
	if not visible:
		is_showing_connections = false
		_clear_connection_lines()
	else:
		# If modal becomes visible again and we have a building, redraw connections
		if building_node:
			is_showing_connections = true
			_redraw_connections()

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
	title_label = Label.new()
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
	
	# Building image and capacity section
	var image_capacity_section = _create_image_capacity_section()
	content_container.add_child(image_capacity_section)
	
	# Building info section
	var info_section = _create_info_section()
	content_container.add_child(info_section)
	
	# Building stats section
	var stats_section = _create_stats_section()
	content_container.add_child(stats_section)
	
	# Building connections section
	var connections_section = _create_connections_section()
	content_container.add_child(connections_section)
	
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

func _create_image_capacity_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Building Overview"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	# Horizontal container for image and capacity info
	var main_container = HBoxContainer.new()
	main_container.add_theme_constant_override("separation", 15)
	section.add_child(main_container)
	
	# Left side - Building image (left-aligned)
	var image_container = VBoxContainer.new()
	image_container.custom_minimum_size = Vector2(80, 0)
	main_container.add_child(image_container)
	
	var building_image = TextureRect.new()
	building_image.name = "BuildingImage"  # Explicit name for find_child
	building_image.custom_minimum_size = Vector2(64, 64)
	building_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	building_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Left-align
	image_container.add_child(building_image)
	
	# Right side - Capacity information
	var capacity_container = VBoxContainer.new()
	capacity_container.name = "CapacityContainer"  # For easy access
	capacity_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_container.add_theme_constant_override("separation", 5)
	main_container.add_child(capacity_container)
	
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
	elif building_type in ["fishing_hut", "stoneworker", "lumberjack", "lumber_mill"]:
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

func _create_connections_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Connections"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var connections_container = VBoxContainer.new()
	connections_container.name = "ConnectionsContainer"
	connections_container.add_theme_constant_override("separation", 5)
	section.add_child(connections_container)
	
	return section

func setup_building_details(building: Node2D):
	building_node = building
	building_data = _extract_building_data(building)
	
	# Get camera controller reference for position tracking
	var game_node = building_node.get_parent().get_parent()
	camera_controller = game_node.get_node_or_null("CameraController")
	
	# Connect to camera movement signals if available
	if camera_controller and camera_controller.has_signal("camera_moved"):
		# Disconnect any previous connections first
		if camera_controller.is_connected("camera_moved", _on_camera_moved):
			camera_controller.disconnect("camera_moved", _on_camera_moved)
		camera_controller.connect("camera_moved", _on_camera_moved)
	elif camera_controller and camera_controller.has_signal("position_changed"):
		# Try alternative signal name
		if camera_controller.is_connected("position_changed", _on_camera_moved):
			camera_controller.disconnect("position_changed", _on_camera_moved)
		camera_controller.connect("position_changed", _on_camera_moved)
	
	# Update title with building ID
	var building_id = building_data.get("name", "Unknown")
	title_label.text = "Building Details: " + building_id
	
	# Draw connection lines on the map
	_draw_connection_lines()
	
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
		
		# Get connections to other buildings/objects
		data["connections"] = _find_building_connections(building, game_node)
		
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

func _find_building_connections(building: Node2D, game_node: Node) -> Array:
	var connections = []
	var building_type = building.get_meta("building_type", "unknown")
	
	print("Finding connections for building type: ", building_type)
	
	# Define connection rules for different building types
	var connection_rules = {
		"house": ["town_center", "barracks", "stoneworker"],
		"barracks": ["town_center", "house"],
		"town_center": ["house", "barracks", "fishing_hut", "farmhouse", "stoneworker", "lumber_mill", "lumberjack"],
		"fishing_hut": ["town_center"],
		"farmhouse": ["town_center", "house", "farm"],
		"stoneworker": ["house", "town_center", "mountain"],
		"lumberjack": ["house", "town_center", "tree"],
		"lumber_mill": ["town_center", "tree"]
	}
	
	# Get connection range (max 50 tiles)
	var connection_range_tiles = 50
	
	# Find connected building types for this building
	var allowed_connections = connection_rules.get(building_type, [])
	
	if allowed_connections.is_empty():
		return connections
	
	# Get the tilemap to convert positions to tile coordinates
	var tilemap_layer = game_node.get_node_or_null("TileMapLayer")
	if not tilemap_layer:
		return connections
		
	var building_tile_coords = tilemap_layer.local_to_map(building.position)
	
	# Get buildings from game's player data instead of searching the scene tree
	if game_node.has_method("get_player_buildings"):
		var all_buildings = game_node.get_player_buildings(1)  # Assuming player 1
		print("Checking connections for ", building.name, " at tile ", building_tile_coords, " - found ", all_buildings.size(), " total buildings")
		
		for building_name in all_buildings:
			if building_name == building.name:
				continue  # Skip self
			
			# Find the actual building node by name
			var buildings_layer = building.get_parent()
			if buildings_layer and buildings_layer.has_node(NodePath(building_name)):
				var other_building = buildings_layer.get_node(NodePath(building_name))
				var other_type = other_building.get_meta("building_type", "unknown")
				var other_tile_coords = tilemap_layer.local_to_map(other_building.position)
				
				# Calculate tile distance (Hexagonal distance)
				var tile_distance = _hex_distance(building_tile_coords, other_tile_coords)
				
				if other_type in allowed_connections and tile_distance <= connection_range_tiles:
					connections.append({
						"name": other_building.name,
						"type": other_type,
						"distance": tile_distance,
						"object_type": "building"
					})
					print("Added connection: ", building_name, " (", other_type, ") at ", tile_distance, " tiles away")
	
	# Also search for mountains if they're in allowed connections
	if "mountain" in allowed_connections:
		print("Looking for mountain connections for ", building_type)
		
		# Use the new environment system to get mountains
		if game_node.has_method("get_environment_objects"):
			var mountains = game_node.get_environment_objects("mountains")
			print("Found ", mountains.size(), " mountains in environment system")
			
			for mountain_id in mountains:
				var mountain_data = mountains[mountain_id]
				var mountain_tile_coords = mountain_data["tile_coords"]
				var tile_distance = _hex_distance(building_tile_coords, mountain_tile_coords)
				
				print("Found mountain ", mountain_id, " at distance ", tile_distance)
				if tile_distance <= connection_range_tiles:
					connections.append({
						"name": mountain_id,
						"type": "mountain",
						"distance": tile_distance,
						"object_type": "mountain"
					})
					print("Added mountain connection: ", mountain_id, " at ", tile_distance, " tiles away")
		else:
			print("Environment system not available, falling back to old method")
			# Fallback to old method
			var map_objects_holder = game_node.get_node_or_null("MapObjects")
			if map_objects_holder:
				print("Found MapObjects holder with ", map_objects_holder.get_child_count(), " children")
				for child in map_objects_holder.get_children():
					print("Checking child: ", child.name, " type: ", child.get_class())
					if child.name.begins_with("Mountain") or child.name.begins_with("mountain_"):
						var mountain_tile_coords = tilemap_layer.local_to_map(child.position)
						var tile_distance = _hex_distance(building_tile_coords, mountain_tile_coords)
						
						print("Found mountain ", child.name, " at distance ", tile_distance)
						if tile_distance <= connection_range_tiles:
							connections.append({
								"name": child.name,
								"type": "mountain",
								"distance": tile_distance,
								"object_type": "mountain"
							})
							print("Added mountain connection: ", child.name, " at ", tile_distance, " tiles away")
			else:
				print("MapObjects holder not found!")
	
	# Also search for trees if they're in allowed connections
	if "tree" in allowed_connections:
		print("Looking for tree connections for ", building_type)
		
		# Use the new environment system to get trees
		if game_node.has_method("get_environment_objects"):
			var trees = game_node.get_environment_objects("trees")
			print("Found ", trees.size(), " trees in environment system")
			
			for tree_id in trees:
				var tree_data = trees[tree_id]
				var tree_tile_coords = tree_data["tile_coords"]
				var tile_distance = abs(building_tile_coords.x - tree_tile_coords.x) + abs(building_tile_coords.y - tree_tile_coords.y)
				
				print("Found tree ", tree_id, " at distance ", tile_distance)
				if tile_distance <= connection_range_tiles:
					connections.append({
						"name": tree_id,
						"type": "tree",
						"distance": tile_distance,
						"object_type": "tree"
					})
					print("Added tree connection: ", tree_id, " at ", tile_distance, " tiles away")
		else:
			print("Environment system not available, falling back to old method")
			# Fallback to old method
			var map_objects_holder = game_node.get_node_or_null("MapObjects")
			if map_objects_holder:
				print("Found MapObjects holder with ", map_objects_holder.get_child_count(), " children")
				for child in map_objects_holder.get_children():
					print("Checking child: ", child.name, " type: ", child.get_class())
					if child.name.begins_with("Tree") or child.name.begins_with("tree_"):
						var tree_tile_coords = tilemap_layer.local_to_map(child.position)
						var tile_distance = abs(building_tile_coords.x - tree_tile_coords.x) + abs(building_tile_coords.y - tree_tile_coords.y)
						
						print("Found tree ", child.name, " at distance ", tile_distance)
						if tile_distance <= connection_range_tiles:
							connections.append({
								"name": child.name,
								"type": "tree",
								"distance": tile_distance,
								"object_type": "tree"
							})
							print("Added tree connection: ", child.name, " at ", tile_distance, " tiles away")
			else:
				print("MapObjects holder not found!")
	
	# Sort connections by distance
	connections.sort_custom(func(a, b): return a.distance < b.distance)
	
	# For stoneworkers, limit mountain connections to 3 nearest
	# For lumberjacks, limit tree connections to 3 nearest
	if building_type == "stoneworker":
		var mountain_connections = []
		var other_connections = []
		
		for connection in connections:
			if connection.type == "mountain":
				mountain_connections.append(connection)
			else:
				other_connections.append(connection)
		
		# Keep only the 3 nearest mountains
		if mountain_connections.size() > 3:
			mountain_connections = mountain_connections.slice(0, 3)
		
		# Combine back together
		connections = other_connections + mountain_connections
		connections.sort_custom(func(a, b): return a.distance < b.distance)
	
	elif building_type == "lumberjack":
		var tree_connections = []
		var other_connections = []
		
		for connection in connections:
			if connection.type == "tree":
				tree_connections.append(connection)
			else:
				other_connections.append(connection)
		
		# Keep only the 3 nearest trees
		if tree_connections.size() > 3:
			tree_connections = tree_connections.slice(0, 3)
		
		# Combine back together
		connections = other_connections + tree_connections
		connections.sort_custom(func(a, b): return a.distance < b.distance)
	
	return connections

func _astar_pathfind(start_tile: Vector2i, end_tile: Vector2i, _tilemap: TileMapLayer) -> Array:
	# Simple A* implementation for tile-based pathfinding
	var open_set = []
	var closed_set = {}
	var came_from = {}
	var g_score = {}
	var f_score = {}
	
	# Initialize starting tile
	open_set.append(start_tile)
	g_score[start_tile] = 0
	f_score[start_tile] = _heuristic(start_tile, end_tile)
	
	while open_set.size() > 0:
		# Find tile with lowest f_score
		var current = open_set[0]
		var current_index = 0
		for i in range(open_set.size()):
			if f_score.get(open_set[i], INF) < f_score.get(current, INF):
				current = open_set[i]
				current_index = i
		
		# Remove current from open set
		open_set.remove_at(current_index)
		closed_set[current] = true
		
		# Check if we reached the goal
		if current == end_tile:
			return _reconstruct_path(came_from, current)
		
		# Check all neighbors (6-directional for hex grid)
		var neighbors = _get_hex_neighbors(current)
		
		for neighbor in neighbors:
			if closed_set.has(neighbor):
				continue
			
			# Simple walkability check - assume empty tiles are walkable
			var tentative_g_score = g_score.get(current, INF) + 1
			
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			elif tentative_g_score >= g_score.get(neighbor, INF):
				continue
			
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g_score
			f_score[neighbor] = g_score[neighbor] + _heuristic(neighbor, end_tile)
	
	return []  # No path found

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	# Hexagonal distance heuristic
	return _hex_distance(a, b)

func _get_hex_neighbors(tile: Vector2i) -> Array:
	# Get 6 neighbors for hexagonal grid
	# Godot uses offset coordinates for hex tiles
	var neighbors = []
	
	# For odd-row offset (pointy-top hexagons)
	if tile.y % 2 == 0:  # Even row
		neighbors = [
			Vector2i(tile.x - 1, tile.y - 1),  # NW
			Vector2i(tile.x, tile.y - 1),      # NE  
			Vector2i(tile.x + 1, tile.y),      # E
			Vector2i(tile.x, tile.y + 1),      # SE
			Vector2i(tile.x - 1, tile.y + 1),  # SW
			Vector2i(tile.x - 1, tile.y)       # W
		]
	else:  # Odd row
		neighbors = [
			Vector2i(tile.x, tile.y - 1),      # NW
			Vector2i(tile.x + 1, tile.y - 1),  # NE
			Vector2i(tile.x + 1, tile.y),      # E
			Vector2i(tile.x + 1, tile.y + 1),  # SE
			Vector2i(tile.x, tile.y + 1),      # SW
			Vector2i(tile.x - 1, tile.y)       # W
		]
	
	return neighbors

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	# Convert offset coordinates to axial coordinates for distance calculation
	var ax = a.x - (a.y - (a.y & 1)) / 2
	var ay = a.y
	var az = -ax - ay
	
	var bx = b.x - (b.y - (b.y & 1)) / 2  
	var by = b.y
	var bz = -bx - by
	
	# Hexagonal distance in axial coordinates
	return (abs(ax - bx) + abs(ay - by) + abs(az - bz)) / 2

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func _on_camera_moved():
	# Redraw connection lines when camera moves
	if is_showing_connections and building_node:
		_update_line_positions()

func _update_line_positions():
	# Update all connection lines based on current camera position and zoom
	if not camera_controller or not building_node:
		return
		
	var game_node = building_node.get_parent().get_parent()
	var tilemap = game_node.get_node_or_null("TileMapLayer")
	if not tilemap:
		return
	
	# Update each line with current camera transform
	for i in range(connection_lines.size()):
		if i < connection_paths.size() and is_instance_valid(connection_lines[i]):
			var line = connection_lines[i]
			var path_data = connection_paths[i]
			
			# Clear existing points
			line.clear_points()
			
			# Recalculate world positions based on current camera
			for tile_coord in path_data.path:
				var world_pos = tilemap.map_to_local(tile_coord)
				line.add_point(world_pos)

func _draw_connection_lines():
	# Clear existing connection lines first
	_clear_connection_lines()
	
	if not building_node:
		return
		
	is_showing_connections = true
	_redraw_connections()

func _redraw_connections():
	if not building_node or not is_showing_connections:
		return
		
	var game_node = building_node.get_parent().get_parent()
	var tilemap = game_node.get_node_or_null("TileMapLayer")
	if not tilemap:
		return
		
	var connections = building_data.get("connections", [])
	var building_tile_coords = tilemap.local_to_map(building_node.position)
	
	# Colors for different connection types (more visible colors)
	var connection_colors = {
		"house": Color.DEEP_SKY_BLUE,
		"town_center": Color.ORANGE,
		"barracks": Color.CRIMSON,
		"fishing_hut": Color.AQUA,
		"farm": Color.LIME_GREEN,
		"farmhouse": Color.YELLOW_GREEN,
		"stoneworker": Color.SILVER,
		"lumberjack": Color.DARK_GREEN,
		"lumber_mill": Color.SADDLE_BROWN,
		"mountain": Color.GRAY,
		"tree": Color.GREEN
	}
	
	for connection in connections:
		var target_node = null
		
		# Find the target object (building, mountain, or tree)
		if connection.object_type == "building":
			var buildings_layer = building_node.get_parent()
			if buildings_layer and buildings_layer.has_node(NodePath(connection.name)):
				target_node = buildings_layer.get_node(NodePath(connection.name))
		elif connection.object_type == "mountain":
			# For environment objects, try to find by position since names might not match exactly
			if game_node.has_method("get_environment_objects"):
				var mountains = game_node.get_environment_objects("mountains")
				if mountains.has(connection.name):
					var mountain_data = mountains[connection.name]
					var mountain_pos = tilemap.map_to_local(mountain_data["tile_coords"])
					# Find the actual node by position
					var map_objects_holder = game_node.get_node_or_null("MapObjects")
					if map_objects_holder:
						for child in map_objects_holder.get_children():
							if child.position.distance_to(mountain_pos) < 32:  # Within one tile
								target_node = child
								break
		elif connection.object_type == "tree":
			# For environment objects, try to find by position since names might not match exactly
			if game_node.has_method("get_environment_objects"):
				var trees = game_node.get_environment_objects("trees")
				if trees.has(connection.name):
					var tree_data = trees[connection.name]
					var tree_pos = tilemap.map_to_local(tree_data["tile_coords"])
					# Find the actual node by position
					var map_objects_holder = game_node.get_node_or_null("MapObjects")
					if map_objects_holder:
						for child in map_objects_holder.get_children():
							if child.position.distance_to(tree_pos) < 32:  # Within one tile
								target_node = child
								break
		
		if target_node:
			var target_tile_coords = tilemap.local_to_map(target_node.position)
			
			# Find path using A*
			var path = _astar_pathfind(building_tile_coords, target_tile_coords, tilemap)
			
			if path.size() > 1:  # Only draw if path exists and has multiple points
				var color = connection_colors.get(connection.type, Color.WHITE)
				_draw_path_on_tilemap(path, color, tilemap)

func _draw_path_on_tilemap(path: Array, color: Color, tilemap: TileMapLayer):
	# Create a Line2D node to draw the connection path
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.z_index = 100  # Draw above everything else
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Convert tile coordinates to world positions (tile centers)
	for tile_coord in path:
		# Calculate world position of tile center
		var world_pos = tilemap.map_to_local(tile_coord)
		line.add_point(world_pos)
	
	# Add line to the tilemap layer so it moves with the world
	tilemap.add_child(line)
	
	# Store both the line reference and the path data for updates
	connection_lines.append(line)
	connection_paths.append({
		"path": path,
		"color": color,
		"line": line
	})
	
	print("Drew connection line with ", path.size(), " points in ", color)

func _clear_connection_lines():
	# Remove all Line2D nodes from the scene
	for line in connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	
	connection_lines.clear()
	connection_paths.clear()
	is_showing_connections = false
	print("Cleared connection lines")

func clear_all_connections():
	# Public function to clear connections from outside
	is_showing_connections = false
	_clear_connection_lines()

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
	var connections_container = null
	var capacity_container = null
	
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
			elif child.name == "ConnectionsContainer":
				connections_container = child
			elif child.name == "CapacityContainer":
				capacity_container = child
			elif child is HBoxContainer:
				# Look for image and capacity container in the new layout
				for hbox_child in child.get_children():
					if hbox_child is VBoxContainer:
						# Check if this VBox contains the image
						for vbox_child in hbox_child.get_children():
							if vbox_child and vbox_child.name == "BuildingImage":
								building_image = vbox_child
								break
					elif hbox_child is VBoxContainer and hbox_child.name == "CapacityContainer":
						capacity_container = hbox_child
			elif child is CenterContainer:
				for grandchild in child.get_children():
					if grandchild and grandchild.name == "BuildingImage":
						building_image = grandchild
	
	# Backup search for CapacityContainer
	if not capacity_container:
		capacity_container = find_child("CapacityContainer", true, false)
	
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
		
		# Population impact (skip for town center)
		if building_type != "town_center":
			var population_effect = _get_population_effect(building_type)
			if population_effect != "None":
				_add_info_row(stats_container, "Population:", population_effect)
		
		# Show player population stats
		var game_node = _get_game_node()
		if game_node:
			var owner_player = building_data.get("owner_player", 1)
			var pop_data = game_node.get_player_population_data(owner_player)
			if not pop_data.is_empty():
				var total_pop = str(pop_data.get("total", 30))
				var unhoused_pop = str(pop_data.get("unhoused", 30))
				var unemployed_pop = str(pop_data.get("unemployed", 30))
				_add_info_row(stats_container, "Total Population:", total_pop)
				_add_info_row(stats_container, "Unhoused:", unhoused_pop)
				_add_info_row(stats_container, "Unemployed:", unemployed_pop)
		
		# Special effects
		var special_effects = _get_special_effects(building_type)
		if special_effects != "None":
			_add_info_row(stats_container, "Special:", special_effects)
	
	# Populate capacity section (next to image)
	if capacity_container:
		# Clear existing capacity info
		for child in capacity_container.get_children():
			child.queue_free()
		
		var building_type = building_data.get("building_type", "unknown")
		
		# Living capacity controls
		var living_capacity = _get_living_capacity(building_type)
		if living_capacity > 0:
			_create_capacity_control(capacity_container, "Living Capacity:", living_capacity, "living")
		
		# Worker capacity controls
		var worker_capacity = _get_worker_capacity(building_type)
		if worker_capacity > 0:
			_create_capacity_control(capacity_container, "Worker Capacity:", worker_capacity, "worker")
	
	# Populate connections section
	if connections_container:
		# Clear existing connections
		for child in connections_container.get_children():
			child.queue_free()
		
		var connections = building_data.get("connections", [])
		if connections.is_empty():
			var no_connections_label = Label.new()
			no_connections_label.text = "No connections in range"
			no_connections_label.add_theme_color_override("font_color", Color.GRAY)
			connections_container.add_child(no_connections_label)
		else:
			for connection in connections:
				var connection_row = HBoxContainer.new()
				connections_container.add_child(connection_row)
				
				# Connection type icon/indicator
				var type_label = Label.new()
				var type_text = connection.type.capitalize()
				if connection.object_type == "building":
					type_text = "🏠 " + type_text
				elif connection.object_type == "map_object":
					type_text = "🌳 " + type_text
				type_label.text = type_text
				type_label.custom_minimum_size.x = 100
				connection_row.add_child(type_label)
				
				# Connection name and distance
				var details_label = Label.new()
				details_label.text = connection.name + " (" + str(connection.distance) + " tiles)"
				details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				connection_row.add_child(details_label)

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
	label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", Color.WHITE)
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
		"farmhouse":
			return "Farmhouse"
		"stoneworker":
			return "Stoneworker"
		"lumberjack":
			return "Lumberjack"
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
		"farmhouse":
			return "Manages farm operations (+6 worker capacity)"
		"stoneworker":
			var base_stone = 2
			var bonus = max(0, (days_active / 20))
			return "+" + str(base_stone + bonus) + " Stone/turn"
		"lumberjack":
			var base_wood = 2
			var bonus = max(0, (days_active / 15))
			return "+" + str(base_wood + bonus) + " Wood/turn"
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
		"farmhouse":
			return "0.8 Gold/turn"
		"stoneworker":
			return "2 Gold/turn"
		"lumberjack":
			return "1.5 Gold/turn"
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

func _get_living_capacity(building_type: String) -> int:
	match building_type:
		"house":
			return 7  # Family of up to 7
		"town_center":
			return 20  # 20 people living
		"barracks":
			return 5  # 5 soldiers per barracks
		_:
			return 0

func _get_worker_capacity(building_type: String) -> int:
	match building_type:
		"town_center":
			return 10  # 10 people working
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

func _get_special_effects(building_type: String) -> String:
	match building_type:
		"town_center":
			return "Administrative center, enables other buildings"
		"barracks":
			return "Military training, +10% unit combat effectiveness"
		"fishing_hut":
			return "Must be near water"
		"farmhouse":
			return "Agricultural center, manages nearby farms"
		"stoneworker":
			return "Must be near stone deposits"
		"lumberjack":
			return "Must be near forests"
		"lumber_mill":
			return "Must be near forest"
		_:
			return "None"

func _on_close_pressed():
	_clear_connection_lines()
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
	_show_demolish_warning(building_name)

func _show_demolish_warning(building_name: String):
	# Create warning modal
	demolish_warning_modal = ConfirmationDialog.new()
	demolish_warning_modal.title = "Confirm Demolish"
	demolish_warning_modal.dialog_text = "Delete " + building_name + "?"
	
	# Connect signals
	demolish_warning_modal.confirmed.connect(_on_demolish_confirmed)
	demolish_warning_modal.canceled.connect(_on_demolish_cancelled)
	
	# Add to scene and show
	get_tree().current_scene.add_child(demolish_warning_modal)
	demolish_warning_modal.popup_centered()

func _on_demolish_confirmed():
	# Clean up warning modal
	if demolish_warning_modal:
		demolish_warning_modal.queue_free()
		demolish_warning_modal = null
	
	# Emit signal to game to handle building deletion
	demolish_confirmed.emit(building_data)
	
	# Close the details modal
	_on_close_pressed()

func _on_demolish_cancelled():
	# Just clean up warning modal and return to details
	if demolish_warning_modal:
		demolish_warning_modal.queue_free()
		demolish_warning_modal = null

func _on_train_units_pressed():
	var building_name = building_data.get("name", "Unknown")
	print("Train units at: ", building_name)
	# TODO: Open unit training interface

func _on_collect_resources_pressed():
	var building_name = building_data.get("name", "Unknown")
	var building_type = building_data.get("building_type", "unknown")
	print("Collect resources from: ", building_name, " (", building_type, ")")
	# TODO: Implement manual resource collection with bonus

func _find_node_recursive(node: Node, target_name: String) -> Node:
	# Recursive helper to find a node by name
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null

func _create_capacity_control(parent: Container, label_text: String, max_capacity: int, capacity_type: String):
	# Create horizontal container for the capacity control
	var control_row = HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 10)
	parent.add_child(control_row)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	control_row.add_child(label)
	
	# Minus button
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(30, 30)
	control_row.add_child(minus_btn)
	
	# Current/Max display - get actual occupancy from building node
	var capacity_label = Label.new()
	var current_occupancy = 0
	if building_node:
		current_occupancy = building_node.get_meta(capacity_type + "_occupancy", 0)
	else:
		# Fallback to building_data if building_node not available
		current_occupancy = building_data.get(capacity_type + "_occupancy", 0)
	capacity_label.text = str(current_occupancy) + "/" + str(max_capacity)
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacity_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control_row.add_child(capacity_label)
	
	# Plus button
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 30)
	control_row.add_child(plus_btn)
	
	# Store current value in the label's metadata
	capacity_label.set_meta("current_value", current_occupancy)
	capacity_label.set_meta("max_value", max_capacity)
	capacity_label.set_meta("capacity_type", capacity_type)
	
	# Connect button signals
	plus_btn.pressed.connect(_on_capacity_plus_pressed.bind(capacity_label))
	minus_btn.pressed.connect(_on_capacity_minus_pressed.bind(capacity_label))

func _on_capacity_plus_pressed(capacity_label: Label):
	var current_value = capacity_label.get_meta("current_value", 0)
	var max_value = capacity_label.get_meta("max_value", 0)
	var capacity_type = capacity_label.get_meta("capacity_type", "")
	
	if current_value < max_value:
		# Try to update building occupancy through game validation
		var game_node = _get_game_node()
		if game_node and game_node.has_method("update_building_occupancy"):
			if game_node.update_building_occupancy(building_node, capacity_type, current_value + 1):
				# Success - update UI
				current_value += 1
				capacity_label.set_meta("current_value", current_value)
				capacity_label.text = str(current_value) + "/" + str(max_value)
				
				# Update building data
				building_data[capacity_type + "_occupancy"] = current_value
				
				# Refresh population modal if it's open
				_refresh_population_modal()
				
				print("Increased ", capacity_type, " occupancy to ", current_value, "/", max_value)
			else:
				print("Cannot increase capacity - not enough available population")


func _on_capacity_minus_pressed(capacity_label: Label):
	var current_value = capacity_label.get_meta("current_value", 0)
	var max_value = capacity_label.get_meta("max_value", 0)
	var capacity_type = capacity_label.get_meta("capacity_type", "")
	
	if current_value > 0:
		# Update building occupancy through game validation
		var game_node = _get_game_node()
		if game_node and game_node.has_method("update_building_occupancy"):
			if game_node.update_building_occupancy(building_node, capacity_type, current_value - 1):
				# Success - update UI
				current_value -= 1
				capacity_label.set_meta("current_value", current_value)
				capacity_label.text = str(current_value) + "/" + str(max_value)
				
				# Update building data
				building_data[capacity_type + "_occupancy"] = current_value
				
				# Refresh population modal if it's open
				_refresh_population_modal()
				
				print("Decreased ", capacity_type, " occupancy to ", current_value, "/", max_value)

func _get_game_node() -> Node:
	# Get reference to the main game node
	if building_node:
		return building_node.get_parent().get_parent()
	return null

func _refresh_population_modal():
	# Refresh the population modal if it's currently open
	var game_node = _get_game_node()
	if game_node and game_node.has_method("get") and game_node.population_modal:
		if is_instance_valid(game_node.population_modal) and game_node.population_modal.visible:
			if game_node.population_modal.has_method("refresh_content"):
				game_node.population_modal.refresh_content()
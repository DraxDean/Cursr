extends Control

signal close_requested
signal demolish_confirmed(building_data: Dictionary)

var modal_type: String = "building_details"
var building_node: Node2D
var building_data: Dictionary
var game_node: Node  # Reference to the game node
var is_dragging: bool = false
var drag_offset: Vector2
var title_label: Label
var _registered_with_ui_manager: bool = false  # Track registration state
var connection_lines: Array = []  # Store Line2D nodes for visual connections
var is_showing_connections: bool = false
var camera_controller: Node
var connection_paths: Array = []  # Store path data for redrawing
var demolish_warning_modal: ConfirmationDialog
var connection_lines_container: Node2D  # Dedicated container for connection line nodes
var selected_job_path_line: Line2D = null  # Currently selected job's path visualization (white)
var selected_job_index: int = -1  # Currently selected job index
var selected_building_path_line: Line2D = null  # Currently selected building path visualization (white)
var selected_building_path_index: int = -1  # Currently selected building connection path index
var paths_toggle_checkbox: CheckBox = null  # Show/hide all paths checkbox
var building_paths_visibility: Dictionary = {}  # Track whether paths shown per building (key: building_node.name)
var all_job_path_lines: Array = []  # All drawn job path lines (for show/hide)
var building_connections_data: Array = []  # Store building connections with indices for selection

func _ready():
	DebugConfig.dprint("buildings", ["Building Details Modal: _ready() called"])
	_setup_modal()
	DebugConfig.dprint("buildings", ["Building Details Modal: _setup_modal() completed"])
	
	# Connect visibility changes to clear lines when hidden
	# This will also trigger the parent's _on_modal_visibility_changed
	visibility_changed.connect(_on_visibility_changed)
	
	# Manually register since visibility = true during _ready() may not trigger the signal
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Manually registering in _ready()"])
	_register_with_ui_manager()

func _ensure_connection_lines_container():
	# First ensure game_node is set
	if not game_node and building_node:
		game_node = building_node.get_parent().get_parent()
	
	# Check if container exists and is valid
	if connection_lines_container and is_instance_valid(connection_lines_container):
		# Verify it's still in the scene tree
		if connection_lines_container.get_parent() != null:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Connection lines container already exists and is attached"])
			connection_lines_container.show()  # Ensure it's visible
			return
		else:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Container exists but is orphaned, will recreate"])
			connection_lines_container = null
	
	# Create new container - add to tilemap layer, not game node
	if game_node:
		var tilemap = game_node.get_node_or_null("TileMapLayer")
		if tilemap:
			connection_lines_container = Node2D.new()
			connection_lines_container.name = "ConnectionLinesContainer"
			connection_lines_container.z_index = 1000  # Render above everything in the game world
			tilemap.add_child(connection_lines_container)
			connection_lines_container.show()
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Created new connection lines container as child of TileMapLayer"])
		else:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: ERROR - TileMapLayer not found, cannot create container"])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: ERROR - Cannot create connection lines container, game_node is null"])

func _process(_delta):
	# Only check for redraw needs, don't update every frame
	if visible and building_node and is_showing_connections:
		# Check if we need to redraw connections (if lines were lost)
		if connection_lines.size() == 0 and connection_paths.size() > 0:
			_redraw_connections()

func _on_visibility_changed():
	# Handle modal stack registration/unregistration
	if visible:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Visibility changed to true, registering with UI manager"])
		_register_with_ui_manager()
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Visibility changed to false, unregistering from UI manager"])
		_unregister_from_ui_manager()
	
	# Handle connection lines visibility
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
	
	# Jobs section
	var jobs_section = _create_jobs_section()
	content_container.add_child(jobs_section)
	
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
	
	# Add toggle checkbox for showing/hiding all paths at the top
	var paths_toggle_hbox = HBoxContainer.new()
	paths_toggle_hbox.add_theme_constant_override("separation", 10)
	
	paths_toggle_checkbox = CheckBox.new()
	paths_toggle_checkbox.text = "Show Paths"
	paths_toggle_checkbox.toggled.connect(_on_paths_toggle_toggled)
	paths_toggle_hbox.add_child(paths_toggle_checkbox)
	
	capacity_container.add_child(paths_toggle_hbox)
	
	main_container.add_child(capacity_container)
	
	return section

func _create_info_section() -> Control:
	var section = VBoxContainer.new()
	
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
	elif building_type in ["research", "fishing_hut", "stoneworker", "lumberjack", "lumber_mill"]:
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

func _create_jobs_section() -> Control:
	var section = VBoxContainer.new()
	
	var section_title = Label.new()
	section_title.text = "Jobs"
	section_title.add_theme_font_size_override("font_size", 16)
	section.add_child(section_title)
	
	var jobs_container = VBoxContainer.new()
	jobs_container.name = "JobsContainer"
	jobs_container.add_theme_constant_override("separation", 5)
	section.add_child(jobs_container)
	
	return section

func setup_building_details(building: Node2D):
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: setup_building_details() called for building: %s" % building.name])
	building_node = building
	building_data = _extract_building_data(building)
	
	# Debug: Check if building has jobs
	var jobs_on_building = building_node.get_meta("resource_jobs", [])
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: DEBUG - Building %s has %d jobs in metadata" % [building.name, jobs_on_building.size()]])
	
	# Get game reference and ensure resource rates are calculated
	game_node = building_node.get_parent().get_parent()
	if game_node and game_node.has_method("calculate_resource_rates"):
		var owner_player = building_data.get("owner_player", 1)
		game_node.calculate_resource_rates(owner_player)
	
	# Get camera controller reference for position tracking
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
	
	# Connect to game's building_jobs_updated signal for real-time job updates
	if game_node and game_node.is_connected("building_jobs_updated", Callable(self, "_on_building_jobs_updated")):
		game_node.disconnect("building_jobs_updated", Callable(self, "_on_building_jobs_updated"))
	if game_node and game_node.has_signal("building_jobs_updated"):
		game_node.connect("building_jobs_updated", Callable(self, "_on_building_jobs_updated"))
	
	# Update title with building ID and coordinates
	var building_id = building_data.get("name", "Unknown")
	var coords = building_data.get("tile_coords", Vector2i(0, 0))
	title_label.text = building_id + " (" + str(coords.x) + ", " + str(coords.y) + ")"
	
	# Clear previous paths and connections
	_clear_all_job_path_lines()
	_clear_connection_lines()
	
	# Restore paths toggle state for this building
	var should_show_paths = building_paths_visibility.get(building_node.name, false)
	if paths_toggle_checkbox:
		paths_toggle_checkbox.set_pressed_no_signal(should_show_paths)
	
	_populate_building_info()
	# Always populate jobs on open so existing assignments are visible immediately
	_populate_jobs_from_building()
	
	# If paths should be shown, draw both job paths and building connections
	if should_show_paths:
		_draw_all_job_paths()
		_draw_connection_lines()
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: setup_building_details() completed"])

func _extract_building_data(building: Node2D) -> Dictionary:
	var data = {}
	
	# Basic info - use display_name if set, otherwise use node name (building ID)
	data["name"] = building.get_meta("display_name", building.name)
	data["position"] = building.position
	data["owner_player"] = building.get_meta("owner_player", 1)
	data["building_type"] = building.get_meta("building_type", "unknown")
	data["construction_day"] = building.get_meta("construction_day", 0)
	
	# Get occupancy data based on building type
	if data["building_type"] == "barracks":
		data["station_occupancy"] = building.get_meta("station_occupancy", 0)
	else:
		data["living_occupancy"] = building.get_meta("living_occupancy", 0)
		data["worker_occupancy"] = building.get_meta("worker_occupancy", 0)
	
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
	"""Find building-to-building connections only (resource connections now handled via job paths)"""
	var connections = []
	var building_type = building.get_meta("building_type", "unknown")
	
	DebugConfig.dprint("buildings", ["Finding connections for building type: ", building_type])
	
	# Define building-to-building connection rules only
	var connection_rules = {
		"house": ["town_center", "barracks", "stoneworker"],
		"barracks": ["town_center", "house"],
		"town_center": ["house", "barracks", "fishing_hut", "farmhouse", "stoneworker", "lumber_mill", "lumberjack", "research"],
		"research": ["town_center"],
		"fishing_hut": ["town_center"],
		"farmhouse": ["town_center", "house"],
		"stoneworker": ["house", "town_center"],
		"lumberjack": ["house", "town_center"],
		"lumber_mill": ["town_center"],
		"farm": ["farmhouse"]
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
	
	# Get buildings from game's player data
	if game_node.has_method("get_player_buildings"):
		var all_buildings = game_node.get_player_buildings(1)  # Assuming player 1
		DebugConfig.dprint("buildings", ["Checking connections for ", building.name, " - found ", all_buildings.size(), " total buildings"])
		
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
					# Get display name if it exists
					var display_name = other_building.get_meta("display_name", other_building.name)
					connections.append({
						"name": other_building.name,
						"display_name": display_name,
						"type": other_type,
						"distance": tile_distance,
						"object_type": "building",
						"tile_coords": other_tile_coords
					})
					DebugConfig.dprint("buildings", ["Added connection: ", other_building.name, " -> ", display_name, " (", other_type, ")"])
	# Sort connections by distance
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

func _on_building_jobs_updated(building_name: String):
	"""Handle real-time job updates when jobs are assigned/changed"""
	# Only update if this is the building currently shown in the modal
	if building_node and building_node.name == building_name:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Jobs updated for building %s, refreshing display" % building_name])
		# Re-extract building data to pick up any name changes
		building_data = _extract_building_data(building_node)
		# Update title to show new name if it was renamed
		var building_id = building_data.get("name", "Unknown")
		var coords = building_data.get("tile_coords", Vector2i(0, 0))
		title_label.text = building_id + " (" + str(coords.x) + ", " + str(coords.y) + ")"
		# Re-populate the jobs section dynamically
		_populate_jobs_from_building()

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
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: _draw_connection_lines() called. Clearing %d existing lines" % connection_lines.size()])
	_clear_connection_lines()
	
	if not building_node:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: No building_node, skipping connection lines"])
		return
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Setting is_showing_connections = true and calling _redraw_connections()"])
	is_showing_connections = true
	_redraw_connections()

func _redraw_connections():
	if not building_node or not is_showing_connections:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: _redraw_connections() skipped - building_node exists: %s, is_showing_connections: %s" % [building_node != null, is_showing_connections]])
		return
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: _redraw_connections() called. Current lines on screen: %d" % connection_lines.size()])
	
	if not game_node:
		game_node = building_node.get_parent().get_parent()
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Set game_node in _redraw_connections()"])
	
	var tilemap = game_node.get_node_or_null("TileMapLayer")
	if not tilemap:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: TileMapLayer not found!"])
		return
	
	# Ensure connection lines container exists
	_ensure_connection_lines_container()
	
	# Verify container was created successfully
	if not connection_lines_container or not is_instance_valid(connection_lines_container):
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: ERROR - Failed to create or validate connection lines container"])
		return
	
	var connections = building_data.get("connections", [])
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Redrawing %d connections" % connections.size()])
	var building_tile_coords = tilemap.local_to_map(building_node.position)
	
	# Colors for different connection types (more visible colors)
	var connection_colors = {
		"house": Color.DEEP_SKY_BLUE,
		"town_center": Color.ORANGE,
		"barracks": Color.CRIMSON,
		"research": Color.MAGENTA,
		"fishing_hut": Color.AQUA,
		"farm": Color.LIME_GREEN,
		"farmhouse": Color.YELLOW_GREEN,
		"stoneworker": Color.SILVER,
		"lumberjack": Color.DARK_GREEN,
		"lumber_mill": Color.SADDLE_BROWN,
		"mountain": Color.GRAY,
		"tree": Color.GREEN,
		"fish": Color.DEEP_SKY_BLUE
	}
	
	for connection in connections:
		# Skip resource connections (mountains, trees, fish) - we now use job paths for those
		if connection.object_type in ["mountain", "tree", "fish"]:
			continue
		
		# Re-validate container at start of each iteration
		if not connection_lines_container or not is_instance_valid(connection_lines_container):
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Container became invalid mid-loop! Re-ensuring..."])
			_ensure_connection_lines_container()
			if not connection_lines_container or not is_instance_valid(connection_lines_container):
				DebugConfig.dprint("buildings", ["BuildingDetailsModal: CRITICAL - Could not restore container, aborting redraw"])
				return
		
		var target_node = null
		var path = []
		var path_is_world_coords = false  # Track if path is already in world coordinates
		
		# First, try to use pre-calculated path if available
		if connection.has("path") and not connection["path"].is_empty():
			path = connection["path"]
			path_is_world_coords = true  # Pre-calculated paths are stored as world coordinates
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Using pre-calculated path for ", connection.name, " (", connection.type, ")"])
		else:
			# Otherwise, find the target object and recalculate path
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
			elif connection.object_type == "fish":
				# For fish objects, try to find by position
				if game_node.has_method("get_environment_objects"):
					var fish = game_node.get_environment_objects("fish")
					if fish.has(connection.name):
						var fish_data = fish[connection.name]
						var fish_pos = tilemap.map_to_local(fish_data["tile_coords"])
						# Find the actual node by position
						var map_objects_holder = game_node.get_node_or_null("MapObjects")
						if map_objects_holder:
							for child in map_objects_holder.get_children():
								if child.position.distance_to(fish_pos) < 32:  # Within one tile
									target_node = child
									break
			
			if target_node:
				var target_tile_coords = tilemap.local_to_map(target_node.position)
				
				# Find path using A*
				path = _astar_pathfind(building_tile_coords, target_tile_coords, tilemap)
				path_is_world_coords = false  # Calculated paths are in tile coordinates
				DebugConfig.dprint("buildings", ["BuildingDetailsModal: Calculated path for ", connection.name, " (", connection.type, ") - ", path.size(), " tiles"])
		
		# Draw the path if we have one
		if path.size() > 1:  # Only draw if path exists and has multiple points
			var color = connection_colors.get(connection.type, Color.WHITE)
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drawing path for %s | Container valid: %s | Parent: %s" % [connection.name, is_instance_valid(connection_lines_container), connection_lines_container.get_parent() if is_instance_valid(connection_lines_container) else "N/A"]])
			_draw_path_on_tilemap(path, color, tilemap, path_is_world_coords)
		else:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: No path available for ", connection.name, " (", connection.type, ")"])

func _draw_path_on_tilemap(path: Array, color: Color, tilemap: TileMapLayer, path_is_world_coords: bool = false):
	# Create a Line2D node to draw the connection path
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Convert path points to world positions
	var first_point = Vector2.ZERO
	var last_point = Vector2.ZERO
	for point in path:
		var world_pos: Vector2
		if path_is_world_coords:
			# Path is already in world coordinates (from pre-calculated connections)
			world_pos = point
		else:
			# Path is in tile coordinates, convert to world positions
			world_pos = tilemap.map_to_local(point)
		
		line.add_point(world_pos)
		if line.get_point_count() == 1:
			first_point = world_pos
		last_point = world_pos
	
	# Add line to the connection lines container (renders above game world)
	if connection_lines_container and is_instance_valid(connection_lines_container):
		connection_lines_container.add_child(line)
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Added line to container. Container now has %d children. Parent: %s" % [connection_lines_container.get_child_count(), connection_lines_container.get_parent()]])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: ERROR - connection_lines_container is invalid at draw time!"])
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Container check: exists=%s | valid=%s | parent=%s" % [connection_lines_container != null, connection_lines_container != null and is_instance_valid(connection_lines_container), connection_lines_container.get_parent() if connection_lines_container != null else "N/A"]])
		return  # Don't add line if container is invalid
	
	# Store both the line reference and the path data for updates
	connection_lines.append(line)
	connection_paths.append({
		"path": path,
		"color": color,
		"line": line
	})
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drew path on tilemap. Total lines: %d | Path length: %d | From: %s To: %s | Color: %s" % [connection_lines.size(), path.size(), first_point, last_point, color]])
	
	DebugConfig.dprint("buildings", ["Drew connection line with ", path.size(), " points in ", color])

func _clear_connection_lines(immediate: bool = false):
	# Remove all Line2D nodes from the scene
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Clearing %d connection lines" % connection_lines.size()])
	for line in connection_lines:
		if is_instance_valid(line):
			if immediate:
				# When closing modal, immediately free to prevent orphaned nodes
				if line.get_parent():
					line.get_parent().remove_child(line)
				line.free()
			else:
				# Normal operation, defer deletion
				line.queue_free()
	
	connection_lines.clear()
	connection_paths.clear()
	is_showing_connections = false
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Cleared all connection lines"])
	# Note: We keep the container alive so it can be reused for subsequent drawings

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
			DebugConfig.dprint("buildings", ["Building Details: Could not find any VBoxContainer"])
			return
		
	var scroll_container = main_vbox.get_node_or_null("ScrollContainer")
	if not scroll_container:
		# Try to find ScrollContainer by type
		for child in main_vbox.get_children():
			if child is ScrollContainer:
				scroll_container = child
				break
		if not scroll_container:
			DebugConfig.dprint("buildings", ["Building Details: No ScrollContainer found"])
			return
		
	var content_vbox = scroll_container.get_node_or_null("ContentContainer")
	if not content_vbox:
		# Try to find by type
		for child in scroll_container.get_children():
			if child is VBoxContainer:
				content_vbox = child
				break
		if not content_vbox:
			DebugConfig.dprint("buildings", ["Building Details: Could not find content VBoxContainer"])
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
		
		if days_built >= 0:
			_add_info_row(info_container, "Age:", str(days_built))
	
	# Populate stats section
	if stats_container:
		# Clear existing stats
		for child in stats_container.get_children():
			child.queue_free()
		
		var building_type = building_data.get("building_type", "unknown")
		
		# Production based on building type and workers - FIRST DETAIL
		var production = _get_building_production()
		if production != "None":
			_add_info_row(stats_container, "Production:", production)
		
		# Health/Durability
		_add_info_row(stats_container, "Health:", "100/100 (Perfect)")
		
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
		# Clear existing capacity controls BUT PRESERVE the Show Paths checkbox at the top
		# The first child should be the HBoxContainer that contains the checkbox
		var first_child = capacity_container.get_child(0) if capacity_container.get_child_count() > 0 else null
		var checkbox_container = null
		
		# Identify which child is the checkbox container
		if first_child is HBoxContainer:
			# Check if this container has the checkbox as its last child
			var last_child_of_first = first_child.get_child(first_child.get_child_count() - 1) if first_child.get_child_count() > 0 else null
			if last_child_of_first == paths_toggle_checkbox:
				checkbox_container = first_child
		
		# Queue free all children except the checkbox container
		for child in capacity_container.get_children():
			if child != checkbox_container:
				child.queue_free()
		
		var building_type = building_data.get("building_type", "unknown")
		DebugConfig.dprint("buildings", ["UI DEBUG: Populating capacity section for building_type: ", building_type])
		
		# Barracks has a single job type: soldiers stationed there auto-train
		if building_type == "barracks":
			DebugConfig.dprint("buildings", ["UI DEBUG: Creating barracks capacity controls"])
			_create_capacity_control(capacity_container, "Soldiers:", 10, "station")
		elif building_type == "farm":
			# Farm tile — show current growth state and worker assignment
			_create_farm_state_display(capacity_container)
		else:
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
		
		# Clear and rebuild connections data for selection
		building_connections_data.clear()
		selected_building_path_index = -1
		
		var connections = building_data.get("connections", [])
		if connections.is_empty():
			var no_connections_label = Label.new()
			no_connections_label.text = "No connections in range"
			no_connections_label.add_theme_color_override("font_color", Color.GRAY)
			connections_container.add_child(no_connections_label)
		else:
			var connection_index = 0
			for connection in connections:
				# Store connection data with index for selection
				building_connections_data.append(connection)
				
				# Create a row for this connection
				var connection_row = HBoxContainer.new()
				connection_row.add_theme_constant_override("separation", 10)
				connections_container.add_child(connection_row)
				
				# Connection identifier button (clickable) with unique path ID
				var connection_button = Button.new()
				
				# Create unique path ID for this connection - use display name if available
				var display_name = connection.get("display_name", connection.name)
				connection_button.text = display_name
				connection_button.custom_minimum_size.x = 150
				connection_button.pressed.connect(_on_building_path_clicked.bindv([connection_index]))
				connection_row.add_child(connection_button)
				
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
				details_label.text = display_name + " (" + str(connection.distance) + " tiles)"
				details_label.custom_minimum_size.x = 150
				connection_row.add_child(details_label)
				
				connection_index += 1

func _populate_jobs_from_building():
	"""Populate jobs section with jobs from the building's metadata"""
	var jobs_container = find_child("JobsContainer", true, false)
	if not jobs_container:
		return
	
	# Clear selected path visualization when refreshing jobs list
	_clear_selected_path()
	selected_job_index = -1
	
	# Clear existing job rows (but not the toggle checkbox)
	for child in jobs_container.get_children():
		child.queue_free()
	
	# Get jobs from building metadata
	var jobs = building_node.get_meta("resource_jobs", [])
	DebugConfig.dprint("buildings", ["UI DEBUG: _populate_jobs_from_building - found ", jobs.size(), " jobs on building ", building_node.name])
	
	if jobs.is_empty():
		DebugConfig.dprint("buildings", ["UI DEBUG: No jobs found, showing 'No jobs configured' message"])
		var no_jobs_label = Label.new()
		no_jobs_label.text = "No jobs configured"
		no_jobs_label.add_theme_color_override("font_color", Color.GRAY)
		jobs_container.add_child(no_jobs_label)
	else:
		DebugConfig.dprint("buildings", ["UI DEBUG: Displaying ", jobs.size(), " jobs"])
		for i in range(jobs.size()):
			_add_job_row(jobs_container, jobs[i], i)
	
	# Redraw paths and connections if toggle is on (in case job paths changed due to capacity)
	if paths_toggle_checkbox and paths_toggle_checkbox.button_pressed:
		_clear_all_job_path_lines()
		_clear_connection_lines()
		_draw_all_job_paths()
		_draw_connection_lines()

func _add_job_row(container: Container, job: Dictionary, job_index: int):
	"""Add a single job row to the jobs container with clickable path"""
	var job_row = HBoxContainer.new()
	job_row.add_theme_constant_override("separation", 10)
	container.add_child(job_row)
	
	# Job slot label — use path_id if available, otherwise a human-readable slot name
	var path_button = Button.new()
	var path_id = job.get("path_id", "")
	if path_id.is_empty():
		# Research and similar buildings have no resource path — show a numbered slot label
		var building_type = building_node.get_meta("building_type", "worker") if building_node else "worker"
		var slot_label_map = {
			"research": "Researcher",
			"town_center": "Scientist",
			"barracks": "Soldier",
			"farmhouse": "Farmer",
			"farm": "Farmer",
		}
		var slot_prefix = slot_label_map.get(building_type, "Worker")
		path_button.text = slot_prefix + " " + str(job_index + 1)
		path_button.disabled = true  # No path to visualise
		path_button.modulate = Color(0.8, 0.8, 0.8)
	else:
		path_button.text = path_id
		path_button.modulate = Color.WHITE
		path_button.pressed.connect(_on_job_path_clicked.bindv([job_index]))
	path_button.custom_minimum_size.x = 120
	path_button.set_meta("job_index", job_index)
	job_row.add_child(path_button)
	
	# Assigned unit display — clickable button opens unit details modal
	var unit_assigned = job.get("unit_assigned", null)
	if unit_assigned:
		var display_name = unit_assigned  # fallback to ID
		var found_unit: Dictionary = {}
		var game = game_node if game_node else _get_game_node()
		if game and game.get("players_data") != null:
			for pid in game.players_data:
				if str(pid) == "environment":
					continue
				for u in game.players_data[pid].get("units", []):
					if u.get("unique_id") == unit_assigned:
						display_name = u.get("name", unit_assigned)
						found_unit = u
						break
		var unit_btn = Button.new()
		unit_btn.text = display_name
		unit_btn.flat = true
		unit_btn.add_theme_color_override("font_color", Color.GREEN)
		unit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not found_unit.is_empty():
			unit_btn.pressed.connect(_on_unit_name_clicked.bind(found_unit))
		job_row.add_child(unit_btn)
		
		# Barracks/research-specific: show training progress and Train / Cancel button
		var btype = building_node.get_meta("building_type", "") if building_node else ""
		if (btype == "barracks" or btype == "research") and not found_unit.is_empty():
			_add_training_row(container, found_unit, btype)
	else:
		var unit_label = Label.new()
		unit_label.text = "Unassigned"
		unit_label.add_theme_color_override("font_color", Color.YELLOW)
		unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		job_row.add_child(unit_label)

func _add_training_row(container: Container, unit: Dictionary, building_type: String):
	"""Add a training progress / action row below a barracks or research job row."""
	var training = unit.get("training")
	var specialties = unit.get("specialties", [])
	var game = game_node if game_node else _get_game_node()
	var training_type: String = "soldier" if building_type == "barracks" else "scholar"
	
	var train_row = HBoxContainer.new()
	train_row.add_theme_constant_override("separation", 6)
	# Indent slightly
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	train_row.add_child(spacer)
	container.add_child(train_row)
	
	if training != null:
		var t_type = training.get("type", "")
		var t_name = t_type.capitalize()
		if game and game.TRAINING_DEFINITIONS.has(t_type):
			t_name = game.TRAINING_DEFINITIONS[t_type]["name"]
		var progress = training.get("progress", 0)
		var days_req = training.get("days_required", 5)
		
		var prog_bar = ProgressBar.new()
		prog_bar.min_value = 0
		prog_bar.max_value = days_req
		prog_bar.value = progress
		prog_bar.custom_minimum_size = Vector2(100, 16)
		prog_bar.show_percentage = false
		train_row.add_child(prog_bar)
		
		var prog_lbl = Label.new()
		prog_lbl.text = "%s %d/%dd" % [t_name, progress, days_req]
		prog_lbl.add_theme_color_override("font_color", Color.CYAN)
		prog_lbl.add_theme_font_size_override("font_size", 11)
		train_row.add_child(prog_lbl)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.add_theme_color_override("font_color", Color.ORANGE_RED)
		cancel_btn.custom_minimum_size = Vector2(60, 20)
		if game and game.has_method("_cancel_unit_training"):
			cancel_btn.pressed.connect(func():
				game._cancel_unit_training(unit)
				if building_node and is_instance_valid(building_node):
					setup_building_details(building_node))
		train_row.add_child(cancel_btn)
	else:
		# Show earned specialties tag (compact)
		if not specialties.is_empty():
			var names: Array[String] = []
			for s in specialties:
				if game and game.TRAINING_DEFINITIONS.has(s):
					names.append(game.TRAINING_DEFINITIONS[s]["name"])
				else:
					names.append(s.capitalize())
			var spec_lbl = Label.new()
			spec_lbl.text = "✦ " + ", ".join(names)
			spec_lbl.add_theme_color_override("font_color", Color.GOLD)
			spec_lbl.add_theme_font_size_override("font_size", 11)
			train_row.add_child(spec_lbl)
		
		# Train as Soldier/Scholar button
		var train_btn = Button.new()
		var training_label: String = game.TRAINING_DEFINITIONS[training_type]["name"] if game and game.TRAINING_DEFINITIONS.has(training_type) else training_type.capitalize()
		if training_type in specialties:
			train_btn.text = "Re-train %s" % training_label
		else:
			train_btn.text = "Train as %s" % training_label
		train_btn.custom_minimum_size = Vector2(130, 22)
		train_btn.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		if game and game.has_method("_start_unit_training"):
			train_btn.pressed.connect(func():
				game._start_unit_training(unit, training_type)
				if building_node and is_instance_valid(building_node):
					setup_building_details(building_node))
		train_row.add_child(train_btn)

func _on_unit_name_clicked(unit: Dictionary):
	"""Open the unit details modal for the clicked unit"""
	var game = game_node if game_node else _get_game_node()
	if game and game.has_method("_open_unit_details_modal"):
		game._open_unit_details_modal(unit)

func _on_job_path_clicked(job_index: int):
	"""Handle job path button click - toggle path visualization"""
	var jobs = building_node.get_meta("resource_jobs", [])
	if job_index < 0 or job_index >= jobs.size():
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Invalid job index: ", job_index])
		return
	
	# If clicking the same job, toggle it off
	if selected_job_index == job_index:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Toggling off path for job index ", job_index])
		_clear_selected_path()
		selected_job_index = -1
		return
	
	# Clear previous job selection
	_clear_selected_path()
	# Clear building path selection when selecting a job path
	_clear_selected_building_path()
	selected_building_path_index = -1
	
	# Set new selection
	selected_job_index = job_index
	var selected_job = jobs[job_index]
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drawing path for job index ", job_index, " - ", selected_job.get("path_id", "unknown")])
	_draw_selected_job_path(selected_job)

func _draw_selected_job_path(job: Dictionary):
	"""Draw the selected job's path in white on the tilemap"""
	var tile_path = job.get("tile_path", [])
	if tile_path.is_empty():
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Job has no tile path to draw"])
		return
	
	# Ensure container is ready
	_ensure_connection_lines_container()
	
	# Get tilemap reference from game
	var tilemap = game_node.get_node_or_null("TileMapLayer") if game_node else null
	if not tilemap:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Could not find tilemap for path drawing"])
		return
	
	# Create line for the selected path in white
	var line = Line2D.new()
	line.width = 6.0  # Thicker than regular paths for visibility
	line.default_color = Color.WHITE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 100  # Bring to front so it's always visible
	
	# Convert tile path to world coordinates and add to line
	for tile in tile_path:
		var world_pos = tilemap.map_to_local(tile)
		line.add_point(world_pos)
	
	# Add line to container
	if connection_lines_container and is_instance_valid(connection_lines_container):
		connection_lines_container.add_child(line)
		selected_job_path_line = line
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drew white path for selected job with ", line.get_point_count(), " points"])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Could not add path line - container invalid"])
		line.queue_free()

func _clear_selected_path():
	"""Remove the white selected path visualization"""
	if selected_job_path_line and is_instance_valid(selected_job_path_line):
		# Immediately remove from parent to prevent orphaned rendering
		if selected_job_path_line.get_parent():
			selected_job_path_line.get_parent().remove_child(selected_job_path_line)
		selected_job_path_line.free()  # Immediately free instead of queue_free
		selected_job_path_line = null
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Cleared selected job path visualization"])

func _on_building_path_clicked(connection_index: int):
	"""Handle building connection path button click - toggle path visualization"""
	if connection_index < 0 or connection_index >= building_connections_data.size():
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Invalid connection index: ", connection_index])
		return
	
	# If clicking the same connection, toggle it off
	if selected_building_path_index == connection_index:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Toggling off path for connection index ", connection_index])
		_clear_selected_building_path()
		selected_building_path_index = -1
		return
	
	# Clear previous building path selection
	_clear_selected_building_path()
	# Clear job path selection when selecting a building path
	_clear_selected_path()
	selected_job_index = -1
	
	# Set new selection
	selected_building_path_index = connection_index
	var selected_connection = building_connections_data[connection_index]
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drawing path for connection index ", connection_index, " - ", selected_connection.get("name", "unknown")])
	_draw_selected_building_path(selected_connection)

func _draw_selected_building_path(connection: Dictionary):
	"""Draw the selected building's connection path in white on the tilemap"""
	if not building_node or not game_node:
		return
	
	var tilemap = game_node.get_node_or_null("TileMapLayer")
	if not tilemap:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Could not find tilemap for path drawing"])
		return
	
	# Ensure container is ready
	_ensure_connection_lines_container()
	
	var path = []
	
	# Try to use pre-calculated path if available
	if connection.has("path") and not connection["path"].is_empty():
		path = connection["path"]
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Using pre-calculated path for ", connection.name])
	else:
		# Otherwise, calculate path if we have tile coordinates
		var building_tile_coords = tilemap.local_to_map(building_node.position)
		
		if connection.has("tile_coords"):
			# Use A* pathfinding to get tile path
			var target_tile = connection["tile_coords"]
			var tile_path = _astar_pathfind(building_tile_coords, target_tile, tilemap)
			if not tile_path.is_empty():
				path = tile_path
				DebugConfig.dprint("buildings", ["BuildingDetailsModal: Calculated A* path to ", connection.name, " with ", tile_path.size(), " tiles"])
			else:
				DebugConfig.dprint("buildings", ["BuildingDetailsModal: No path found to ", connection.name])
				return
		else:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Connection has no tile_coords data"])
			return
	
	# Create line for the selected path in white
	var line = Line2D.new()
	line.width = 6.0  # Thicker than regular paths for visibility
	line.default_color = Color.WHITE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 100  # Bring to front so it's always visible
	
	# Convert path to world coordinates and add to line
	for point in path:
		var world_pos: Vector2
		if point is Vector2i:
			# Tile coordinates - convert to world
			world_pos = tilemap.map_to_local(point)
		else:
			# Already world coordinates
			world_pos = point as Vector2
		line.add_point(world_pos)
	
	# Add line to container
	if connection_lines_container and is_instance_valid(connection_lines_container):
		connection_lines_container.add_child(line)
		selected_building_path_line = line
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drew white path for selected connection with ", line.get_point_count(), " points"])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Could not add path line - container invalid, ensuring it exists"])
		_ensure_connection_lines_container()
		if connection_lines_container and is_instance_valid(connection_lines_container):
			connection_lines_container.add_child(line)
			selected_building_path_line = line
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drew white path after recreating container"])
		else:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: ERROR - could not create container for path"])
			line.queue_free()

func _clear_selected_building_path():
	"""Remove the white selected building path visualization"""
	if selected_building_path_line and is_instance_valid(selected_building_path_line):
		# Immediately remove from parent to prevent orphaned rendering
		if selected_building_path_line.get_parent():
			selected_building_path_line.get_parent().remove_child(selected_building_path_line)
		selected_building_path_line.free()  # Immediately free instead of queue_free
		selected_building_path_line = null
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Cleared selected building path visualization"])

func _on_paths_toggle_toggled(toggled_on: bool):
	"""Handle paths toggle checkbox - controls both job paths and building connections"""
	if not building_node:
		return
	
	# Store the toggle state for this building
	building_paths_visibility[building_node.name] = toggled_on
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Paths toggle for %s set to %s" % [building_node.name, toggled_on]])
	
	if toggled_on:
		_draw_all_job_paths()
		_draw_connection_lines()
	else:
		_clear_all_job_path_lines()
		_clear_connection_lines()

func _draw_all_job_paths():
	"""Draw all job paths for the current building in colored lines"""
	if not building_node or not game_node:
		return
	
	_ensure_connection_lines_container()
	
	var jobs = building_node.get_meta("resource_jobs", [])
	if jobs.is_empty():
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: No jobs to draw"])
		return
	
	var tilemap = game_node.get_node_or_null("TileMapLayer")
	if not tilemap:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Could not find tilemap for path drawing"])
		return
	
	# Colors for different resource types
	var resource_colors = {
		"trees": Color.GREEN,
		"mountains": Color.GRAY,
		"fish": Color.DEEP_SKY_BLUE,
		"farm": Color(0.9, 0.75, 0.2),  # wheat yellow
		"unknown": Color.LIGHT_GRAY
	}
	
	# Draw each job's path
	for i in range(jobs.size()):
		var job = jobs[i]
		var tile_path = job.get("tile_path", [])
		
		if tile_path.is_empty():
			continue
		
		# Get color based on resource type
		var resource_type = job.get("resource_type", "unknown")
		var color = resource_colors.get(resource_type, Color.LIGHT_GRAY)
		
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		# Convert tile path to world coordinates
		for tile in tile_path:
			var world_pos = tilemap.map_to_local(tile)
			line.add_point(world_pos)
		
		# Add line to container
		if connection_lines_container and is_instance_valid(connection_lines_container):
			connection_lines_container.add_child(line)
			all_job_path_lines.append(line)
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Drew path for job %d (%s) with %d points" % [i, resource_type, line.get_point_count()]])

func _clear_all_job_path_lines(immediate: bool = false):
	"""Remove all drawn job path lines"""
	for line in all_job_path_lines:
		if line and is_instance_valid(line):
			if immediate:
				# When closing modal, immediately free to prevent orphaned nodes
				if line.get_parent():
					line.get_parent().remove_child(line)
				line.free()
			else:
				# Normal operation, defer deletion
				line.queue_free()
	all_job_path_lines.clear()
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Cleared all job path lines"])

func _debug_print_tree(node: Node, indent: int):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	DebugConfig.dprint("buildings", [indent_str + "- " + node.name + " (" + node.get_class() + ")"])
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
		"research":
			return "Research"
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
	
	# For worker capacity buildings, count filled jobs instead of occupancy
	var worker_occupancy = 0
	if building_node:
		var jobs = building_node.get_meta("resource_jobs", [])
		if not jobs.is_empty():  # This is a worker capacity building
			for job in jobs:
				if job.get("unit_assigned") != null:
					worker_occupancy += 1
	
	# Fallback to old occupancy value if no jobs (shouldn't happen, but safety)
	if worker_occupancy == 0:
		worker_occupancy = building_data.get("worker_occupancy", 0)
	
	match building_type:
		"fishing_hut":
			var food_production = worker_occupancy * 5  # +5 food per worker
			return "+" + str(food_production) + " Food/day (" + str(worker_occupancy) + " workers)"
		"house":
			return "Housing (no production)"
		"town_center":
			var science_production = worker_occupancy * 3  # +3 science per scientist
			return "+" + str(science_production) + " Science/day (" + str(worker_occupancy) + " scientists)"
		"research":
			var science_production = worker_occupancy * 3  # +3 science per researcher
			return "+" + str(science_production) + " Science/day (" + str(worker_occupancy) + " researchers)"
		"barracks":
			return "Barracks (no production)"
		"farm":
			var state: String = ""
			if building_node:
				state = building_node.get_meta("farm_state", "tilled")
			var has_worker: bool = building_node.get_meta("farm_worker_assigned", false) if building_node else false
			if has_worker and state == "grown":
				return "+25 Food on harvest (ready!)"
			elif has_worker:
				return "Growing... (%s)" % state.capitalize()
			else:
				return "No worker assigned"
		"farmhouse":
			# Count how many farm tiles this farmhouse is working
			var worked := 0
			var grown := 0
			if building_node:
				var fh_jobs: Array = building_node.get_meta("resource_jobs", [])
				var game_node = _get_game_node()
				for job in fh_jobs:
					if job.get("resource_type", "") == "farm" and job.get("unit_assigned") != null:
						worked += 1
						if game_node and is_instance_valid(game_node.map_objects_holder):
							var farm_nd = game_node.map_objects_holder.get_node_or_null(NodePath(job.get("resource_id", "")))
							if is_instance_valid(farm_nd) and farm_nd.get_meta("farm_state", "") == "grown":
								grown += 1
			if worked == 0:
				return "No farms being worked"
			return "Working %d farm(s) — %d ready to harvest" % [worked, grown]
		"stoneworker":
			var stone_production = worker_occupancy * 1  # +1 stone per worker
			return "+" + str(stone_production) + " Stone/day (" + str(worker_occupancy) + " workers)"
		"lumberjack":
			var wood_production = worker_occupancy * 1  # +1 wood per worker
			return "+" + str(wood_production) + " Wood/day (" + str(worker_occupancy) + " workers)"
		"lumber_mill":
			var wood_production = worker_occupancy * 1  # +1 wood per worker
			return "+" + str(wood_production) + " Wood/day (" + str(worker_occupancy) + " workers)"
		_:
			return "Unknown"

func _get_building_maintenance() -> String:
	var building_type = building_data.get("building_type", "unknown")
	match building_type:
		"fishing_hut":
			return "1 Gold/turn"
		"house":
			return "0.5 Gold/turn"
		"town_center":
			return "2 Gold/turn"
		"research":
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
		_:
			return 0

func _get_worker_capacity(building_type: String) -> int:
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

func _get_special_effects(building_type: String) -> String:
	match building_type:
		"town_center":
			return "Administrative center, enables other buildings"
		"barracks":
			return "Military training, +10% unit combat effectiveness"
		"research":
			return "Scientific research, generates science for tech advancement"
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
	# Call the full close_modal() to ensure ALL paths (connection_lines, job_path_lines, etc.) are cleaned up
	close_modal()
	close_requested.emit()
	# Queue_free will be called by game.gd's _on_building_details_closed callback
	# This ensures the modal is fully cleaned up and freed after signals are processed

func _register_with_ui_manager():
	"""Register this modal with the UI manager's modal stack"""
	if _registered_with_ui_manager:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Already registered with UI manager"])
		return  # Already registered
	var ui_manager = _get_ui_manager()
	if ui_manager and ui_manager.has_method("push_modal"):
		ui_manager.push_modal(self)
		_registered_with_ui_manager = true
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Successfully registered with UI manager"])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Failed to register - UI manager not found or no push_modal method"])

func close_modal():
	"""Close the modal and clear all visual elements"""
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: close_modal() called - clearing connection lines"])
	_clear_connection_lines(true)  # Immediate cleanup when closing
	# Clear selected job path visualization
	_clear_selected_path()
	# Clear selected building path visualization
	_clear_selected_building_path()
	selected_building_path_index = -1
	# Clear all job path lines
	_clear_all_job_path_lines(true)  # Immediate cleanup when closing
	selected_job_index = -1
	# Remove and clean up container when modal closes
	if connection_lines_container and is_instance_valid(connection_lines_container):
		# First clear any remaining children (shouldn't be any after above cleanup)
		for child in connection_lines_container.get_children():
			if is_instance_valid(child):
				child.free()
		# Remove from tree to prevent visual overlap with new modal's container
		if connection_lines_container.get_parent():
			connection_lines_container.get_parent().remove_child(connection_lines_container)
		connection_lines_container.free()  # Immediately free the container too
		connection_lines_container = null
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Removed and freed connection lines container on close"])
	
	# Disconnect from game's building_jobs_updated signal
	var game = building_node.get_parent().get_parent() if building_node else null
	if game and game.is_connected("building_jobs_updated", Callable(self, "_on_building_jobs_updated")):
		game.disconnect("building_jobs_updated", Callable(self, "_on_building_jobs_updated"))
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Disconnected from building_jobs_updated signal"])
	
	visible = false

func _unregister_from_ui_manager():
	"""Unregister this modal from the UI manager's modal stack"""
	if not _registered_with_ui_manager:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Not registered, skipping unregister"])
		return  # Not registered
	var ui_manager = _get_ui_manager()
	if ui_manager and ui_manager.has_method("pop_modal"):
		ui_manager.pop_modal(self)
		_registered_with_ui_manager = false
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Successfully unregistered from UI manager"])
	else:
		DebugConfig.dprint("buildings", ["BuildingDetailsModal: Failed to unregister - UI manager not found"])

func _get_ui_manager():
	"""Get reference to UI manager from game node"""
	# Try to get from game node's meta
	var current = get_parent()
	while current:
		if current.has_meta("ui_manager"):
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Found UI manager via metadata"])
			return current.get_meta("ui_manager")
		current = current.get_parent()
	
	# Fallback: try to find UIManager node
	if get_parent():
		var ui_mgr = get_parent().get_node_or_null("UIManager")
		if ui_mgr:
			DebugConfig.dprint("buildings", ["BuildingDetailsModal: Found UI manager via node lookup"])
			return ui_mgr
	
	DebugConfig.dprint("buildings", ["BuildingDetailsModal: Failed to find UI manager"])
	return null

func _on_upgrade_pressed():
	var building_name = building_data.get("name", "Unknown")
	var building_type = building_data.get("building_type", "unknown")
	DebugConfig.dprint("buildings", ["Upgrade building: ", building_name, " (", building_type, ")"])
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
	DebugConfig.dprint("buildings", ["Train units at: ", building_name])
	# TODO: Open unit training interface

func _on_collect_resources_pressed():
	var building_name = building_data.get("name", "Unknown")
	var building_type = building_data.get("building_type", "unknown")
	DebugConfig.dprint("buildings", ["Collect resources from: ", building_name, " (", building_type, ")"])
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

func _create_farm_state_display(parent: Container) -> void:
	"""Show the farm tile's growth stage and worker assignment in the capacity panel."""
	if not building_node:
		return

	var state: String = building_node.get_meta("farm_state", "tilled")
	var has_worker: bool = building_node.get_meta("farm_worker_assigned", false)

	# Growth stage row
	var state_row = HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 10)
	parent.add_child(state_row)

	var state_lbl = Label.new()
	state_lbl.text = "Growth Stage:"
	state_lbl.custom_minimum_size.x = 120
	state_row.add_child(state_lbl)

	const STAGE_COLORS := {
		"tilled":  Color(0.6, 0.45, 0.25),
		"sown":    Color(0.8, 0.75, 0.3),
		"growing": Color(0.4, 0.85, 0.3),
		"grown":   Color(0.2, 1.0, 0.2),
	}
	var stage_val = Label.new()
	stage_val.text = state.capitalize()
	stage_val.add_theme_color_override("font_color", STAGE_COLORS.get(state, Color.WHITE))
	state_row.add_child(stage_val)

	# Worker assignment row
	var worker_row = HBoxContainer.new()
	worker_row.add_theme_constant_override("separation", 10)
	parent.add_child(worker_row)

	var worker_lbl = Label.new()
	worker_lbl.text = "Worker:"
	worker_lbl.custom_minimum_size.x = 120
	worker_row.add_child(worker_lbl)

	var worker_val = Label.new()
	if has_worker:
		worker_val.text = "✓ Assigned"
		worker_val.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		worker_val.text = "None"
		worker_val.add_theme_color_override("font_color", Color.GRAY)
	worker_row.add_child(worker_val)

	# Which farmhouse is working this tile
	var game_node = _get_game_node()
	if game_node and is_instance_valid(game_node.map_objects_holder):
		for child in game_node.map_objects_holder.get_children():
			if not game_node._is_building_node(child):
				continue
			if child.get_meta("building_type", "") != "farmhouse":
				continue
			var fh_jobs: Array = child.get_meta("resource_jobs", [])
			for job in fh_jobs:
				if job.get("resource_id", "") == building_node.name:
					var fh_row = HBoxContainer.new()
					fh_row.add_theme_constant_override("separation", 10)
					parent.add_child(fh_row)
					var fh_lbl = Label.new()
					fh_lbl.text = "Managed by:"
					fh_lbl.custom_minimum_size.x = 120
					fh_row.add_child(fh_lbl)
					var fh_val = Label.new()
					fh_val.text = child.get_meta("display_name", child.name)
					fh_val.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
					fh_row.add_child(fh_val)
					break

func _create_capacity_control(parent: Container, label_text: String, max_capacity: int, capacity_type: String):
	# Create horizontal container for the capacity control
	DebugConfig.dprint("buildings", ["UI DEBUG: Creating capacity control - label: ", label_text, " type: ", capacity_type, " max: ", max_capacity])
	
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
	
	# Current/Max display
	var capacity_label = Label.new()
	var current_occupancy = 0
	
	# For worker capacity, count filled job slots; for others, use occupancy metadata
	if capacity_type == "worker" and building_node:
		var jobs = building_node.get_meta("resource_jobs", [])
		var filled_count = 0
		for job in jobs:
			if job.get("unit_assigned") != null:
				filled_count += 1
		current_occupancy = filled_count
		DebugConfig.dprint("buildings", ["UI DEBUG: Worker capacity - jobs.size()=%d, filled=%d" % [jobs.size(), filled_count]])
	elif building_node:
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
	
	DebugConfig.dprint("buildings", ["UI DEBUG: Stored metadata - type: ", capacity_label.get_meta("capacity_type"), " current: ", capacity_label.get_meta("current_value")])
	
	# Connect button signals
	plus_btn.pressed.connect(_on_capacity_plus_pressed.bind(capacity_label))
	minus_btn.pressed.connect(_on_capacity_minus_pressed.bind(capacity_label))
	
	DebugConfig.dprint("buildings", ["UI DEBUG: Connected button signals for capacity_type: ", capacity_type])

func _on_capacity_plus_pressed(capacity_label: Label):
	var current_value = capacity_label.get_meta("current_value", 0)
	var max_value = capacity_label.get_meta("max_value", 0)
	var capacity_type = capacity_label.get_meta("capacity_type", "")
	
	DebugConfig.dprint("buildings", ["UI DEBUG: _on_capacity_plus_pressed - capacity_type: ", capacity_type, " current: ", current_value, " max: ", max_value])
	
	if current_value < max_value:
		# Try to update building occupancy through game validation
		var game_node = _get_game_node()
		if game_node and game_node.has_method("update_building_occupancy"):
			DebugConfig.dprint("buildings", ["UI DEBUG: Calling update_building_occupancy with capacity_type: ", capacity_type])
			if game_node.update_building_occupancy(building_node, capacity_type, current_value + 1):
				# Success - update UI
				current_value += 1
				capacity_label.set_meta("current_value", current_value)
				capacity_label.text = str(current_value) + "/" + str(max_value)
				
				# Update building data
				building_data[capacity_type + "_occupancy"] = current_value
				
				# Refresh population and resources modals if they're open
				_refresh_population_modal()
				_refresh_resources_modal()
				
				DebugConfig.dprint("buildings", ["Increased ", capacity_type, " occupancy to ", current_value, "/", max_value])
			else:
				DebugConfig.dprint("buildings", ["Cannot increase capacity - not enough available population"])
		else:
			DebugConfig.dprint("buildings", ["UI DEBUG: game_node not found or no update_building_occupancy method"])


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
				
				# Refresh population and resources modals if they're open
				_refresh_population_modal()
				_refresh_resources_modal()
				
				DebugConfig.dprint("buildings", ["Decreased ", capacity_type, " occupancy to ", current_value, "/", max_value])

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

func _refresh_resources_modal():
	# Refresh the resources modal if it's currently open
	var game_node = _get_game_node()
	if game_node and game_node.has_method("get") and game_node.resources_modal:
		if is_instance_valid(game_node.resources_modal) and game_node.resources_modal.visible:
			if game_node.resources_modal.has_method("refresh_content"):
				game_node.resources_modal.refresh_content()

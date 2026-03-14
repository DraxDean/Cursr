# scripts/ui/unit_view_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var tilemap_ref: TileMapLayer
var current_unit: Dictionary = {}
var connection_lines: Array = []  # Store Line2D nodes for path visualization

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	# Get tilemap reference from game object
	if game_ref and game_ref.has_meta("tilemap_layer"):
		tilemap_ref = game_ref.get_meta("tilemap_layer")
	elif game_ref and "tilemap_layer" in game_ref:
		tilemap_ref = game_ref.tilemap_layer
	super("unit_view", "Unit Details: ", start_position)

func display_unit(unit: Dictionary):
	"""Display details for a specific unit"""
	current_unit = unit
	# Update the title with the unit name
	title_label.text = "Unit Details: " + current_unit.get("name", "Unknown")
	refresh_content()
	
	# Draw unit paths on the tilemap
	_draw_unit_paths()

func refresh_content():
	clear_content()
	
	if current_unit.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No unit selected"
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(empty_label)
		fit_to_content()
		return
	
	# Title - Unit Details: (name)
	var title_label = Label.new()
	title_label.text = "Unit Details: " + current_unit.get("name", "Unknown")
	title_label.add_theme_color_override("font_color", Color.CYAN)
	title_label.add_theme_font_size_override("font_size", 18)
	add_content_child(title_label)
	
	# Type and Race on one line
	var type_race_label = Label.new()
	var race = current_unit.get("race", "unknown").to_lower()
	var unit_type = current_unit.get("type", "unknown").to_lower()
	type_race_label.text = "%s %s" % [race, unit_type]
	type_race_label.add_theme_color_override("font_color", Color.YELLOW)
	type_race_label.add_theme_font_size_override("font_size", 14)
	add_content_child(type_race_label)
	
	# Portrait and data container (horizontal layout)
	var main_container = HBoxContainer.new()
	add_content_child(main_container)
	
	# Character Portrait
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/portraits/human-portrait-male-peasant-brownhair.png")
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	portrait.custom_minimum_size = Vector2(120, 150)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(portrait)
	
	# Data fields container (right side)
	var data_container = VBoxContainer.new()
	main_container.add_child(data_container)
	
	# Job
	var job_container = HBoxContainer.new()
	data_container.add_child(job_container)
	var job_label = Label.new()
	job_label.text = "Job: "
	job_label.add_theme_color_override("font_color", Color.WHITE)
	job_label.custom_minimum_size = Vector2(80, 20)
	job_container.add_child(job_label)
	var job_value = Label.new()
	var job = current_unit.get("job", null)
	job_value.text = "Unemployed" if job == null else str(job)
	job_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	job_container.add_child(job_value)
	
	# Living Quarters
	var living_container = HBoxContainer.new()
	data_container.add_child(living_container)
	var living_label = Label.new()
	living_label.text = "Living: "
	living_label.add_theme_color_override("font_color", Color.WHITE)
	living_label.custom_minimum_size = Vector2(80, 20)
	living_container.add_child(living_label)
	var living_value = Label.new()
	var living_quarters = current_unit.get("living_quarters", null)
	living_value.text = "None" if living_quarters == null else str(living_quarters)
	living_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	living_container.add_child(living_value)
	
	# Speed Multiplier
	var speed_container = HBoxContainer.new()
	data_container.add_child(speed_container)
	var speed_label = Label.new()
	speed_label.text = "Speed: "
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.custom_minimum_size = Vector2(80, 20)
	speed_container.add_child(speed_label)
	var speed_value = Label.new()
	var speed_mult = current_unit.get("speed_multiplier", 1.0)
	var speed_percent = int(speed_mult * 100)
	speed_value.text = str(speed_percent) + "%"
	speed_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	speed_container.add_child(speed_value)
	
	# Unit ID (underneath everything)
	var id_container = HBoxContainer.new()
	add_content_child(id_container)
	var id_label = Label.new()
	id_label.text = "ID: "
	id_label.add_theme_color_override("font_color", Color.WHITE)
	id_label.custom_minimum_size = Vector2(60, 20)
	id_container.add_child(id_label)
	var id_value = Label.new()
	id_value.text = current_unit.get("unique_id", "unknown")
	id_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	id_container.add_child(id_value)
	
	fit_to_content()
func _draw_unit_paths():
	"""Draw unit's paths: current movement, home, job, and resource"""
	if not tilemap_ref or current_unit.is_empty():
		return
	
	# Clear existing paths
	_clear_connection_lines()
	
	var unit_pos = current_unit.get("position", Vector2.ZERO)
	
	# Draw current movement path (if unit is moving)
	var movement_state = current_unit.get("movement_state", "idle")
	var current_path = current_unit.get("current_path", [])
	if movement_state == "moving" and not current_path.is_empty():
		# Draw current path in red (active movement)
		_draw_path_on_tilemap(current_path, Color.RED, tilemap_ref)
	
	# Draw path to job (work)
	var job = current_unit.get("job", null)
	if job:
		# Extract building name from job (handle barracks job naming: barracks1_station -> barracks1)
		var job_building_name = job
		if job.contains("_station") or job.contains("_training"):
			job_building_name = job.substr(0, job.rfind("_"))
		
		if game_ref.map_objects_holder.has_node(NodePath(job_building_name)):
			var job_building = game_ref.map_objects_holder.get_node(NodePath(job_building_name))
			var path_to_job = game_ref._get_path_between_positions(unit_pos, job_building.position)
			if not path_to_job.is_empty():
				_draw_path_on_tilemap(path_to_job, Color.GREEN, tilemap_ref)
	
	# Draw path to home (living quarters)
	var living_quarters = current_unit.get("living_quarters", null)
	if living_quarters and game_ref.map_objects_holder.has_node(NodePath(living_quarters)):
		var home_building = game_ref.map_objects_holder.get_node(NodePath(living_quarters))
		var path_to_home = game_ref._get_path_between_positions(unit_pos, home_building.position)
		if not path_to_home.is_empty():
			_draw_path_on_tilemap(path_to_home, Color.BLUE, tilemap_ref)
	
	# Draw path to job's resource (if available in the job)
	var job_assignment = current_unit.get("job", null)
	if job_assignment:
		# Extract building name from job (handle barracks job naming: barracks1_station -> barracks1)
		var job_building_name = job_assignment
		if job_assignment.contains("_station") or job_assignment.contains("_training"):
			job_building_name = job_assignment.substr(0, job_assignment.rfind("_"))
		
		# Get the assigned job from building metadata
		var assigned_job_index = current_unit.get("assigned_job_index", -1)
		if assigned_job_index >= 0 and game_ref.map_objects_holder.has_node(NodePath(job_building_name)):
			var job_building = game_ref.map_objects_holder.get_node(NodePath(job_building_name))
			var jobs = job_building.get_meta("resource_jobs", [])
			
			if assigned_job_index < jobs.size():
				var assigned_job = jobs[assigned_job_index]
				var tile_path = assigned_job.get("tile_path", [])
				
				# Convert tile path to world coordinates and draw
				if not tile_path.is_empty():
					var world_resource_path = []
					for tile_coord in tile_path:
						world_resource_path.append(tilemap_ref.map_to_local(tile_coord))
					
					if not world_resource_path.is_empty():
						_draw_path_on_tilemap(world_resource_path, Color.ORANGE, tilemap_ref)

func _draw_path_on_tilemap(path: Array, color: Color, tilemap: TileMapLayer):
	"""Draw a path as a Line2D on the tilemap"""
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.z_index = 100  # Draw above everything else
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Convert positions to points (they're already world positions from _get_path_between_positions)
	for world_pos in path:
		if world_pos is Vector2:
			line.add_point(world_pos)
		else:
			# It's a tile coordinate, convert to world position
			var world_position = tilemap.map_to_local(world_pos)
			line.add_point(world_position)
	
	# Add line to the tilemap layer
	tilemap.add_child(line)
	connection_lines.append(line)

func _clear_connection_lines():
	"""Clear all drawn paths"""
	for line in connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	connection_lines.clear()

func close_modal():
	"""Close the modal and clean up paths"""
	_clear_connection_lines()
	visible = false

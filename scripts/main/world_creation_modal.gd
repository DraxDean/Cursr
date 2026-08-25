# scripts/main/world_creation_modal.gd
extends Node

# Constants
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# World generation
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")
var generator: WorldGenerator
var world_data: Dictionary = {}
var step_states: Array[Dictionary] = []
var current_step: int = 0
var rng = RandomNumberGenerator.new()

# References to game elements
var game_node: Node
var tilemap_layer: TileMapLayer
var camera: Camera2D
var ui_manager: Node

# UI References
var header_component: Node
var footer_component: Node

# Town center placement state
var is_placing_town_center: bool = false
var town_center_preview_sprite: Sprite2D
var town_center_placed: bool = false

# Generation steps data
var generation_steps = [
	{
		"title": "In the beginning...",
		"description": "There was nothing but darkness and void.\nPress Continue to begin creation.",
		"action": "_step_void"
	},
	{
		"title": "Let there be Water",
		"description": "The vast oceans spread across the empty world,\ncovering everything in endless blue depths.",
		"action": "_step_water"
	},
	{
		"title": "Let there be Land", 
		"description": "From the depths rises a great continent of sand,\nbreaking the surface of the endless sea.",
		"action": "_step_land"
	},
	{
		"title": "Let there be Ice",
		"description": "At the world's edges, eternal winter takes hold,\nfreezing the northern and southern waters.",
		"action": "_step_ice"
	},
	{
		"title": "Let there be Mountains",
		"description": "Great peaks rise from the earth,\ntowering monuments of stone and snow.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_mountains"
	},
	{
		"title": "Let there be Forests",
		"description": "Vast woodlands spread across the land,\nbringing life and shelter to the world.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_forests"
	},
	{
		"title": "Let there be Plains",
		"description": "Rolling grasslands complete the world,\nperfect for civilization to take root.",
		"action": "_step_plains"
	},
	{
		"title": "Let there be Mountain Peaks",
		"description": "Mighty peaks rise from the mountain ranges,\ncreating majestic landmarks across the world.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_mountain_peaks"
	},
	{
		"title": "Let there be Ancient Forests",
		"description": "Ancient trees take root in the fertile woodlands,\ncreating mystical forests full of life and wonder.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_ancient_forests"
	},
	{
		"title": "Let there be Fish",
		"description": "The oceans teem with life,\nthriving schools of fish swim in the deep.",
		"action": "_step_fish"
	},
	{
		"title": "Choose Your People",
		"description": "Select the race that will inhabit this world\nand choose their starting settlement.",
		"action": "_step_race_select"
	},
	{
		"title": "Choose Your Settlement Location",
		"description": "Your settlement will be built in the center of the world.",
		"action": "_step_choose_starting_tile"
	},
	{
		"title": "Name Your Settlement",
		"description": "Choose a name for your new settlement.",
		"action": "_step_name_settlement"
	}
]

# Variables for town naming
var town_names: Array = []
var selected_town_name: String = ""

func setup_direct_ui(game_ref: Node, tilemap_ref: TileMapLayer, camera_ref: Camera2D):
	game_node = game_ref
	tilemap_layer = tilemap_ref
	camera = camera_ref
	
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Setting up direct UI control"])
	
	# Load town center names for naming step
	_load_town_center_names()
	
	# Create our own UI elements directly in the UI_Layer
	_create_world_creation_ui()
	
	# Initialize
	rng.randomize()
	generator = WorldGenerator.new()
	current_step = 0
	step_states.clear()
	
	# Start first step
	_show_current_step()
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Direct UI setup complete"])

func _create_world_creation_ui():
	# Get the UI layer
	var ui_layer = game_node.get_node("UI_Layer")
	
	# Hide the scene-based WorldCreationPanel that has the full-screen overlay
	var scene_panel = ui_layer.get_node_or_null("WorldCreationPanel")
	if scene_panel:
		scene_panel.visible = false
	
	# Create header component
	var WorldCreationHeader = preload("res://scripts/main/world_creation_header.gd")
	header_component = WorldCreationHeader.new()
	ui_layer.add_child(header_component)
	
	# Create footer component  
	var WorldCreationFooter = preload("res://scripts/main/world_creation_footer.gd")
	footer_component = WorldCreationFooter.new()
	ui_layer.add_child(footer_component)
	
	# Connect footer signals
	footer_component.back_pressed.connect(_on_back_pressed)
	footer_component.reset_camera_pressed.connect(_on_reset_camera_pressed)
	footer_component.reroll_pressed.connect(_on_reroll_pressed)
	footer_component.continue_pressed.connect(_on_continue_pressed)
	footer_component.start_game_pressed.connect(_on_start_game_pressed)
	
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Header/Footer components created and connected"])

func cleanup_ui():
	# Clean up our UI elements when done
	var _ui_layer = game_node.get_node("UI_Layer")
	
	# Clean up town center preview sprite
	if town_center_preview_sprite and is_instance_valid(town_center_preview_sprite):
		town_center_preview_sprite.queue_free()
	
	# Clean up race selection UI if it exists
	if has_meta("race_select_ui"):
		var race_ui = get_meta("race_select_ui")
		if is_instance_valid(race_ui):
			race_ui.queue_free()
		remove_meta("race_select_ui")
	
	# Clean up naming UI if it exists
	if has_meta("naming_ui"):
		var naming_ui = get_meta("naming_ui")
		if is_instance_valid(naming_ui):
			naming_ui.queue_free()
		remove_meta("naming_ui")
	
	if has_meta("settlement_name_input"):
		remove_meta("settlement_name_input")
	
	# Clean up preview sprite if it exists
	if has_meta("preview_sprite"):
		var preview_sprite = get_meta("preview_sprite")
		if is_instance_valid(preview_sprite):
			preview_sprite.queue_free()
		remove_meta("preview_sprite")
	
	# Disable tile selection mode (if it was enabled)
	var camera_controller = game_node.get_node("CameraController")
	if camera_controller:
		camera_controller.tile_selection_mode = false
		if camera_controller.tile_clicked.is_connected(_on_tile_selected):
			camera_controller.tile_clicked.disconnect(_on_tile_selected)
	
	if header_component:
		header_component.queue_free()
		header_component = null
	if footer_component:
		footer_component.queue_free()
		footer_component = null


func _on_tile_selected(tile_pos: Vector2):
	# Store starting tile position
	world_data["starting_tile"] = tile_pos
	DebugConfig.dprint("world_gen", ["Selected starting tile at: ", tile_pos])
	# Preview fishing hut at selected position
	_preview_fishing_hut(tile_pos)

func _show_town_center_preview(tile_pos: Vector2):
	# Clean up existing preview if any
	if town_center_preview_sprite and is_instance_valid(town_center_preview_sprite):
		town_center_preview_sprite.queue_free()
	
	# Load town center texture
	var town_center_texture = preload("res://assets/buildings/human_towncentre-export.png")
	
	# Create a sprite node for the preview
	town_center_preview_sprite = Sprite2D.new()
	town_center_preview_sprite.name = "TownCenterPreview"
	town_center_preview_sprite.texture = town_center_texture
	town_center_preview_sprite.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	town_center_preview_sprite.z_index = 10  # Make sure it's above the tilemap
	
	# Position it at the upside-down triangle meeting point
	if tilemap_layer:
		# Get the midpoint between the two tiles above the center tile
		var tile_above_left = tilemap_layer.map_to_local(Vector2i(int(tile_pos.x) - 1, int(tile_pos.y) - 1))
		var tile_above_right = tilemap_layer.map_to_local(Vector2i(int(tile_pos.x), int(tile_pos.y) - 1))
		var midpoint = (tile_above_left + tile_above_right) / 2.0
		
		town_center_preview_sprite.position = midpoint
		
		# Add to the tilemap's parent so it's in the right layer
		tilemap_layer.get_parent().add_child(town_center_preview_sprite)
	
	DebugConfig.dprint("world_gen", ["Town center preview shown at: ", tile_pos])

func _preview_fishing_hut(tile_pos: Vector2):
	# Legacy function - kept for compatibility
	_show_town_center_preview(tile_pos)

func setup_modal(game_ref: Node, tilemap_ref: TileMapLayer, camera_ref: Camera2D, _ui_manager_ref: Node):
	# Keep this for compatibility but redirect to direct UI
	setup_direct_ui(game_ref, tilemap_ref, camera_ref)

func _show_current_step():
	if current_step >= generation_steps.size():
		DebugConfig.dprint("world_gen", ["WorldCreationModal: All steps completed"])
		return
		
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Showing step %d" % current_step])
	var step_data = generation_steps[current_step]
	
	# Update UI text
	if header_component:
		header_component.update_step(step_data["title"], step_data["description"])
	
	# Store current state before executing step (for rerolling)
	if current_step < step_states.size():
		# We're rerolling, restore previous state first
		world_data = step_states[current_step].duplicate(true)
	else:
		# Store state before new step
		step_states.append(world_data.duplicate(true))
	
	# Show/hide buttons based on step
	if footer_component:
		footer_component.reroll_button.visible = current_step > 0
		# Check specific steps for custom button layouts
		if current_step < generation_steps.size():
			var step_action = generation_steps[current_step]["action"]
			if step_action == "_step_race_select":
				footer_component.update_buttons(["Back", "Next"])
			elif step_action == "_step_choose_starting_tile":
				footer_component.update_buttons(["Back", "Next"])
			elif step_action == "_step_name_settlement":
				footer_component.update_buttons(["Back", "Begin Game"])
			else:
				footer_component.update_buttons_for_step(current_step, generation_steps.size())
	
	# Execute the step action
	if has_method(step_data["action"]):
		call(step_data["action"])
	else:
		push_error("WorldCreationModal: Step action not found: " + step_data["action"])

func _step_void():
	world_data.clear()
	_clear_and_draw_map()
	_center_camera_position_only()

func _step_water():
	world_data.clear()
	generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_position_only()

func _step_land():
	if world_data.is_empty():
		generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	generator._generate_continent(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_position_only()

func _step_ice():
	if world_data.is_empty():
		_step_land()
	generator._add_ice_caps(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_position_only()

func _step_mountains():
	if world_data.is_empty():
		_step_ice()
	generator._place_patches(
		generator.NUM_MOUNTAIN_PATCHES,
		generator.MOUNTAIN_PATCH_RADIUS_MIN, 
		generator.MOUNTAIN_PATCH_RADIUS_MAX,
		generator.MOUNTAIN_COORDS,
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()
	# No object placement here - terrain only
	_center_camera_position_only()

func _step_forests():
	if world_data.is_empty():
		_step_mountains()
	generator._place_patches(
		generator.NUM_FOREST_PATCHES,
		generator.FOREST_PATCH_RADIUS_MIN,
		generator.FOREST_PATCH_RADIUS_MAX, 
		generator.FOREST_COORDS,
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()
	# No object placement here - terrain only
	_center_camera_position_only()

func _step_plains():
	if world_data.is_empty():
		_step_forests()
	generator._place_patches(
		generator.NUM_DESERT_PATCHES,
		generator.DESERT_PATCH_RADIUS_MIN,
		generator.DESERT_PATCH_RADIUS_MAX,
		generator.GRASS_COORDS, 
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()
	_center_camera_position_only()

func _step_mountain_peaks():
	DebugConfig.dprint("world_gen", ["WorldCreation: Executing mountain peaks step"])
	# Place mountain objects on existing mountain terrain
	var parent_game_node = get_parent()
	if parent_game_node and parent_game_node.has_method("get_node"):
		var map_object_manager = parent_game_node.get_node("MapObjectManager")
		if map_object_manager and map_object_manager.has_method("place_mountains_only"):
			map_object_manager.place_mountains_only(world_data)
			DebugConfig.dprint("world_gen", ["WorldCreation: Mountain peaks placed"])
		else:
			DebugConfig.dprint("world_gen", ["WorldCreation: Map object manager not found or missing method"])
	_center_camera_position_only()

func _step_ancient_forests():
	DebugConfig.dprint("world_gen", ["WorldCreation: Executing ancient forests step"])
	# Place tree objects on existing forest terrain
	var parent_game_node = get_parent()
	if parent_game_node and parent_game_node.has_method("get_node"):
		var map_object_manager = parent_game_node.get_node("MapObjectManager")
		if map_object_manager and map_object_manager.has_method("place_trees_only"):
			map_object_manager.place_trees_only(world_data)
			DebugConfig.dprint("world_gen", ["WorldCreation: Ancient forests placed"])
		else:
			DebugConfig.dprint("world_gen", ["WorldCreation: Map object manager not found or missing method"])
	_center_camera_position_only()

func _step_fish():
	DebugConfig.dprint("world_gen", ["WorldCreation: Executing fish step"])
	# First, generate fish markers in world_data
	generator._place_fish(MAP_WIDTH, MAP_HEIGHT, world_data)
	
	# Then place fish objects in ocean tiles
	var parent_game_node = get_parent()
	if parent_game_node and parent_game_node.has_method("get_node"):
		var map_object_manager = parent_game_node.get_node("MapObjectManager")
		if map_object_manager and map_object_manager.has_method("place_fish"):
			map_object_manager.place_fish(world_data)
			DebugConfig.dprint("world_gen", ["WorldCreation: Fish placed"])
		else:
			DebugConfig.dprint("world_gen", ["WorldCreation: Map object manager not found or missing method"])
	_center_camera_position_only()

func _step_race_select():
	# Don't hide the UI, just update it like other steps
	# The race selection will be handled within the existing UI framework
	header_component.update_step("Choose Your Race", "Select your civilization and starting building")
	footer_component.update_buttons(["Back", "Next"])
	_show_race_selection_ui()
	DebugConfig.dprint("world_gen", ["WorldCreation: Race selection step activated"])

func _show_race_selection_ui():
	"""Show the race selection modal UI"""
	# Check if race selection UI already exists
	if has_meta("race_select_ui"):
		var existing_race_ui = get_meta("race_select_ui")
		if is_instance_valid(existing_race_ui):
			return  # Already showing
		remove_meta("race_select_ui")
	
	# Get UI layer reference
	var ui_layer = game_node.get_node("UI_Layer")
	if not ui_layer:
		push_error("WorldCreationModal: UI_Layer not found")
		return
	
	# Load and instantiate race selection modal
	var RaceSelectModal = preload("res://scripts/main/world_creation_race_select_modal.gd")
	var race_select_ui = RaceSelectModal.new()
	
	# Set up the race select modal (this also adds it to ui_layer)
	race_select_ui.setup_integrated(game_node, self, ui_layer)
	
	# Store reference for later cleanup
	set_meta("race_select_ui", race_select_ui)
	
	DebugConfig.dprint("world_gen", ["WorldCreation: Race selection UI shown"])

func _step_choose_starting_tile():
	# Clean up race selection UI if it exists
	if has_meta("race_select_ui"):
		var race_ui = get_meta("race_select_ui")
		if is_instance_valid(race_ui):
			race_ui.queue_free()
		remove_meta("race_select_ui")
	
	# Start interactive town center placement mode
	is_placing_town_center = true
	town_center_placed = false
	
	# Create initial preview at center
	var center_tile = Vector2(MAP_WIDTH / 2.0, MAP_HEIGHT / 2.0)
	_show_town_center_preview(center_tile)
	
	# Update header for this step
	header_component.update_step("Choose Starting Location", "Hover to preview placement. Click to place your town center. Use Reset to change position.")
	footer_component.update_buttons(["Back", "Reset"])
	DebugConfig.dprint("world_gen", ["WorldCreation: Town center placement mode active"])

func _load_town_center_names():
	"""Load town center names from assets/names/buildings/towncentre.txt"""
	var names_path = "res://assets/names/buildings/towncentre.txt"
	if FileAccess.file_exists(names_path):
		var file = FileAccess.open(names_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var lines = content.split("\n")
			for line in lines:
				var trimmed = line.strip_edges()
				if not trimmed.is_empty():
					town_names.append(trimmed)
			DebugConfig.dprint("world_gen", ["Game: Loaded %d town center names" % town_names.size()])
		else:
			push_error("Failed to open towncentre.txt")
	else:
		push_error("towncentre.txt not found at: " + names_path)

func _step_name_settlement():
	"""Display settlement naming UI"""
	DebugConfig.dprint("world_gen", ["WorldCreation: Showing settlement naming step"])
	
	# Disable town center placement mode
	is_placing_town_center = false
	
	# Clean up any other preview sprites but keep the placed town center sprite
	if has_meta("preview_sprite"):
		var preview_sprite = get_meta("preview_sprite")
		if is_instance_valid(preview_sprite):
			preview_sprite.queue_free()
		remove_meta("preview_sprite")
	
	# Keep town_center_preview_sprite visible - don't delete it
	
	# Pick a random town name if not already selected
	if selected_town_name.is_empty() and not town_names.is_empty():
		_pick_random_town_name()
	
	# Update header
	header_component.update_step("Name Your Settlement", "Choose a name for your new settlement")
	footer_component.update_buttons(["Back", "Begin Game"])
	
	# Show naming UI
	_show_settlement_naming_ui()

func _pick_random_town_name():
	"""Select a random town name from the loaded list"""
	if town_names.is_empty():
		selected_town_name = "New Settlement"
	else:
		var random_name = town_names[randi() % town_names.size()]
		# Capitalize each word in the name
		selected_town_name = random_name.to_upper()[0] + random_name.substr(1)
	DebugConfig.dprint("world_gen", ["WorldCreation: Selected town name: ", selected_town_name])

func _show_settlement_naming_ui():
	"""Create and show the settlement naming UI"""
	var ui_layer = game_node.get_node("UI_Layer")
	
	# Check if naming UI already exists, if so remove it
	if has_meta("naming_ui"):
		var naming_ui = get_meta("naming_ui")
		if is_instance_valid(naming_ui):
			naming_ui.queue_free()
		remove_meta("naming_ui")
	
	# Create a container for the naming UI
	var naming_container = Control.new()
	naming_container.name = "SettlementNamingContainer"
	naming_container.size = get_viewport().get_visible_rect().size
	naming_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let input pass through to buttons below
	var center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 20)
	
	# Center it on screen
	var center_panel = PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(400, 200)
	var screen_size = get_viewport().get_visible_rect().size
	center_panel.position = (screen_size - center_panel.custom_minimum_size) / 2
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 15)
	
	# Label
	var label = Label.new()
	label.text = "Enter settlement name:"
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(label)
	
	# Input field
	var input_field = LineEdit.new()
	input_field.text = selected_town_name
	input_field.custom_minimum_size = Vector2(300, 40)
	input_field.set_meta("settlement_name_input", true)
	inner_vbox.add_child(input_field)
	
	# Button container (Reroll and input in HBox)
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var reroll_button = Button.new()
	reroll_button.text = "Reroll"
	reroll_button.custom_minimum_size = Vector2(100, 40)
	reroll_button.pressed.connect(_on_reroll_settlement_name)
	button_hbox.add_child(reroll_button)
	
	inner_vbox.add_child(button_hbox)
	
	center_panel.add_child(inner_vbox)
	naming_container.add_child(center_panel)
	
	ui_layer.add_child(naming_container)
	set_meta("naming_ui", naming_container)
	set_meta("settlement_name_input", input_field)
	
	DebugConfig.dprint("world_gen", ["WorldCreation: Settlement naming UI created"])

func _on_reroll_settlement_name():
	"""Pick a new random town name and update the input field"""
	_pick_random_town_name()
	
	# Update the input field if it exists
	if has_meta("settlement_name_input"):
		var input_field = get_meta("settlement_name_input")
		if is_instance_valid(input_field):
			input_field.text = selected_town_name
	
	DebugConfig.dprint("world_gen", ["WorldCreation: Rerolled settlement name to: ", selected_town_name])

func _center_camera_position_only():
	"""Center camera position on map without changing zoom level (preserves user zoom)"""
	if camera and tilemap_layer:
		# Calculate the center of the map in world coordinates
		var map_center_x = MAP_WIDTH / 2.0
		var map_center_y = MAP_HEIGHT / 2.0
		var world_center = tilemap_layer.map_to_local(Vector2i(int(map_center_x), int(map_center_y)))
		
		camera.position = world_center
		DebugConfig.dprint("world_gen", ["WorldCreation: Camera centered at: ", world_center])

func _center_camera_on_map():
	"""Full camera reset: center position AND reset zoom to default"""
	if camera and tilemap_layer:
		# Calculate the center of the map in world coordinates
		var map_center_x = MAP_WIDTH / 2.0
		var map_center_y = MAP_HEIGHT / 2.0
		var world_center = tilemap_layer.map_to_local(Vector2i(int(map_center_x), int(map_center_y)))
		
		camera.position = world_center
		camera.zoom = Vector2(0.6, 0.6)  # Zoom out to see more of the map
		DebugConfig.dprint("world_gen", ["WorldCreation: Camera reset to: ", world_center, " with zoom: ", camera.zoom])

func _clear_and_draw_map():
	if not is_instance_valid(tilemap_layer):
		return
		
	tilemap_layer.clear()
	
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])

func _on_back_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreation: Going back to main menu"])
	cleanup_ui()
	game_node._cancel_world_creation()

func _on_reset_camera_pressed():
	# Check if we're in town center placement mode
	if is_placing_town_center:
		_reset_town_center_placement()
	else:
		DebugConfig.dprint("world_gen", ["WorldCreation: Resetting camera view"])
		_center_camera_on_map()

func _on_reroll_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreation: Rerolling step %d" % current_step])
	
	# Special handling for object placement steps
	if current_step < generation_steps.size():
		var step_data = generation_steps[current_step]
		if step_data["action"] == "_step_mountain_peaks":
			# Clear only mountain objects before rerolling
			var parent_game_node = get_parent()
			if parent_game_node and parent_game_node.has_method("get_node"):
				var map_object_manager = parent_game_node.get_node("MapObjectManager")
				if map_object_manager and map_object_manager.has_method("clear_mountains_only"):
					map_object_manager.clear_mountains_only()
		elif step_data["action"] == "_step_ancient_forests":
			# Clear only tree objects before rerolling
			var parent_game_node = get_parent()
			if parent_game_node and parent_game_node.has_method("get_node"):
				var map_object_manager = parent_game_node.get_node("MapObjectManager")
				if map_object_manager and map_object_manager.has_method("clear_trees_only"):
					map_object_manager.clear_trees_only()
	
	_show_current_step()

func _on_continue_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Continue/Next button pressed - current step: %d" % current_step])
	
	# Special handling for race selection step
	var race_select_index = 10  # Race selection is at index 10
	var _tile_select_index = 11  # Tile selection is at index 11
	var _naming_index = 12  # Naming is at index 12
	
	if current_step == race_select_index:
		# Race selection finishing - need to finish the UI and advance
		if has_meta("race_select_ui"):
			var race_ui = get_meta("race_select_ui")
			if is_instance_valid(race_ui):
				race_ui._finish_race_selection_internal()
				# Manually advance the step since the race UI doesn't do it
				current_step += 1
				if current_step < step_states.size():
					step_states.resize(current_step)
				DebugConfig.dprint("world_gen", ["WorldCreationModal: Advanced to step: %d" % current_step])
				_show_current_step()
				return
	
	# Normal step progression
	current_step += 1
	if current_step < step_states.size():
		step_states.resize(current_step)
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Advanced to step: %d" % current_step])
	_show_current_step()

func _on_start_game_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Start game button pressed - step: %d" % current_step])
	
	var naming_index = 12  # Naming is at index 12
	
	# If we're on the naming step, capture the name and finish
	if current_step == naming_index:
		# Get the settlement name from the input field
		if has_meta("settlement_name_input"):
			var input_field = get_meta("settlement_name_input")
			if is_instance_valid(input_field):
				selected_town_name = input_field.text
		
		# Store the selected town name in world data
		if not world_data.has("player_data"):
			world_data["player_data"] = {}
		world_data["player_data"]["settlement_name"] = selected_town_name
		
		DebugConfig.dprint("world_gen", ["WorldCreation: Settlement named: ", selected_town_name])
		
		cleanup_ui()
		game_node._finish_world_creation(world_data)
		return
	
	# For other steps, just finish (shouldn't normally happen)
	cleanup_ui()
	game_node._finish_world_creation(world_data)

func _unhandled_input(event: InputEvent):
	"""Handle input during town center placement"""
	if not is_placing_town_center:
		return
	
	if event is InputEventMouseMotion:
		_update_town_center_preview()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_place_town_center()

func _update_town_center_preview():
	"""Update preview sprite position based on mouse hover"""
	if not town_center_preview_sprite or not is_instance_valid(town_center_preview_sprite):
		return
	
	# Convert screen position to world position
	var world_pos = camera.get_global_mouse_position()
	# Convert to tile coordinates
	var tile_coords = tilemap_layer.local_to_map(world_pos)
	
	# Position preview at the midpoint between the two tiles above the hovered tile and the hovered tile
	# This creates an upside-down triangle meeting point
	var tile_above_left = tilemap_layer.map_to_local(Vector2i(int(tile_coords.x) - 1, int(tile_coords.y) - 1))
	var tile_above_right = tilemap_layer.map_to_local(Vector2i(int(tile_coords.x), int(tile_coords.y) - 1))
	
	# Calculate the midpoint between the two tiles above
	var midpoint_above = (tile_above_left + tile_above_right) / 2.0
	
	# Position sprite at this upside-down triangle meeting point
	town_center_preview_sprite.position = midpoint_above
	
	# Check if placement is valid and update tint
	var can_place = _can_place_town_center_at_tile(tile_coords)
	if can_place:
		town_center_preview_sprite.modulate = Color(0.7, 1.0, 0.7, 0.7)  # Green tint
	else:
		town_center_preview_sprite.modulate = Color(1.0, 0.7, 0.7, 0.7)  # Red tint

func _can_place_town_center_at_tile(tile_coords: Vector2i) -> bool:
	"""Check if town center can be placed at this tile"""
	# Check if tile is within map bounds
	var used_rect = tilemap_layer.get_used_rect()
	if not used_rect.has_point(tile_coords):
		return false
	
	# Could add more validation here (terrain type, etc.)
	return true

func _place_town_center():
	"""Place the town center at the clicked location"""
	# Convert screen position to tile coordinates
	var world_pos = camera.get_global_mouse_position()
	var tile_coords = tilemap_layer.local_to_map(world_pos)
	
	if _can_place_town_center_at_tile(tile_coords):
		# Store the placement location
		world_data["starting_tile"] = Vector2(tile_coords.x, tile_coords.y)
		town_center_placed = true
		
		# Make preview sprite fully opaque and keep it visible on the map
		if town_center_preview_sprite and is_instance_valid(town_center_preview_sprite):
			town_center_preview_sprite.modulate = Color(1, 1, 1, 1.0)  # Fully opaque
		
		is_placing_town_center = false
		
		# Update UI to continue
		header_component.update_step("Choose Starting Location", "Town center placed! Click Next to continue.")
		footer_component.update_buttons(["Back", "Next"])
		
		DebugConfig.dprint("world_gen", ["WorldCreation: Town center placed at: ", world_data["starting_tile"]])
	else:
		DebugConfig.dprint("world_gen", ["Cannot place town center at this location"])

func _reset_town_center_placement():
	"""Reset town center placement back to preview mode"""
	if is_placing_town_center and town_center_preview_sprite and is_instance_valid(town_center_preview_sprite):
		town_center_preview_sprite.modulate = Color(1, 1, 1, 0.7)  # Reset to neutral color
		DebugConfig.dprint("world_gen", ["WorldCreation: Town center placement reset"])

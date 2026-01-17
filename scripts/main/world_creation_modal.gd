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
		"description": "Great peaks rise from the earth,\ntowering monuments of stone and snow.",
		"action": "_step_mountains"
	},
	{
		"title": "Let there be Forests",
		"description": "Vast woodlands spread across the land,\nbringing life and shelter to the world.",
		"action": "_step_forests"
	},
	{
		"title": "Let there be Plains",
		"description": "Rolling grasslands complete the world,\nperfect for civilization to take root.",
		"action": "_step_plains"
	},
	{
		"title": "Choose Your People",
		"description": "Select the race that will inhabit this world\nand choose their starting settlement.",
		"action": "_step_race_select"
	}
]

func setup_direct_ui(game_ref: Node, tilemap_ref: TileMapLayer, camera_ref: Camera2D):
	game_node = game_ref
	tilemap_layer = tilemap_ref
	camera = camera_ref
	
	print("WorldCreationModal: Setting up direct UI control")
	
	# Create our own UI elements directly in the UI_Layer
	_create_world_creation_ui()
	
	# Initialize
	rng.randomize()
	generator = WorldGenerator.new()
	current_step = 0
	step_states.clear()
	
	# Start first step
	_show_current_step()
	print("WorldCreationModal: Direct UI setup complete")

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
	
	print("WorldCreationModal: Header/Footer components created and connected")

func cleanup_ui():
	# Clean up our UI elements when done
	var ui_layer = game_node.get_node("UI_Layer")
	
	# Clean up race selection UI if it exists
	if has_meta("race_select_ui"):
		var race_ui = get_meta("race_select_ui")
		if is_instance_valid(race_ui):
			race_ui.queue_free()
		remove_meta("race_select_ui")
	
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
	
	# Show normal UI elements again
	game_node.get_node("UI_Layer/MenuButtonContainer").show()
	game_node.get_node("UI_Layer/TurnControlsContainer").show()

func _on_tile_selected(tile_pos: Vector2):
	# Store starting tile position
	world_data["starting_tile"] = tile_pos
	print("Selected starting tile at: ", tile_pos)
	# Preview fishing hut at selected position
	_preview_fishing_hut(tile_pos)

func _preview_fishing_hut(tile_pos: Vector2):
	# Load and place the town center sprite as a preview (using town center for starting building)
	var town_center_texture = preload("res://assets/buildings/human_towncentre-export.png")
	
	# Create a sprite node for the preview
	var preview_sprite = Sprite2D.new()
	preview_sprite.name = "TownCenterPreview"
	preview_sprite.texture = town_center_texture
	
	# Position it at the center tile
	if tilemap_layer:
		var world_pos = tilemap_layer.map_to_local(Vector2i(tile_pos.x, tile_pos.y))
		preview_sprite.position = world_pos
		preview_sprite.z_index = 10  # Make sure it's above the tilemap
		
		# Add to the tilemap's parent so it's in the right layer
		tilemap_layer.get_parent().add_child(preview_sprite)
		
		# Store reference for cleanup
		set_meta("preview_sprite", preview_sprite)
		
	print("Town center preview placed at: ", tile_pos)

func setup_modal(game_ref: Node, tilemap_ref: TileMapLayer, camera_ref: Camera2D, ui_manager_ref: Node):
	# Keep this for compatibility but redirect to direct UI
	setup_direct_ui(game_ref, tilemap_ref, camera_ref)

func _show_current_step():
	if current_step >= generation_steps.size():
		print("WorldCreationModal: All steps completed")
		return
		
	print("WorldCreationModal: Showing step %d" % current_step)
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
		footer_component.update_buttons_for_step(current_step, generation_steps.size())
	
	# Execute the step action
	if has_method(step_data["action"]):
		call(step_data["action"])
	else:
		push_error("WorldCreationModal: Step action not found: " + step_data["action"])

func _step_void():
	world_data.clear()
	_clear_and_draw_map()
	_center_camera_on_map()

func _step_water():
	world_data.clear()
	generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_on_map()

func _step_land():
	if world_data.is_empty():
		generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	generator._generate_continent(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_on_map()

func _step_ice():
	if world_data.is_empty():
		_step_land()
	generator._add_ice_caps(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()
	_center_camera_on_map()

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
	_center_camera_on_map()

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
	_center_camera_on_map()

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
	_center_camera_on_map()

func _step_race_select():
	# Don't hide the UI, just update it like other steps
	# The race selection will be handled within the existing UI framework
	header_component.update_step("Choose Your Race", "Select your civilization and starting building")
	footer_component.update_buttons(["Back", "Next"])
	_show_race_selection_ui()
	print("WorldCreation: Race selection step activated")

func _step_choose_starting_tile():
	header_component.update_step("Choose Starting Location", "Your settlement will be built in the center of the world")
	footer_component.update_buttons(["Back", "Start Game"])
	_show_tile_selection_preview()

func _show_race_selection_ui():
	# Create race selection UI in the middle area (between header and footer)
	var ui_layer = game_node.get_node("UI_Layer")
	
	# Create race selection container
	var RaceSelectUI = preload("res://scripts/main/world_creation_race_select_modal.gd")
	var race_select_ui = RaceSelectUI.new()
	race_select_ui.setup_integrated(game_node, self, ui_layer)
	
	# Store reference so we can clean it up later
	if not has_meta("race_select_ui"):
		set_meta("race_select_ui", race_select_ui)

func _show_tile_selection_preview():
	# Clean up any existing UI
	if has_meta("race_select_ui"):
		var race_ui = get_meta("race_select_ui")
		if is_instance_valid(race_ui):
			race_ui.queue_free()
		remove_meta("race_select_ui")
	
	# Automatically select center tile
	var center_tile = Vector2(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	world_data["starting_tile"] = center_tile
	print("Auto-selected center tile: ", center_tile)
	
	# Show fishing hut preview at center
	_preview_fishing_hut(center_tile)

func _center_camera_on_map():
	if camera and tilemap_layer:
		# Calculate the center of the map in world coordinates
		var map_center_x = MAP_WIDTH / 2.0
		var map_center_y = MAP_HEIGHT / 2.0
		var world_center = tilemap_layer.map_to_local(Vector2i(map_center_x, map_center_y))
		
		camera.position = world_center
		camera.zoom = Vector2(0.6, 0.6)  # Zoom out to see more of the map
		print("WorldCreation: Camera centered at: ", world_center)

func _clear_and_draw_map():
	if not is_instance_valid(tilemap_layer):
		return
		
	tilemap_layer.clear()
	
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])

func _on_back_pressed():
	print("WorldCreation: Going back to main menu")
	cleanup_ui()
	game_node._cancel_world_creation()

func _on_reset_camera_pressed():
	print("WorldCreation: Resetting camera view")
	_center_camera_on_map()

func _on_reroll_pressed():
	print("WorldCreation: Rerolling step %d" % current_step)
	_show_current_step()

func _on_continue_pressed():
	print("WorldCreationModal: Continue/Next button pressed - current step: %d" % current_step)
	
	# Special handling for race selection step
	if current_step == generation_steps.size() - 1:  # Race selection step
		if has_meta("race_select_ui"):
			var race_ui = get_meta("race_select_ui")
			if is_instance_valid(race_ui):
				race_ui._finish_race_selection()
				return
	
	# Normal step progression
	current_step += 1
	if current_step < step_states.size():
		step_states.resize(current_step)
	print("WorldCreationModal: Advanced to step: %d" % current_step)
	_show_current_step()

func _on_start_game_pressed():
	print("WorldCreationModal: Start game button pressed")
	
	# Check if we need to advance to tile selection or finish
	if current_step == generation_steps.size() - 1:  # Race selection step
		# If we're in race selection mode, advance to tile selection
		if has_meta("race_select_ui"):
			var race_ui = get_meta("race_select_ui")
			if is_instance_valid(race_ui):
				race_ui._finish_race_selection()
				return
	
	# For tile selection step, just finish (tile is auto-selected)
	cleanup_ui()
	game_node._finish_world_creation(world_data)
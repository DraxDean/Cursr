# scripts/main/world_creation_modal.gd
extends Node

# Constants
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# World generation
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")
var generator: WorldGenerator
var world_data: Dictionary = {}
var step_states: Array[Dictionary] = []          # world_data BEFORE each step ran (reroll baseline)
var step_after_states: Array[Dictionary] = []    # world_data AFTER each step ran (Back/Continue restore this, unchanged, unless Reroll/Regenerate is pressed)
var current_step: int = 0
var rng = RandomNumberGenerator.new()

# Steps whose action actually mutates world_data via RNG — these are the ones that must NOT
# reroll themselves just from navigating Back/Continue; only Reroll/Regenerate should.
const REROLLABLE_STEP_ACTIONS := [
	"_step_void", "_step_water", "_step_land", "_step_mountains",
	"_step_forests", "_step_plains", "_step_fish"
]

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
		"description": "There was nothing but darkness and void.",
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
		"title": "Let there be Mountains",
		"description": "Great chains of peaks rise from the earth,\ntowering monuments of stone and snow.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_mountains"
	},
	{
		"title": "Let there be Forests",
		"description": "Vast woodlands take root across the land, ancient trees rising within\nthem to bring life and shelter to the world.\nPress Continue when satisfied or Reroll to try again.",
		"action": "_step_forests"
	},
	{
		"title": "Let there be Plains",
		"description": "Rolling grasslands complete the world,\nperfect for civilization to take root.",
		"action": "_step_plains"
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

# Variables for difficulty selection (naming step)
var selected_difficulty: String = "captain"
var difficulty_buttons: Array[Button] = []

# Land step (stage 3) slider values — kept in [0,1], 0.5 = default/middle. Persist across
# reroll/regenerate within a session so revisiting the step keeps whatever the player set.
var land_landmass_value: float = 0.5
var land_coast_noise_value: float = 0.5

# Mountains step slider values. num_ranges is an integer count (0-6); the rest are [0,1]
# fractions, 0.5 = default/middle. Same persist-for-the-session behavior as the land sliders.
var mountain_num_ranges: int = 3
var mountain_range_size: float = 0.5
var mountain_peak_sharpness: float = 0.5
var mountain_density: float = 0.5

# Forest step slider values — same [0,1]/0.5-default convention as the land/mountain sliders.
var forest_size_value: float = 0.5
var forest_tendril_spread: float = 0.5

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
	step_after_states.clear()
	land_landmass_value = 0.5
	land_coast_noise_value = 0.5
	mountain_num_ranges = 3
	mountain_range_size = 0.5
	mountain_peak_sharpness = 0.5
	mountain_density = 0.5
	forest_size_value = 0.5
	forest_tendril_spread = 0.5
	
	# Zoom all the way out so the whole map is visible from the water stage onward —
	# replaces the old "Reset Camera" button, which is gone now.
	if is_instance_valid(camera) and is_instance_valid(game_node) and is_instance_valid(game_node.camera_controller):
		var min_zoom: float = game_node.camera_controller.min_zoom
		camera.zoom = Vector2(min_zoom, min_zoom)
	
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
	footer_component.quick_start_pressed.connect(_on_quick_start_pressed)
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
	
	# Clean up land sliders modal if it exists
	_hide_land_sliders_modal()
	
	# Clean up mountains sliders modal if it exists
	_hide_mountains_sliders_modal()
	
	# Clean up forest sliders modal if it exists
	_hide_forest_sliders_modal()
	
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

func _show_current_step(force_regenerate: bool = false):
	if current_step >= generation_steps.size():
		DebugConfig.dprint("world_gen", ["WorldCreationModal: All steps completed"])
		return
		
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Showing step %d" % current_step])
	var step_data = generation_steps[current_step]
	
	# Tear down any step-specific overlay UI that doesn't belong to the step we're about to
	# show. Needed now that Back revisits earlier phases instead of always cancelling out to
	# the main menu, so leftover UI from a later step can't stay on screen after going back.
	var step_action: String = step_data["action"]
	if step_action != "_step_race_select":
		_hide_race_select_ui()
	if step_action != "_step_name_settlement":
		_hide_naming_ui()
	if step_action != "_step_land":
		_hide_land_sliders_modal()
	if step_action != "_step_mountains":
		_hide_mountains_sliders_modal()
	if step_action != "_step_forests":
		_hide_forest_sliders_modal()
	if step_action != "_step_choose_starting_tile":
		is_placing_town_center = false
	
	# Update UI text
	if header_component:
		header_component.update_step(step_data["title"], step_data["description"])
	
	# Store current state before executing step (used as the reroll baseline)
	if current_step < step_states.size():
		world_data = step_states[current_step].duplicate(true)
	else:
		step_states.append(world_data.duplicate(true))
	
	# Show/hide buttons based on step
	if footer_component:
		footer_component.reroll_button.visible = current_step > 0
		footer_component.quick_start_button.visible = current_step == 0
		# Check specific steps for custom button layouts
		if step_action == "_step_race_select":
			footer_component.update_buttons(["Back", "Next"])
		elif step_action == "_step_choose_starting_tile":
			footer_component.update_buttons(["Back", "Next"])
		elif step_action == "_step_name_settlement":
			footer_component.update_buttons(["Back", "Begin Game"])
		else:
			footer_component.update_buttons_for_step(current_step, generation_steps.size())
	
	# Revisiting an already-completed generative step (via Back, or Continuing forward again)
	# must NOT reroll it — only an explicit Reroll/Regenerate should change its content.
	var is_revisit_without_reroll: bool = (
		not force_regenerate
		and step_action in REROLLABLE_STEP_ACTIONS
		and current_step < step_after_states.size()
	)
	
	if is_revisit_without_reroll:
		world_data = step_after_states[current_step].duplicate(true)
		_redraw_current_step_view(step_action)
	elif has_method(step_action):
		call(step_action)
		if step_action in REROLLABLE_STEP_ACTIONS:
			_commit_step_regeneration(current_step)
	else:
		push_error("WorldCreationModal: Step action not found: " + step_action)

func _redraw_current_step_view(step_action: String):
	"""Redraw the map/camera (and re-show any slider modal) for a step whose world_data we
	just restored verbatim, without re-running its generation logic."""
	_clear_and_draw_map()
	_center_camera_position_only()
	match step_action:
		"_step_land":
			_show_land_sliders_modal()
		"_step_mountains":
			_show_mountains_sliders_modal()
		"_step_forests":
			_show_forest_sliders_modal()

func _commit_step_regeneration(step_index: int):
	"""Record freshly (re)generated world_data as this step's canonical result, and drop any
	later steps' cached results since they were built on the now-stale previous data."""
	if step_index < step_after_states.size():
		step_after_states[step_index] = world_data.duplicate(true)
	else:
		step_after_states.append(world_data.duplicate(true))
	if step_after_states.size() > step_index + 1:
		step_after_states.resize(step_index + 1)
	if step_states.size() > step_index + 1:
		step_states.resize(step_index + 1)


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
	_regenerate_land_terrain()
	_show_land_sliders_modal()

func _regenerate_land_terrain():
	"""(Re)draw the ocean+continent from scratch using the current landmass/coast noise
	slider values. Always resets to base ocean first so shrinking the landmass on a
	regenerate doesn't leave stray land tiles behind from a previous, larger pass."""
	generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	generator._generate_continent(MAP_WIDTH, MAP_HEIGHT, world_data, land_landmass_value, land_coast_noise_value)
	_clear_and_draw_map()
	_center_camera_position_only()

func regenerate_land_from_sliders(landmass: float, coast_noise: float):
	"""Called by the land sliders modal's Regenerate button."""
	land_landmass_value = landmass
	land_coast_noise_value = coast_noise
	_regenerate_land_terrain()
	_commit_step_regeneration(current_step)

func _show_land_sliders_modal():
	if has_meta("land_sliders_ui"):
		var existing = get_meta("land_sliders_ui")
		if is_instance_valid(existing):
			return  # Already showing
		remove_meta("land_sliders_ui")
	var ui_layer = game_node.get_node("UI_Layer")
	var LandSlidersModal = preload("res://scripts/main/world_creation_land_sliders_modal.gd")
	var sliders_ui = LandSlidersModal.new()
	sliders_ui.setup_integrated(self, ui_layer)
	set_meta("land_sliders_ui", sliders_ui)

func _hide_land_sliders_modal():
	if has_meta("land_sliders_ui"):
		var ui = get_meta("land_sliders_ui")
		if is_instance_valid(ui):
			ui.queue_free()
		remove_meta("land_sliders_ui")

func _hide_race_select_ui():
	if has_meta("race_select_ui"):
		var ui = get_meta("race_select_ui")
		if is_instance_valid(ui):
			ui.queue_free()
		remove_meta("race_select_ui")

func _hide_naming_ui():
	if has_meta("naming_ui"):
		var ui = get_meta("naming_ui")
		if is_instance_valid(ui):
			ui.queue_free()
		remove_meta("naming_ui")
	if has_meta("settlement_name_input"):
		remove_meta("settlement_name_input")

func _step_mountains():
	if world_data.is_empty():
		_step_land()
	_regenerate_mountains()
	_show_mountains_sliders_modal()

func _regenerate_mountains():
	"""Clear any existing mountain terrain+objects, then regenerate both from the current
	slider values (chains/ranges for terrain, peak-weighted density for objects)."""
	_clear_mountain_terrain()
	generator._generate_mountain_ranges(MAP_WIDTH, MAP_HEIGHT, world_data, mountain_num_ranges, mountain_range_size, mountain_peak_sharpness)
	_clear_and_draw_map()
	_center_camera_position_only()
	var parent_game_node = get_parent()
	if parent_game_node and parent_game_node.has_method("get_node"):
		var map_object_manager = parent_game_node.get_node("MapObjectManager")
		if map_object_manager:
			if map_object_manager.has_method("clear_mountains_only"):
				map_object_manager.clear_mountains_only()
			if map_object_manager.has_method("place_mountains_weighted"):
				map_object_manager.place_mountains_weighted(world_data, mountain_density)

func _clear_mountain_terrain():
	"""Revert any existing mountain tiles back to plain land before regenerating ranges,
	so shrinking the range count/size on a regenerate doesn't leave stray peaks behind."""
	for coords in world_data.keys():
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.get("atlas_coords") == generator.MOUNTAIN_COORDS:
			world_data[coords] = {"source_id": generator.SOURCE_ID, "atlas_coords": generator.DESERT_COORDS}

func regenerate_mountains_from_sliders(num_ranges: int, range_size: float, peak_sharpness: float, density: float):
	"""Called by the mountains sliders modal's Regenerate button."""
	mountain_num_ranges = num_ranges
	mountain_range_size = range_size
	mountain_peak_sharpness = peak_sharpness
	mountain_density = density
	_regenerate_mountains()
	_commit_step_regeneration(current_step)

func _show_mountains_sliders_modal():
	if has_meta("mountains_sliders_ui"):
		var existing = get_meta("mountains_sliders_ui")
		if is_instance_valid(existing):
			return  # Already showing
		remove_meta("mountains_sliders_ui")
	var ui_layer = game_node.get_node("UI_Layer")
	var MountainsSlidersModal = preload("res://scripts/main/world_creation_mountains_sliders_modal.gd")
	var sliders_ui = MountainsSlidersModal.new()
	sliders_ui.setup_integrated(self, ui_layer)
	set_meta("mountains_sliders_ui", sliders_ui)

func _hide_mountains_sliders_modal():
	if has_meta("mountains_sliders_ui"):
		var ui = get_meta("mountains_sliders_ui")
		if is_instance_valid(ui):
			ui.queue_free()
		remove_meta("mountains_sliders_ui")

func _step_forests():
	if world_data.is_empty():
		_step_mountains()
	_regenerate_forest_terrain()
	_show_forest_sliders_modal()

func _regenerate_forest_terrain():
	"""Clear any existing forest terrain+objects, then regenerate both from the current
	slider values (tendril clusters for terrain, then tree objects placed on top). Always
	clears existing forest tiles first so shrinking the forest on a regenerate doesn't leave
	stray patches (or orphaned tree sprites) behind from a previous, larger pass."""
	_clear_forest_terrain()
	generator._generate_forest_clusters(MAP_WIDTH, MAP_HEIGHT, world_data, forest_size_value, forest_tendril_spread)
	_clear_and_draw_map()
	_center_camera_position_only()
	var parent_game_node = get_parent()
	if parent_game_node and parent_game_node.has_method("get_node"):
		var map_object_manager = parent_game_node.get_node("MapObjectManager")
		if map_object_manager:
			if map_object_manager.has_method("clear_trees_only"):
				map_object_manager.clear_trees_only()
			if map_object_manager.has_method("place_trees_only"):
				map_object_manager.place_trees_only(world_data)

func _clear_forest_terrain():
	"""Revert any existing forest tiles back to plain land before regenerating clusters."""
	for coords in world_data.keys():
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.get("atlas_coords") == generator.FOREST_COORDS:
			world_data[coords] = {"source_id": generator.SOURCE_ID, "atlas_coords": generator.DESERT_COORDS}

func regenerate_forest_from_sliders(size_value: float, tendril_spread: float):
	"""Called by the forest sliders modal's Regenerate button."""
	forest_size_value = size_value
	forest_tendril_spread = tendril_spread
	_regenerate_forest_terrain()
	_commit_step_regeneration(current_step)

func _show_forest_sliders_modal():
	if has_meta("forest_sliders_ui"):
		var existing = get_meta("forest_sliders_ui")
		if is_instance_valid(existing):
			return  # Already showing
		remove_meta("forest_sliders_ui")
	var ui_layer = game_node.get_node("UI_Layer")
	var ForestSlidersModal = preload("res://scripts/main/world_creation_forest_sliders_modal.gd")
	var sliders_ui = ForestSlidersModal.new()
	sliders_ui.setup_integrated(self, ui_layer)
	set_meta("forest_sliders_ui", sliders_ui)

func _hide_forest_sliders_modal():
	if has_meta("forest_sliders_ui"):
		var ui = get_meta("forest_sliders_ui")
		if is_instance_valid(ui):
			ui.queue_free()
		remove_meta("forest_sliders_ui")

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
	center_panel.custom_minimum_size = Vector2(460, 300)
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
	
	# Difficulty selector
	var diff_label = Label.new()
	diff_label.text = "Difficulty:"
	diff_label.add_theme_font_size_override("font_size", 16)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(diff_label)
	
	var diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_buttons.clear()
	var diff_group := ButtonGroup.new()
	for level in game_node.DIFFICULTY_LEVELS:
		var diff_btn = Button.new()
		diff_btn.text = level["label"]
		diff_btn.custom_minimum_size = Vector2(80, 34)
		diff_btn.toggle_mode = true
		diff_btn.button_group = diff_group
		diff_btn.set_meta("difficulty_id", level["id"])
		diff_btn.button_pressed = (level["id"] == selected_difficulty)
		diff_btn.modulate = Color(1.2, 1.2, 0.8) if level["id"] == selected_difficulty else Color.WHITE
		diff_btn.pressed.connect(_on_difficulty_selected.bind(level["id"]))
		diff_row.add_child(diff_btn)
		difficulty_buttons.append(diff_btn)
	inner_vbox.add_child(diff_row)
	
	var diff_hint = Label.new()
	diff_hint.text = "Controls how often marauder raids appear"
	diff_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	diff_hint.add_theme_font_size_override("font_size", 11)
	diff_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(diff_hint)
	
	center_panel.add_child(inner_vbox)
	naming_container.add_child(center_panel)
	
	ui_layer.add_child(naming_container)
	set_meta("naming_ui", naming_container)
	set_meta("settlement_name_input", input_field)
	
	DebugConfig.dprint("world_gen", ["WorldCreation: Settlement naming UI created"])

func _on_difficulty_selected(difficulty_id: String):
	"""Update the selected difficulty and refresh button highlighting"""
	selected_difficulty = difficulty_id
	for btn in difficulty_buttons:
		if is_instance_valid(btn):
			btn.modulate = Color(1.2, 1.2, 0.8) if btn.get_meta("difficulty_id", "") == difficulty_id else Color.WHITE
	DebugConfig.dprint("world_gen", ["WorldCreation: Difficulty selected: ", selected_difficulty])

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

func _clear_and_draw_map():
	if not is_instance_valid(tilemap_layer):
		return
		
	tilemap_layer.clear()
	
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])

func _on_back_pressed():
	# Step 0 has nowhere earlier to go back to, so that's the only place Back still cancels
	# out to the main menu — every later step just steps back one phase.
	if current_step <= 0:
		DebugConfig.dprint("world_gen", ["WorldCreation: Going back to main menu"])
		cleanup_ui()
		game_node._cancel_world_creation()
		return
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Back pressed - stepping back from %d" % current_step])
	current_step -= 1
	_show_current_step()

func _on_reset_camera_pressed():
	# Only meaningful during town-center placement now — the "Reset Camera" behavior is gone
	# since the camera stays fully zoomed out for the whole of world creation.
	if is_placing_town_center:
		_reset_town_center_placement()

func _on_quick_start_pressed():
	"""Skip the step-by-step genesis narration and jump straight to race selection."""
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Quick Start pressed - skipping to race selection"])
	var race_select_index = 7  # Race selection is at index 7
	while current_step < race_select_index:
		current_step += 1
		_show_current_step()

func _on_reroll_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreation: Rerolling step %d" % current_step])
	# Mountains/forests clear+regenerate both terrain and objects themselves as part of their
	# _regenerate_* functions, so no per-step special casing is needed here anymore.
	_show_current_step(true)  # force_regenerate — this is the one action that's actually allowed to reroll

func _on_continue_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Continue/Next button pressed - current step: %d" % current_step])
	
	# Special handling for race selection step
	var race_select_index = 7  # Race selection is at index 7
	var _tile_select_index = 8  # Tile selection is at index 8
	var _naming_index = 9  # Naming is at index 9
	
	if current_step == race_select_index:
		# Race selection finishing - need to finish the UI and advance
		if has_meta("race_select_ui"):
			var race_ui = get_meta("race_select_ui")
			if is_instance_valid(race_ui):
				race_ui._finish_race_selection_internal()
				# Manually advance the step since the race UI doesn't do it
				current_step += 1
				DebugConfig.dprint("world_gen", ["WorldCreationModal: Advanced to step: %d" % current_step])
				_show_current_step()
				return
	
	# Normal step progression
	current_step += 1
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Advanced to step: %d" % current_step])
	_show_current_step()

func _on_start_game_pressed():
	DebugConfig.dprint("world_gen", ["WorldCreationModal: Start game button pressed - step: %d" % current_step])
	
	var naming_index = 9  # Naming is at index 9
	
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
		world_data["player_data"]["difficulty"] = selected_difficulty
		
		DebugConfig.dprint("world_gen", ["WorldCreation: Settlement named: ", selected_town_name, " — Difficulty: ", selected_difficulty])
		
		cleanup_ui()
		game_node._finish_world_creation(world_data)
		return
	
	# For other steps, just finish (shouldn't normally happen)
	cleanup_ui()
	game_node._finish_world_creation(world_data)

func _unhandled_input(event: InputEvent):
	# Left/Right step between genesis phases, same as clicking the arrow buttons — skipped
	# while a text field (e.g. the settlement name input) has focus so cursor movement still
	# works there.
	var focus_owner = get_viewport().gui_get_focus_owner() if get_viewport() else null
	var is_typing: bool = focus_owner is LineEdit or focus_owner is TextEdit
	if not is_typing:
		if event.is_action_pressed("ui_left"):
			if is_instance_valid(footer_component) and footer_component.back_button.visible:
				_on_back_pressed()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("ui_right"):
			if is_instance_valid(footer_component):
				if footer_component.continue_button.visible:
					_on_continue_pressed()
					get_viewport().set_input_as_handled()
					return
				elif footer_component.start_game_button.visible:
					_on_start_game_pressed()
					get_viewport().set_input_as_handled()
					return

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

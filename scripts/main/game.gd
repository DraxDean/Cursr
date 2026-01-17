# scripts/main/game.gd - Orchestrator (with Debug Prints)
extends Node

# --- Constants ---
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# --- Export Variables for Scenes ---
@export var tree_scene: PackedScene
@export var mountain_scene: PackedScene

# --- Node References ---
@onready var tilemap_layer: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UI_Layer
@onready var map_objects_holder: Node2D = $MapObjects
# Manager Nodes
@onready var camera_controller: Node = $CameraController
@onready var ui_manager: Node = $UIManager
@onready var map_object_manager: Node = $MapObjectManager
@onready var turn_manager: Node = $TurnManager

# UI Components
var game_header: Control

# Info Modals
var players_modal: Control
var resources_modal: Control
var buildings_modal: Control
var population_modal: Control
var army_modal: Control
var modal_positions: Dictionary = {}  # Track modal positions to prevent overlap

# --- Variables ---
var world_data: Dictionary = {}
var loaded_buildings_data: Array = []
var current_save_path: String = ""

# World Creation System
var world_creator: Node
var is_in_world_creation: bool = false


# --- Preload ---
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")


func _ready():
	print("game.gd: _ready started.")
	# --- Node Validation ---
	# ... (Keep validation) ...
	if not is_instance_valid(camera_controller) or not is_instance_valid(ui_manager) \
	or not is_instance_valid(map_object_manager) or not is_instance_valid(turn_manager):
		push_error("Game: Manager nodes not found!"); get_tree().quit(); return
	if SaveLoadManager == null:
		push_error("Game: SaveLoadManager Autoload not found!"); get_tree().quit(); return


# --- Calculate Map Bounds ---
	var map_pixel_width = 0
	var map_pixel_height = 0
	print("Game: Checking TileSet...") # Debug Print
	if is_instance_valid(tilemap_layer) and is_instance_valid(tilemap_layer.tile_set):
		var tile_size = tilemap_layer.tile_set.tile_size
		print("Game: Found TileSet, Tile Size: ", tile_size) # Debug Print
		if tile_size.x > 0 and tile_size.y > 0:
			map_pixel_width = MAP_WIDTH * tile_size.x
			map_pixel_height = MAP_HEIGHT * tile_size.y
			print("Game: Calculated map pixel dimensions: %d x %d" % [map_pixel_width, map_pixel_height]) # Debug Print
		else:
			push_error("Game: TileSet has invalid tile_size (<= 0): %s" % str(tile_size))
			# Stop execution potentially? Or default sizes? For now, error is enough.
	else:
		# This case covers both invalid tilemap_layer and missing tile_set
		if not is_instance_valid(tilemap_layer):
			# This shouldn't happen if previous validation passed, but good to check
			push_error("Game: Cannot calculate bounds, tilemap_layer node is invalid!")
		else:
			# This is the more likely error cause if validation passed
			push_error("Game: Cannot calculate bounds, TileMapLayer node is missing its TileSet resource!")
			push_error("Game: Please assign a TileSet resource to the TileMapLayer node in the editor Inspector.")
		# Consider quitting if bounds calculation fails, as it's critical
		# get_tree().quit()
		return # Stop further execution in _ready if bounds failed

	# --- Setup Managers ---
	print("Game: Setting up CameraController...")
	camera_controller.setup(camera, map_pixel_width, map_pixel_height)

	print("Game: Setting up UIManager...")
	var ui_nodes = { # Verify these paths carefully!
		"open_menu_button": $UI_Layer/MenuButtonContainer/OpenMenuButton,
		"modal_menu_panel": $UI_Layer/ModalMenuPanel,
		"world_creation_panel": $UI_Layer/WorldCreationPanel,
		"load_button": $UI_Layer/ModalMenuPanel/ModalButtonsVBox/LoadButton,
		"confirmation_panel": $UI_Layer/ConfirmationPanel,
		"confirmation_label": $UI_Layer/ConfirmationPanel/VBoxContainer/ConfirmationLabel,
		"confirm_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmSaveButton,
		"confirm_no_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmNoSaveButton,
		"confirm_cancel_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmCancelButton,
	}
	ui_manager.setup(ui_nodes)

	print("Game: Setting up MapObjectManager...")
	var forest_coords = Vector2i(0, 4); var mountain_coords = Vector2i(0, 3) # Corrected coords
	map_object_manager.setup(map_objects_holder, tilemap_layer, tree_scene, mountain_scene, forest_coords, mountain_coords)

	print("Game: Setting up TurnManager...")
	var day_label = $UI_Layer/TurnControlsContainer/TurnVBox/DayCounterLabel
	if not is_instance_valid(day_label): push_error("Game: Day counter label node not found!")
	turn_manager.setup(day_label)


	# --- Connect Signals ---
	print("Game: Connecting signals...")
	# Connect UI buttons to UIManager requests / TurnManager
	# Using get_node for safety in case @onready vars haven't resolved (unlikely but safe)
	var open_btn = get_node_or_null("UI_Layer/MenuButtonContainer/OpenMenuButton")
	if open_btn: open_btn.pressed.connect(ui_manager.open_main_modal)
	else: push_error("Game: OpenMenuButton not found for connection.")

	var return_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/ReturnButton")
	if return_btn: return_btn.pressed.connect(ui_manager.close_main_modal)
	else: push_error("Game: ReturnButton not found for connection.")

	# Add connections for SettingsButton if needed, connecting to a UIManager function

	var save_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/SaveButton")
	if save_btn: save_btn.pressed.connect(_on_save_requested) # Calls local wrapper
	else: push_error("Game: SaveButton not found for connection.")

	# Add connection for LoadButton (simple version)
	var load_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/LoadButton")
	if load_btn: load_btn.pressed.connect(_on_load_pressed) # Calls local simple load
	else: push_error("Game: LoadButton not found for connection.")

	var main_menu_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/MainMenuButton")
	if main_menu_btn: main_menu_btn.pressed.connect(ui_manager.request_main_menu)
	else: push_error("Game: MainMenuButton not found for connection.")

	var quit_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/QuitButton")
	if quit_btn: quit_btn.pressed.connect(ui_manager.request_quit)
	else: push_error("Game: QuitButton not found for connection.")

	var end_day_btn = get_node_or_null("UI_Layer/TurnControlsContainer/TurnVBox/EndDayButton")
	if end_day_btn: end_day_btn.pressed.connect(turn_manager.end_turn)
	else: push_error("Game: EndDayButton not found for connection.")


	# --- DEBUG: Connect signals *from* UIManager back to game.gd ---
	print("Game: Connecting signals FROM UIManager...")
	if is_instance_valid(ui_manager):
		if not ui_manager.is_connected("save_requested", Callable(self, "_on_save_requested_from_ui")):
			var err_save_req = ui_manager.save_requested.connect(_on_save_requested_from_ui)
			if err_save_req == OK: print("Game: Connected ui_manager.save_requested to _on_save_requested_from_ui")
			else: push_error("Game: FAILED to connect ui_manager.save_requested. Error: %d" % err_save_req)
		else: print("Game: ui_manager.save_requested ALREADY connected.")

		if not ui_manager.is_connected("action_confirmed", Callable(self, "_on_action_confirmed_from_ui")):
			var err_action_conf = ui_manager.action_confirmed.connect(_on_action_confirmed_from_ui)
			if err_action_conf == OK: print("Game: Connected ui_manager.action_confirmed to _on_action_confirmed_from_ui")
			else: push_error("Game: FAILED to connect ui_manager.action_confirmed. Error: %d" % err_action_conf)
		else: print("Game: ui_manager.action_confirmed ALREADY connected.")
	else:
		push_error("Game: Cannot connect UIManager signals, ui_manager node is invalid!")
	# --- END DEBUG ---

	print("Game: Connecting signals complete.")

	# --- Setup Game Header ---
	_setup_game_header()

	# --- Initialize Map ---
	initialize_map()
	print("game.gd: _ready finished.")


func _unhandled_input(event: InputEvent):
	if is_in_world_creation:
		# During world creation, use camera controller for all input
		if is_instance_valid(camera_controller):
			camera_controller.handle_input(event, false)  # Not paused during world creation
		get_viewport().set_input_as_handled()
		return
		
	# Normal game input handling
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(ui_manager): ui_manager.handle_escape()
		get_viewport().set_input_as_handled(); return

	if is_instance_valid(camera_controller):
		camera_controller.handle_input(event, get_tree().paused)


func _process(delta: float):
	if is_instance_valid(camera_controller):
		camera_controller.process_movement(delta, get_tree().paused)


# --- Map Initialization ---
func initialize_map():
	print("Game: Initializing Map..."); print("Game: Start Mode: %s" % GameManager.start_mode)
	var success = false; var loaded_day = 1
	
	if GameManager.start_mode == "world_creation":
		print("Game: Mode: World Creation")
		_start_world_creation_mode()
		return  # Don't proceed with normal map initialization
	elif GameManager.start_mode == "new":
		print("Game: Mode: New Game"); current_save_path = ""
		if generate_world_data(): success = true
		else: push_error("Game: Failed to generate world data.")
	elif GameManager.start_mode == "new_with_data":
		print("Game: Mode: New Game with Generated Data")
		current_save_path = ""
		if not GameManager.generated_world_data.is_empty():
			world_data = GameManager.generated_world_data.duplicate()
			GameManager.generated_world_data.clear()  # Clear it after use
			success = true
		else:
			push_error("Game: Generated world data is empty, falling back to normal generation")
			if generate_world_data(): success = true
	elif GameManager.start_mode == "load":
		print("Game: Mode: Load Game from Path: ", GameManager.load_file_path)
		if GameManager.load_file_path.is_empty(): push_error("Game: Load mode selected but no load_file_path provided! Starting new game."); GameManager.start_mode = "new"; initialize_map(); return
		else:
			var loaded_state = SaveLoadManager.load_game(GameManager.load_file_path)
			if not loaded_state.is_empty():
				world_data = loaded_state["map_data"]; loaded_day = loaded_state["current_day"]
				current_save_path = loaded_state["current_save_path"]; success = true
				# Store buildings data for restoration after map is drawn
				if loaded_state.has("buildings_data"):
					loaded_buildings_data = loaded_state["buildings_data"]
			else: push_error("Game: Failed to load state from %s. Starting new game." % GameManager.load_file_path); GameManager.start_mode = "new"; initialize_map(); return
	else: push_error("Game: Invalid start mode: %s. Starting new game." % GameManager.start_mode); GameManager.start_mode = "new"; initialize_map(); return
	if success:
		print("Game: Map state ready. Updating managers...")
		turn_manager.set_day(loaded_day); _clear_and_draw_map(); map_object_manager.clear_objects()
		map_object_manager.place_objects(world_data)
		# Restore buildings if loading from save
		if not loaded_buildings_data.is_empty():
			_restore_buildings(loaded_buildings_data)
			loaded_buildings_data = []  # Clear after restoration
		camera_controller.center_camera()
		print("Game: Map ready.")
	else: print("Game: Map initialization failed.")
	print("Game: --- Map Initialization Finished ---")


# --- World Creation Functions ---

func _start_world_creation_mode():
	print("Game: Starting world creation mode")
	is_in_world_creation = true
	
	# Hide game header during world creation
	if game_header:
		game_header.visible = false
	
	# Create world creator
	var WorldCreationModal = preload("res://scripts/main/world_creation_modal.gd")
	world_creator = WorldCreationModal.new()
	world_creator.name = "WorldCreationModal"
	add_child(world_creator)
	
	# Hide normal UI elements
	$UI_Layer/MenuButtonContainer.hide()
	$UI_Layer/TurnControlsContainer.hide()
	
	# Setup world creator with direct UI control
	world_creator.setup_direct_ui(self, tilemap_layer, camera)
	
	print("Game: World creation mode active with direct UI control")

func _setup_world_creation_delayed():
	# Remove this function - not needed with direct UI approach
	pass

func _connect_world_creation_buttons():
	# Remove this function - not needed with direct UI approach  
	pass

func _debug_print_ui_structure(node: Node, indent: int = 0):
	# Keep this for debugging if needed
	var indent_str = "  ".repeat(indent)
	print("%s%s" % [indent_str, node.name])
	for child in node.get_children():
		_debug_print_ui_structure(child, indent + 1)

# Direct button handlers that call the world creator
func _on_world_creation_continue():
	print("Game: Continue button pressed!")
	if world_creator and world_creator.has_method("_on_continue_pressed"):
		world_creator._on_continue_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _on_world_creation_back():
	print("Game: Back button pressed!")
	if world_creator and world_creator.has_method("_on_back_pressed"):
		world_creator._on_back_pressed()
	else:
		push_error("Game: World creator or method not found!")

func _finish_world_creation(generated_world_data: Dictionary):
	print("Game: Finishing world creation")
	is_in_world_creation = false
	
	# Use the generated world data
	world_data = generated_world_data.duplicate()
	current_save_path = ""
	
	# Close world creation modal
	ui_manager.close_world_creation_modal()
	
	# Clean up world creator
	if world_creator:
		world_creator.queue_free()
		world_creator = null
	
	# Proceed with normal game initialization first
	var loaded_day = 1
	turn_manager.set_day(loaded_day)
	_clear_and_draw_map()
	# Don't clear objects - they were placed during world creation
	# map_object_manager.clear_objects()
	# map_object_manager.place_objects(world_data)
	
	# Place the starting town center AFTER map objects are placed
	_place_starting_town_center()
	
	# Show game header now that the game has started
	if game_header:
		game_header.visible = true
		print("Game: Game header now visible after world creation")
	
	# Don't center camera - preserve current position from world creation
	# camera_controller.center_camera()
	print("Game: World creation complete, game ready.")

func _place_starting_town_center():
	# Get starting tile position from world data
	if not world_data.has("starting_tile"):
		print("Warning: No starting tile found in world data")
		return
		
	var starting_tile = world_data["starting_tile"]
	var tile_coords = Vector2i(int(starting_tile.x), int(starting_tile.y))
	print("Game: Placing town center at tile: ", tile_coords)
	
	# Clear any existing terrain features at this tile
	_clear_tile_features(tile_coords)
	
	# Place the town center building
	_place_town_center_building(tile_coords)

func _clear_tile_features(tile_coords: Vector2i):
	# Remove any objects (trees, mountains) at this tile
	if map_object_manager and map_object_manager.has_method("remove_object_at_tile"):
		map_object_manager.remove_object_at_tile(tile_coords)
	
	# Clear any terrain modifiers from world_data
	var coord_key = tile_coords
	if world_data.has(coord_key):
		var tile_data = world_data[coord_key]
		if typeof(tile_data) == TYPE_DICTIONARY:
			# Keep the base terrain but remove any modifiers
			print("Game: Cleared features from tile: ", tile_coords)

func _place_town_center_building(tile_coords: Vector2i):
	# Get player race and building choice
	var player_data = world_data.get("player_data", {})
	var selected_race = player_data.get("race", "human")
	var selected_building = player_data.get("starting_building", "town_center")
	
	print("Game: Placing ", selected_building, " for race ", selected_race, " at ", tile_coords)
	
	# Load the town center texture
	var building_texture_path = "res://assets/buildings/human_towncentre-export.png"
	if selected_building == "fishing_hut":
		building_texture_path = "res://assets/buildings/human_finshinghut.png"
	elif selected_building == "barracks":
		building_texture_path = "res://assets/buildings/human_barracks.png"
	elif selected_building == "house":
		building_texture_path = "res://assets/buildings/human_house.png"
	
	# Create the building sprite
	if ResourceLoader.exists(building_texture_path):
		var building_texture = load(building_texture_path)
		var building_sprite = Sprite2D.new()
		building_sprite.name = "TownCenter_" + str(tile_coords.x) + "_" + str(tile_coords.y)
		building_sprite.texture = building_texture
		
		# Add player ownership data
		building_sprite.set_meta("owner_player", 1)  # Player 1
		building_sprite.set_meta("building_type", selected_building)
		building_sprite.set_meta("construction_day", turn_manager.get_day())
		
		# Position it at the tile location
		var world_pos = tilemap_layer.map_to_local(tile_coords)
		building_sprite.position = world_pos
		building_sprite.z_index = 5  # Above terrain but below UI
		
		# Add to map objects holder
		map_objects_holder.add_child(building_sprite)
		
		print("Game: Successfully placed ", selected_building, " at world position: ", world_pos)
		
		# Auto-save after placing town center
		print("Game: Auto-saving after town center placement...")
		if _execute_save():
			print("Game: Auto-save successful!")
		else:
			print("Game: Auto-save failed, but continuing game...")
	else:
		print("Warning: Could not find building texture: ", building_texture_path)

func _setup_game_header():
	# Create and setup the game header
	var GameHeaderScript = preload("res://scripts/managers/game_header.gd")
	game_header = GameHeaderScript.new()
	ui_layer.add_child(game_header)
	
	# Header is visible by default
	
	# Connect header signals to existing UI manager functions
	game_header.settings_pressed.connect(_on_header_settings_pressed)
	game_header.players_pressed.connect(_on_header_players_pressed)
	game_header.resources_pressed.connect(_on_header_resources_pressed)
	game_header.buildings_pressed.connect(_on_header_buildings_pressed)
	game_header.population_pressed.connect(_on_header_population_pressed)
	game_header.army_pressed.connect(_on_header_army_pressed)
	
	# No need to update values anymore
	print("Game: Game header created and connected")
	
	# Setup info modals
	_setup_info_modals()

func _restore_buildings(buildings_data: Array):
	print("Game: Restoring ", buildings_data.size(), " buildings from save data")
	for building_info in buildings_data:
		if building_info.has("texture_path") and ResourceLoader.exists(building_info["texture_path"]):
			var building_texture = load(building_info["texture_path"])
			var building_sprite = Sprite2D.new()
			building_sprite.name = building_info.get("name", "Building")
			building_sprite.texture = building_texture
			building_sprite.position = building_info.get("position", Vector2.ZERO)
			building_sprite.z_index = building_info.get("z_index", 5)
			
			# Restore ownership data
			building_sprite.set_meta("owner_player", building_info.get("owner_player", 1))
			building_sprite.set_meta("building_type", building_info.get("building_type", "unknown"))
			building_sprite.set_meta("construction_day", building_info.get("construction_day", 0))
			
			map_objects_holder.add_child(building_sprite)
			print("Game: Restored building: ", building_sprite.name, " at position: ", building_sprite.position)
		else:
			print("Warning: Could not restore building with texture: ", building_info.get("texture_path", "unknown"))

func _setup_info_modals():
	# Create info modals with different starting positions
	var PlayersModalScript = preload("res://scripts/ui/players_modal.gd")
	var ResourcesModalScript = preload("res://scripts/ui/resources_modal.gd")
	var BuildingsModalScript = preload("res://scripts/ui/buildings_modal.gd")
	var PopulationModalScript = preload("res://scripts/ui/population_modal.gd")
	var ArmyModalScript = preload("res://scripts/ui/army_modal.gd")
	
	# Calculate positions to prevent overlap
	var base_pos = Vector2(10, 60)  # Base position under header
	var modal_offset = Vector2(50, 50)  # Offset for each new modal
	
	players_modal = PlayersModalScript.new(self, base_pos)
	resources_modal = ResourcesModalScript.new(self, base_pos + modal_offset)
	buildings_modal = BuildingsModalScript.new(self, base_pos + modal_offset * 2)
	population_modal = PopulationModalScript.new(self, base_pos + modal_offset * 3)
	army_modal = ArmyModalScript.new(self, base_pos + modal_offset * 4)
	
	# Add modals to UI layer
	ui_layer.add_child(players_modal)
	ui_layer.add_child(resources_modal)
	ui_layer.add_child(buildings_modal)
	ui_layer.add_child(population_modal)
	ui_layer.add_child(army_modal)
	
	# Connect modal close signals (optional)
	players_modal.modal_closed.connect(_on_modal_closed)
	resources_modal.modal_closed.connect(_on_modal_closed)
	buildings_modal.modal_closed.connect(_on_modal_closed)
	population_modal.modal_closed.connect(_on_modal_closed)
	army_modal.modal_closed.connect(_on_modal_closed)
	
	print("Game: Info modals setup complete")

func _on_modal_closed(modal_type: String):
	print("Game: Modal closed: ", modal_type)

# Header button handlers
func _on_header_settings_pressed():
	# Delegate to existing UI manager settings functionality
	if ui_manager and ui_manager.has_method("open_main_modal"):
		ui_manager.open_main_modal()

func _on_header_players_pressed():
	if players_modal:
		players_modal.toggle()

func _on_header_resources_pressed():
	if resources_modal:
		resources_modal.toggle()

func _on_header_buildings_pressed():
	if buildings_modal:
		buildings_modal.toggle()

func _on_header_population_pressed():
	if population_modal:
		population_modal.toggle()

func _on_header_army_pressed():
	if army_modal:
		army_modal.toggle()

func _cancel_world_creation():
	print("Game: Cancelling world creation")
	is_in_world_creation = false
	
	# Clean up world creator
	if world_creator:
		world_creator.queue_free()
		world_creator = null
	
	# Close world creation modal
	ui_manager.close_world_creation_modal()
	
	# Return to main menu
	var error = get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")
	if error != OK:
		push_error("Failed to return to main menu. Error code: %d" % error)

# --- Map Generation Functions ---

func generate_world_data() -> bool:
	print("Game: Generating world data..."); var generator = WorldGenerator.new()
	world_data = generator.generate_world_data(MAP_WIDTH, MAP_HEIGHT)
	if world_data.is_empty(): push_error("Game: World generator returned empty data."); return false
	print("Game: Generation complete."); return true


func _clear_and_draw_map():
	print("Game: Drawing game map...");
	if not is_instance_valid(tilemap_layer): push_error("Game: Cannot draw, TileMapLayer is invalid."); return
	tilemap_layer.clear()
	if world_data.is_empty(): print("Game: No world data loaded to draw."); return
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])
		else: push_warning("Game: Skipping invalid tile data at coords: %s" % str(coords))
	print("Game: Map drawing complete.")


# --- Save/Load Wrappers & UI Callbacks ---

func _on_save_requested():
	print("Game: Save requested by UI button.")
	_execute_save()


func _on_save_requested_from_ui(pending_action: String):
	print("Game: _on_save_requested_from_ui called for action: ", pending_action) # DEBUG
	if _execute_save():
		print("Game: Save successful, telling UIManager to perform action.") # DEBUG
		if is_instance_valid(ui_manager):
			ui_manager.perform_pending_action_after_save()
	else:
		print("Game: Save failed, UI manager should handle reopening menu.") # DEBUG
		# UIManager's _on_confirm_save already handles reopening main menu on failure


func _execute_save() -> bool:
	# Collect building data
	var buildings_data = []
	if map_objects_holder:
		for child in map_objects_holder.get_children():
			if child.name.begins_with("TownCenter_") or child.name.contains("Building_"):
				var building_info = {
					"name": child.name,
					"position": child.position,
					"texture_path": child.texture.resource_path if child.texture else "",
					"z_index": child.z_index,
					"owner_player": child.get_meta("owner_player", 1),
					"building_type": child.get_meta("building_type", "unknown"),
					"construction_day": child.get_meta("construction_day", 0)
				}
				buildings_data.append(building_info)
	
	var game_state = { 
		"map_data": world_data, 
		"buildings_data": buildings_data,
		"current_day": turn_manager.get_day(), 
		"current_save_path": current_save_path 
	}
	var saved_path = SaveLoadManager.save_game(game_state, current_save_path)
	if not saved_path.is_empty():
		current_save_path = saved_path; return true
	else: print("Game: Save failed in SaveLoadManager."); return false


func _on_action_confirmed_from_ui(action_name: String):
	print("Game: _on_action_confirmed_from_ui called for action: ", action_name) # DEBUG
	if is_instance_valid(ui_manager):
		ui_manager._perform_action(action_name) # Tell UI Manager to proceed


# Placeholder for simple load button (Needs replacing with UI Manager integration)
func _on_load_pressed():
	push_warning("Game: Simple Load button pressed - functionality should be moved to UIManager Load Modal.")
	var first_save_path = ""
	var dir = DirAccess.open(SaveLoadManager.SAVE_DIR);
	if dir: dir.list_dir_begin(); var f=dir.get_next(); while f!="": if !dir.current_is_dir() and f.ends_with(".save"): first_save_path = SaveLoadManager.SAVE_DIR.path_join(f); break; f=dir.get_next()
	if first_save_path.is_empty(): push_warning("Game: No save file found for simple load."); return
	print("Game: Attempting simple load of: ", first_save_path)
	var loaded_state = SaveLoadManager.load_game(first_save_path)
	if not loaded_state.is_empty():
		world_data = loaded_state["map_data"]; current_save_path = loaded_state["current_save_path"]
		turn_manager.set_day(loaded_state["current_day"]); _clear_and_draw_map(); map_object_manager.clear_objects()
		map_object_manager.place_objects(world_data); camera_controller.center_camera()
		# Header is visible by default for loaded games
		print("Game: Loaded successfully via simple load.")
	else: 
		print("Game: Failed simple load.")

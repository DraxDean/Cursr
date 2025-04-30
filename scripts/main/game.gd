# scripts/main/game.gd - Orchestrator (with Debug Prints)
extends Node

# --- Constants ---
const MAP_WIDTH = 80
const MAP_HEIGHT = 50

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

# --- Variables ---
var world_data: Dictionary = {}
var current_save_path: String = ""
var player_race: String = "notset"

# --- Preload Scripts---
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")

func _ready():
	print("game.gd: _ready started.")
	# --- Manager Node Validations ---
	if not is_instance_valid(camera_controller) or not is_instance_valid(ui_manager) \
	or not is_instance_valid(map_object_manager) or not is_instance_valid(turn_manager):
		push_error("Game: Manager nodes not found!"); get_tree().quit(); return
	if SaveLoadManager == null:
		push_error("Game: SaveLoadManager Autoload not found!"); get_tree().quit(); return

# --- Calculate Map Bounds ---
	var map_pixel_width = 0
	var map_pixel_height = 0
	print("Game: Checking TileSet...") 
	if is_instance_valid(tilemap_layer) and is_instance_valid(tilemap_layer.tile_set):
		var tile_size = tilemap_layer.tile_set.tile_size
		print("Game: Found TileSet, Tile Size: ", tile_size) 
		if tile_size.x > 0 and tile_size.y > 0:
			map_pixel_width = MAP_WIDTH * tile_size.x
			map_pixel_height = MAP_HEIGHT * tile_size.y
			print("Game: Calculated map pixel dimensions: %d x %d" % [map_pixel_width, map_pixel_height]) # Debug Print
		else:
			push_error("Game: TileSet has invalid tile_size (<= 0): %s" % str(tile_size))
	else:
		if not is_instance_valid(tilemap_layer):
			push_error("Game: Cannot calculate bounds, tilemap_layer node is invalid!")
		else:
			push_error("Game: Cannot calculate bounds, TileMapLayer node is missing its TileSet resource!")
			push_error("Game: Please assign a TileSet resource to the TileMapLayer node in the editor Inspector.")
		return 

	# --- Setup Managers ---
	print("Game: Setting up CameraController...")
	camera_controller.setup(camera, map_pixel_width, map_pixel_height)

	print("Game: Setting up UIManager...")
	var ui_nodes = { # Verify these paths carefully!
		"open_menu_button": $UI_Layer/MenuButtonContainer/OpenMenuButton,
		"modal_menu_panel": $UI_Layer/ModalMenuPanel,
		"confirmation_panel": $UI_Layer/ConfirmationPanel,
		"confirmation_label": $UI_Layer/ConfirmationPanel/VBoxContainer/ConfirmationLabel,
		"confirm_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmSaveButton,
		"confirm_no_save_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmNoSaveButton,
		"confirm_cancel_button": $UI_Layer/ConfirmationPanel/VBoxContainer/HBoxContainer/ConfirmCancelButton,
		
		"open_build_window": $UI_Layer/CommandsContainer/HBoxContainer/OpenBuildButton,
		"build_window": $UI_Layer/BuildWindow,
		
	}
	ui_manager.setup(ui_nodes)

	print("Game: Setting up MapObjectManager...")
	var forest_coords = Vector2i(0, 4); var mountain_coords = Vector2i(0, 3) # Corrected coords
	map_object_manager.setup(map_objects_holder, tilemap_layer, tree_scene, mountain_scene, forest_coords, mountain_coords)

	print("Game: Setting up TurnManager...")
	var day_label = $UI_Layer/TurnControlsContainer/TurnVBox/DayCounterLabel
	if not is_instance_valid(day_label): push_error("Game: Day counter label node not found!")
	turn_manager.setup(day_label)
	
	player_race = GameManager.selected_race
	print("Game: Starting Race: ", player_race)


	# --- Connect Signals ---
	
#	Game Menu Modal Connections
	print("Game: Connecting signals...")
	var open_btn = get_node_or_null("UI_Layer/MenuButtonContainer/OpenMenuButton")
	if open_btn: open_btn.pressed.connect(ui_manager.open_main_modal)
	else: push_error("Game: OpenMenuButton not found for connection.")
	var return_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/ReturnButton")
	if return_btn: return_btn.pressed.connect(ui_manager.close_main_modal)
	else: push_error("Game: ReturnButton not found for connection.")
	var save_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/SaveButton")
	if save_btn: save_btn.pressed.connect(_on_save_requested) # Calls local wrapper
	else: push_error("Game: SaveButton not found for connection.")
	var main_menu_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/MainMenuButton")
	if main_menu_btn: main_menu_btn.pressed.connect(ui_manager.request_main_menu)
	else: push_error("Game: MainMenuButton not found for connection.")
	var quit_btn = get_node_or_null("UI_Layer/ModalMenuPanel/ModalButtonsVBox/QuitButton")
	if quit_btn: quit_btn.pressed.connect(ui_manager.request_quit)
	else: push_error("Game: QuitButton not found for connection.")
	
#	Build Modal Connections
	var open_build_btn = get_node_or_null("UI_Layer/CommandsContainer/HBoxContainer/OpenBuildButton")
	if open_build_btn: open_build_btn.pressed.connect(ui_manager.open_build_window)
	else: push_error("Game: QuitButton not found for connection.")
	
#	Turn connections
	var end_day_btn = get_node_or_null("UI_Layer/TurnControlsContainer/TurnVBox/EndDayButton")
	if end_day_btn: end_day_btn.pressed.connect(turn_manager.end_turn)
	else: push_error("Game: EndDayButton not found for connection.")

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
		
	print("Game: Connecting signals complete.")

	# --- Initialize Map ---
	initialize_map()
	print("game.gd: _ready finished.")

func _unhandled_input(event: InputEvent):
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
	if GameManager.start_mode == "new":
		print("Game: Mode: New Game"); current_save_path = ""
		if generate_world_data(): success = true
		else: push_error("Game: Failed to generate world data.")
	elif GameManager.start_mode == "load":
		print("Game: Mode: Load Game from Path: ", GameManager.load_file_path)
		if GameManager.load_file_path.is_empty(): push_error("Game: Load mode selected but no load_file_path provided! Starting new game."); GameManager.start_mode = "new"; initialize_map(); return
		else:
			var loaded_state = SaveLoadManager.load_game(GameManager.load_file_path)
			if not loaded_state.is_empty():
				world_data = loaded_state["map_data"]; loaded_day = loaded_state["current_day"]
				current_save_path = loaded_state["current_save_path"]; success = true
			else: push_error("Game: Failed to load state from %s. Starting new game." % GameManager.load_file_path); GameManager.start_mode = "new"; initialize_map(); return
	else: push_error("Game: Invalid start mode: %s. Starting new game." % GameManager.start_mode); GameManager.start_mode = "new"; initialize_map(); return
	if success:
		print("Game: Map state ready. Updating managers...")
		turn_manager.set_day(loaded_day); _clear_and_draw_map(); map_object_manager.clear_objects()
		map_object_manager.place_objects(world_data); camera_controller.center_camera()
		print("Game: Map ready.")
	else: print("Game: Map initialization failed.")
	print("Game: --- Map Initialization Finished ---")

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
	var game_state = { "map_data": world_data, "current_day": turn_manager.get_day(), "current_save_path": current_save_path }
	var saved_path = SaveLoadManager.save_game(game_state, current_save_path)
	if not saved_path.is_empty():
		current_save_path = saved_path; return true
	else: print("Game: Save failed in SaveLoadManager."); return false

func _on_action_confirmed_from_ui(action_name: String):
	print("Game: _on_action_confirmed_from_ui called for action: ", action_name) # DEBUG
	if is_instance_valid(ui_manager):
		ui_manager._perform_action(action_name) # Tell UI Manager to proceed

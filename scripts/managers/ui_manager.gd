# scripts/managers/ui_manager.gd
extends Node

# Node References (Set via setup)
var open_menu_button: Button
var modal_menu_panel: PanelContainer
var load_button: Button # In main modal
var confirmation_panel: PanelContainer
var confirmation_label: Label
var confirm_save_button: Button
var confirm_no_save_button: Button
var confirm_cancel_button: Button

var open_build_button: Button
var building_selector;

var selected_building_data = null
var building_preview_sprite = null
var is_building_mode = false

var map_object_manager;

# State
var _pending_action: String = "" # "quit", "main_menu"

# Constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main/main_menu_scene.tscn" # Keep consistent

# Signals for communication
signal save_requested(pending_action) # Emitted when user confirms save
signal action_confirmed(action_name) # Emitted when user confirms without save
signal action_cancelled # Emitted when user cancels

signal building_placement_requested(building_data, coords)

func setup(ui_nodes: Dictionary, object_manager):
	print("UIManager: Setup started.")
	
	map_object_manager = object_manager;
	
	# Expects a dictionary containing references to the UI nodes
	open_menu_button = ui_nodes.get("open_menu_button")
	modal_menu_panel = ui_nodes.get("modal_menu_panel")
	load_button = ui_nodes.get("load_button") # Main modal load button
	confirmation_panel = ui_nodes.get("confirmation_panel")
	confirmation_label = ui_nodes.get("confirmation_label")
	confirm_save_button = ui_nodes.get("confirm_save_button")
	confirm_no_save_button = ui_nodes.get("confirm_no_save_button")
	confirm_cancel_button = ui_nodes.get("confirm_cancel_button")
	open_build_button = ui_nodes.get("open_build_button")

	# --- END DEBUG ---

	if not is_instance_valid(modal_menu_panel) or not is_instance_valid(confirmation_panel):
		push_error("UIManager: Critical panel references missing!")
		return # Stop setup if panels are missing

	# Initial state
	modal_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	modal_menu_panel.hide()
	confirmation_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	confirmation_panel.hide()
	
	#test_modal();
	building_selector_modal();
	building_selector.building_selected.connect(_on_building_selected)
	
	# Connect internal signals here
	_connect_confirmation_signals()

	print("UIManager setup complete.")


func _connect_confirmation_signals():
	print("UIManager: Attempting to connect confirmation signals...")
	# Ensure the button variables are valid before connecting!
	if not is_instance_valid(confirm_save_button): push_error("UIManager: ConfirmSaveButton node invalid! Cannot connect."); return
	if not is_instance_valid(confirm_no_save_button): push_error("UIManager: ConfirmNoSaveButton node invalid! Cannot connect."); return
	if not is_instance_valid(confirm_cancel_button): push_error("UIManager: ConfirmCancelButton node invalid! Cannot connect."); return

	# Connect Save Button
	if not confirm_save_button.is_connected("pressed", Callable(self, "_on_confirm_save")):
		var err_save = confirm_save_button.pressed.connect(_on_confirm_save)
		if err_save == OK: print("UIManager: Connected confirm_save_button to _on_confirm_save")
		else: push_error("UIManager: FAILED to connect confirm_save_button. Error: %d" % err_save)
	else: print("UIManager: confirm_save_button ALREADY connected.")

	# Connect No Save Button
	if not confirm_no_save_button.is_connected("pressed", Callable(self, "_on_confirm_no_save")):
		var err_no_save = confirm_no_save_button.pressed.connect(_on_confirm_no_save)
		if err_no_save == OK: print("UIManager: Connected confirm_no_save_button to _on_confirm_no_save")
		else: push_error("UIManager: FAILED to connect confirm_no_save_button. Error: %d" % err_no_save)
	else: print("UIManager: confirm_no_save_button ALREADY connected.")

	# Connect Cancel Button
	if not confirm_cancel_button.is_connected("pressed", Callable(self, "_on_confirm_cancel")):
		var err_cancel = confirm_cancel_button.pressed.connect(_on_confirm_cancel)
		if err_cancel == OK: print("UIManager: Connected confirm_cancel_button to _on_confirm_cancel")
		else: push_error("UIManager: FAILED to connect confirm_cancel_button. Error: %d" % err_cancel)
	else: print("UIManager: confirm_cancel_button ALREADY connected.")

# In your main scene/ui_manager
func test_modal():
	var modal = preload("res://scenes/ui/test_modal.tscn").instantiate()
	add_child(modal)
	print("UIManager: Test Modal successfully added to scene")

func building_selector_modal():
	var modal = preload("res://scenes/ui/building_selector.tscn").instantiate()
	building_selector = modal;
	add_child(modal)
	modal.hide();
	print("UIManager: Building Selector Modal successfully added to scene")
	
# --- Public Methods Called by game.gd or Signals ---

func open_main_modal():
	print("UIManager: open_main_modal called.") # DEBUG
	if not is_instance_valid(modal_menu_panel): push_error("UIManager: Cannot open modal, panel invalid!"); return # DEBUG
	confirmation_panel.hide() # Ensure confirmation is hidden
	modal_menu_panel.show()
	# Check save state to enable/disable load button
	if is_instance_valid(load_button):
		load_button.disabled = not SaveLoadManager.check_saves_exist()
	else: push_warning("UIManager: Load button instance invalid in open_main_modal.") # DEBUG

	get_tree().paused = true
	if is_instance_valid(open_menu_button): open_menu_button.disabled = true


func close_main_modal():
	print("UIManager: close_main_modal called.") # DEBUG
	if not is_instance_valid(modal_menu_panel): return # DEBUG Safety
	modal_menu_panel.hide()
	# Only unpause if the confirmation panel is also hidden
	if not confirmation_panel.visible:
		get_tree().paused = false
		if is_instance_valid(open_menu_button): open_menu_button.disabled = false
	else:
		print("UIManager: Not unpausing, confirmation panel is visible.") # DEBUG


func request_main_menu():
	print("UIManager: Main Menu action requested.") # DEBUG
	if not is_instance_valid(confirmation_panel) or not is_instance_valid(confirmation_label) \
	or not is_instance_valid(confirm_save_button) or not is_instance_valid(confirm_no_save_button):
		push_error("UIManager: Cannot request main menu, confirmation UI node(s) invalid!") # DEBUG
		return

	_pending_action = "main_menu"
	confirmation_label.text = "Return to Main Menu? Unsaved progress will be lost."
	confirm_save_button.text = "Save & Go to Menu"; confirm_no_save_button.text = "Go to Menu Without Saving"
	if is_instance_valid(modal_menu_panel): modal_menu_panel.hide()
	confirmation_panel.show()


func request_quit():
	print("UIManager: Quit action requested.") # DEBUG
	if not is_instance_valid(confirmation_panel) or not is_instance_valid(confirmation_label) \
	or not is_instance_valid(confirm_save_button) or not is_instance_valid(confirm_no_save_button):
		push_error("UIManager: Cannot request quit, confirmation UI node(s) invalid!") # DEBUG
		return

	_pending_action = "quit"
	confirmation_label.text = "Quit game? Unsaved progress will be lost."
	confirm_save_button.text = "Save & Quit"; confirm_no_save_button.text = "Quit Without Saving"
	if is_instance_valid(modal_menu_panel): modal_menu_panel.hide()
	confirmation_panel.show()


# --- Internal Signal Handlers for Confirmation ---

func _on_confirm_save():
	print("UIManager: _on_confirm_save called.") # DEBUG
	if not is_instance_valid(confirmation_panel): return # DEBUG Safety
	confirmation_panel.hide()
	print("UIManager: Emitting 'save_requested' signal for action: ", _pending_action) # DEBUG
	emit_signal("save_requested", _pending_action)


func _on_confirm_no_save():
	print("UIManager: _on_confirm_no_save called.") # DEBUG
	if not is_instance_valid(confirmation_panel): return # DEBUG Safety
	confirmation_panel.hide()
	print("UIManager: Emitting 'action_confirmed' signal for action: ", _pending_action) # DEBUG
	emit_signal("action_confirmed", _pending_action)


func _on_confirm_cancel():
	print("UIManager: _on_confirm_cancel called.") # DEBUG
	if not is_instance_valid(confirmation_panel): return # DEBUG Safety
	confirmation_panel.hide()
	_pending_action = ""
	open_main_modal() # Reopen main modal on cancel
	print("UIManager: Emitting 'action_cancelled' signal.") # DEBUG
	emit_signal("action_cancelled")


func open_building_selector():
	print("UIManager: open_building_selector called.") # DEBUG
	if building_selector.visible:
		building_selector.hide()
	else:
		building_selector.popup_centered()
		


func _on_building_selected(building_data):
	print("UIManager: Main scene received building: ", building_data)
	selected_building_data = building_data
	enter_building_mode()

func enter_building_mode():
	is_building_mode = true;
	print("UIManager: Entering building mode... ", is_building_mode);
	create_building_preview();
	
func create_building_preview():
	building_preview_sprite = Sprite2D.new()
	print("UIManager: Loading texture: ", selected_building_data.path);
	building_preview_sprite.texture = load(selected_building_data.path)
	building_preview_sprite.modulate = Color(1, 1, 1, 0.5)  # Semi-transparent
	building_preview_sprite.centered = true
#	temp offset until tile preview
	building_preview_sprite.offset = Vector2(695, 405);
	add_child(building_preview_sprite)

# --- Public Method Called by game.gd after Save Success ---

func perform_pending_action_after_save():
	print("UIManager: perform_pending_action_after_save called.") # DEBUG
	_perform_action(_pending_action)


# --- Internal Helper ---

func _perform_action(action_name: String):
	var action_to_perform = action_name
	_pending_action = "" # Clear pending action immediately

	print("UIManager: Performing action: %s" % action_to_perform) # DEBUG
	get_tree().paused = false # Unpause before changing scene or quitting

	if action_to_perform == "main_menu":
		var error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		if error != OK: push_error("UIManager: Failed to change scene to Main Menu. Error: %d" % error)
	elif action_to_perform == "quit":
		get_tree().quit()
	else:
		push_warning("UIManager: Tried to perform unknown pending action: %s" % action_to_perform)


# Handle Esc key presses forwarded from game.gd
func handle_escape():
	print("UIManager: handle_escape called.") # DEBUG
	if confirmation_panel.visible:
		print("UIManager Escape: Confirmation panel visible, cancelling.") # DEBUG
		_on_confirm_cancel()
	elif modal_menu_panel.visible:
		print("UIManager Escape: Main modal visible, closing.") # DEBUG
		close_main_modal()
	# Add elif for load modal here later
	else: # If no modals are open, open the main one
		print("UIManager Escape: No modals visible, opening main.") # DEBUG
		open_main_modal()

# Add these variables to your main scene
var tile_size = Vector2(32, 32)  # Adjust to your actual tile size
var grid_offset = Vector2(0, 0)  # If your grid doesn't start at 0,0

func get_tile_position(world_pos: Vector2) -> Vector2:
	# Convert world position to tile coordinates
	var tile_coords = ((world_pos - grid_offset) / tile_size).floor()
	# Convert back to world position (snapped to grid)
	return tile_coords * tile_size + grid_offset
#
func _input(event):
	#	inspect mode
		
	#	build mode
	if is_building_mode and event is InputEventMouseMotion:
		print("UIManager: input detected in building mode at: ", get_viewport().get_mouse_position())
		print("UIManager: tile coords at mouse: ", get_tile_position(event.global_position));
		var snapped_position = get_tile_position(event.global_position);
		building_preview_sprite.global_position = snapped_position
		building_preview_sprite.global_position -= tile_size / 2
		var texture_size = building_preview_sprite.texture.get_size()
		var centered_position = event.global_position - (texture_size / 2)
		building_preview_sprite.global_position = centered_position
		#var tile_pos = get_tile_under_mouse(event.position)
		 #Handle hover
		#on_tile_hover(tile_pos)
	if is_building_mode and event is InputEventMouseButton:
		# Check if camera is handling this input (dragg
		#return  # Don't place building while dragging camera
		# Get world position from camera controller
		#var world_pos = camera_controller.get_world_mouse_position()
		# Send to game manager to place building
		map_object_manager.place_building(selected_building_data, Vector2(0,0));
		
		#var snapped_position = get_tile_position(event.global_position);
		#building_preview_sprite.global_position = snapped_position;
		#print("UIManager: Blueprint for building: ", selected_building_data, ", at: ", snapped_position)
		##create blueprint(selected_building_data, coords)
		## When user clicks to place building
		#building_placement_requested.emit(selected_building_data, snapped_position)

#func get_tile_under_mouse(mouse_pos: Vector2) -> Vector2i:
	## Convert screen position to world position
	#var world_pos = get_viewport().get_global_mouse_position()
	## Convert world position to tilemap coordinates
	#var tile_pos = tilemap.local_to_map(tilemap.to_local(world_pos))
	#return tile_pos
#
#func on_tile_hover(tile_pos: Vector2i):
	## Visual feedback for hovering
	#print("Hovering tile: ", tile_pos)
	#
#func on_tile_click(tile_pos: Vector2i):
	## Check if tile is valid and buildable
	#if is_tile_buildable(tile_pos):
		#build_on_tile(tile_pos)
#
#func is_tile_buildable(tile_pos: Vector2i) -> bool:
	## Check if tile exists and is empty
	#var tile_data = tilemap.get_cell_tile_data(0, tile_pos)
	#return tile_data != null  # Add more conditions as needed
#
#func build_on_tile(tile_pos: Vector2i):
	## Add building to this specific tile
	#add_building_to_tile(tile_pos, building_data)

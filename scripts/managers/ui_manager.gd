# scripts/managers/ui_manager.gd
extends Node

# Node References (Set via setup)
var open_menu_button: Button
var modal_menu_panel: PanelContainer
var world_creation_panel: Control
var load_button: Button # In main modal
var confirmation_panel: PanelContainer
var confirmation_label: Label
var confirm_save_button: Button
var confirm_no_save_button: Button
var confirm_cancel_button: Button

# State
var _pending_action: String = "" # "quit", "main_menu"

# Constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main/main_menu_scene.tscn" # Keep consistent

# Signals for communication
signal save_requested(pending_action) # Emitted when user confirms save
signal action_confirmed(action_name) # Emitted when user confirms without save
signal action_cancelled # Emitted when user cancels

func setup(ui_nodes: Dictionary):
	# Ensure UIManager processes input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Expects a dictionary containing references to the UI nodes
	open_menu_button = ui_nodes.get("open_menu_button")
	modal_menu_panel = ui_nodes.get("modal_menu_panel")
	world_creation_panel = ui_nodes.get("world_creation_panel")
	load_button = ui_nodes.get("load_button") # Main modal load button
	confirmation_panel = ui_nodes.get("confirmation_panel")
	confirmation_label = ui_nodes.get("confirmation_label")
	confirm_save_button = ui_nodes.get("confirm_save_button")
	confirm_no_save_button = ui_nodes.get("confirm_no_save_button")
	confirm_cancel_button = ui_nodes.get("confirm_cancel_button")

	if not is_instance_valid(modal_menu_panel) or not is_instance_valid(confirmation_panel):
		push_error("UIManager: Critical panel references missing!")
		return # Stop setup if panels are missing

	# Initial state
	modal_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	modal_menu_panel.hide()
	# Connect modal panel input to handle ESC key
	if not modal_menu_panel.is_connected("gui_input", Callable(self, "_on_modal_gui_input")):
		modal_menu_panel.gui_input.connect(_on_modal_gui_input)
	if world_creation_panel:
		world_creation_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		world_creation_panel.hide()
	confirmation_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	confirmation_panel.hide()

	# Connect internal signals here
	_connect_confirmation_signals()


func _unhandled_input(event: InputEvent):
	# Handle ESC key even when game is paused
	if event.is_action_pressed("ui_cancel"):
		handle_escape()
		get_tree().root.set_input_as_handled()


func _connect_confirmation_signals():
	# Ensure the button variables are valid before connecting!
	if not is_instance_valid(confirm_save_button): push_error("UIManager: ConfirmSaveButton node invalid! Cannot connect."); return
	if not is_instance_valid(confirm_no_save_button): push_error("UIManager: ConfirmNoSaveButton node invalid! Cannot connect."); return
	if not is_instance_valid(confirm_cancel_button): push_error("UIManager: ConfirmCancelButton node invalid! Cannot connect."); return

	# Connect Save Button
	if not confirm_save_button.is_connected("pressed", Callable(self, "_on_confirm_save")):
		var err_save = confirm_save_button.pressed.connect(_on_confirm_save)
		if err_save != OK: push_error("UIManager: FAILED to connect confirm_save_button. Error: %d" % err_save)

	# Connect No Save Button
	if not confirm_no_save_button.is_connected("pressed", Callable(self, "_on_confirm_no_save")):
		var err_no_save = confirm_no_save_button.pressed.connect(_on_confirm_no_save)
		if err_no_save != OK: push_error("UIManager: FAILED to connect confirm_no_save_button. Error: %d" % err_no_save)

	# Connect Cancel Button
	if not confirm_cancel_button.is_connected("pressed", Callable(self, "_on_confirm_cancel")):
		var err_cancel = confirm_cancel_button.pressed.connect(_on_confirm_cancel)
		if err_cancel != OK: push_error("UIManager: FAILED to connect confirm_cancel_button. Error: %d" % err_cancel)


# --- Public Methods Called by game.gd or Signals ---

func open_main_modal():
	if not is_instance_valid(modal_menu_panel): push_error("UIManager: Cannot open modal, panel invalid!"); return
	confirmation_panel.hide() # Ensure confirmation is hidden
	modal_menu_panel.show()
	modal_menu_panel.z_index = 100  # Ensure modal is on top
	modal_menu_panel.move_to_front()  # Move to front of parent
	modal_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure it can receive input
	# Check save state to enable/disable load button
	if is_instance_valid(load_button):
		load_button.disabled = not SaveLoadManager.check_saves_exist()

	get_tree().paused = true
	if is_instance_valid(open_menu_button): open_menu_button.disabled = true


func open_world_creation_modal():
	if not is_instance_valid(world_creation_panel): 
		push_error("UIManager: Cannot open world creation modal, panel invalid!")
		return
	# Hide other modals and show world creation
	modal_menu_panel.hide()
	confirmation_panel.hide()
	world_creation_panel.show()

func close_world_creation_modal():
	if is_instance_valid(world_creation_panel):
		world_creation_panel.hide()

func close_main_modal():
	if not is_instance_valid(modal_menu_panel): return
	modal_menu_panel.hide()
	# Only unpause if the confirmation panel is also hidden
	if not confirmation_panel.visible:
		get_tree().paused = false
		if is_instance_valid(open_menu_button): open_menu_button.disabled = false


func request_main_menu():
	if not is_instance_valid(confirmation_panel) or not is_instance_valid(confirmation_label) \
	or not is_instance_valid(confirm_save_button) or not is_instance_valid(confirm_no_save_button):
		push_error("UIManager: Cannot request main menu, confirmation UI node(s) invalid!")
		return

	_pending_action = "main_menu"
	confirmation_label.text = "Return to Main Menu? Unsaved progress will be lost."
	confirm_save_button.text = "Save & Go to Menu"; confirm_no_save_button.text = "Go to Menu Without Saving"
	if is_instance_valid(modal_menu_panel): modal_menu_panel.hide()
	confirmation_panel.show()
	confirmation_panel.z_index = 101
	confirmation_panel.move_to_front()


func request_quit():
	if not is_instance_valid(confirmation_panel) or not is_instance_valid(confirmation_label) \
	or not is_instance_valid(confirm_save_button) or not is_instance_valid(confirm_no_save_button):
		push_error("UIManager: Cannot request quit, confirmation UI node(s) invalid!")
		return

	_pending_action = "quit"
	confirmation_label.text = "Quit game? Unsaved progress will be lost."
	confirm_save_button.text = "Save & Quit"; confirm_no_save_button.text = "Quit Without Saving"
	if is_instance_valid(modal_menu_panel): modal_menu_panel.hide()
	confirmation_panel.show()
	confirmation_panel.z_index = 101
	confirmation_panel.move_to_front()


# --- Internal Signal Handlers for Confirmation ---

func _on_confirm_save():
	if not is_instance_valid(confirmation_panel): return
	confirmation_panel.hide()
	emit_signal("save_requested", _pending_action)


func _on_confirm_no_save():
	if not is_instance_valid(confirmation_panel): return
	confirmation_panel.hide()
	emit_signal("action_confirmed", _pending_action)


func _on_confirm_cancel():
	if not is_instance_valid(confirmation_panel): return
	confirmation_panel.hide()
	_pending_action = ""
	open_main_modal() # Reopen main modal on cancel
	print("UIManager: Emitting 'action_cancelled' signal.") # DEBUG
	emit_signal("action_cancelled")


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


# Handle Esc key presses to toggle menu
func handle_escape():
	var modal_visible = is_instance_valid(modal_menu_panel) and (modal_menu_panel.visible or modal_menu_panel.is_visible_in_tree())
	var confirm_visible = is_instance_valid(confirmation_panel) and (confirmation_panel.visible or confirmation_panel.is_visible_in_tree())
	if confirm_visible:
		_on_confirm_cancel()
	elif modal_visible:
		close_main_modal()
	else: # If no modals are open, open the main one
		open_main_modal()

# Handle GUI input on modal panel (for direct ESC key handling)
func _on_modal_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.is_action("ui_cancel"):
		handle_escape()
		get_tree().root.set_input_as_handled()
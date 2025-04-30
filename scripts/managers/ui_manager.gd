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

var build_window: Window
var open_build_button: Button


# State
var _pending_action: String = "" # "quit", "main_menu"

# Constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main/main_menu_scene.tscn" # Keep consistent

# Signals for communication
signal save_requested(pending_action) # Emitted when user confirms save
signal action_confirmed(action_name) # Emitted when user confirms without save
signal action_cancelled # Emitted when user cancels

func setup(ui_nodes: Dictionary):
	print("UIManager: Setup started.")
	# Expects a dictionary containing references to the UI nodes
	open_menu_button = ui_nodes.get("open_menu_button")
	modal_menu_panel = ui_nodes.get("modal_menu_panel")
	load_button = ui_nodes.get("load_button") # Main modal load button
	confirmation_panel = ui_nodes.get("confirmation_panel")
	confirmation_label = ui_nodes.get("confirmation_label")
	confirm_save_button = ui_nodes.get("confirm_save_button")
	confirm_no_save_button = ui_nodes.get("confirm_no_save_button")
	confirm_cancel_button = ui_nodes.get("confirm_cancel_button")
	
	build_window = ui_nodes.get("build_window")
	open_build_button = ui_nodes.get("open_build_button")

	# --- DEBUG: Validate critical node references ---
	print("UIManager Setup: modal_menu_panel valid? ", is_instance_valid(modal_menu_panel))
	print("UIManager Setup: confirmation_panel valid? ", is_instance_valid(confirmation_panel))
	print("UIManager Setup: build_window valid? ", is_instance_valid(build_window))
	
	# --- END DEBUG ---

	if not is_instance_valid(modal_menu_panel) or not is_instance_valid(confirmation_panel):
		push_error("UIManager: Critical panel references missing!")
		return # Stop setup if panels are missing

	# Initial state
	modal_menu_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	modal_menu_panel.hide()
	confirmation_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	confirmation_panel.hide()
	build_window.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_window.hide()

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


func open_build_window():
	print("UIManager: open_build_window called.") # DEBUG
	if not is_instance_valid(build_window): push_error("UIManager: Cannot open build window, window invalid!"); return # DEBUG
	confirmation_panel.hide() # Ensure confirmation is hidden
	modal_menu_panel.hide()
	if not build_window.visible:
		build_window.show()
	else:
		build_window.hide()
		
		
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

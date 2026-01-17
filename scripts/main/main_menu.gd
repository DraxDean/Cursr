# scripts/main/main_menu.gd
extends Control

# Scene path constants
const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn" # Corrected Path
const WORLD_CREATION_SCENE_PATH = "res://scenes/main/world_creation_scene.tscn"

# Node References - Use explicit paths assuming standard setup
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	# Ensure SaveLoadManager is ready (Autoloads initialize before scene _ready)
	# We can now directly use it
	if SaveLoadManager == null:
		push_error("SaveLoadManager Autoload not found!")
		return

	# Connect signals
	if not is_instance_valid(continue_button): push_error("Node not found: VBoxContainer/ContinueButton"); return
	if not is_instance_valid(new_game_button): push_error("Node not found: VBoxContainer/NewGameButton"); return
	if not is_instance_valid(load_game_button): push_error("Node not found: VBoxContainer/LoadGameButton"); return
	if not is_instance_valid(quit_button): push_error("Node not found: VBoxContainer/QuitButton"); return

	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Enable/disable buttons based on save availability
	var saves_exist = SaveLoadManager.check_saves_exist()
	continue_button.disabled = not saves_exist
	load_game_button.disabled = not saves_exist
	
	if continue_button.disabled:
		continue_button.tooltip_text = "No saved games found."
	if load_game_button.disabled:
		load_game_button.tooltip_text = "No saved games found."


func _on_continue_pressed():
	print("Main Menu: Continuing from last save...")
	var most_recent_save = SaveLoadManager.get_most_recent_save()
	if most_recent_save.is_empty():
		push_warning("Continue pressed, but no save file found.")
		return
	
	GameManager.start_mode = "load"
	GameManager.load_file_path = most_recent_save
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK: push_error("Failed to change scene to %s. Error code: %d" % [GAME_SCENE_PATH, error])


func _on_new_game_pressed():
	print("Main Menu: Starting World Creation...")
	GameManager.start_mode = "world_creation"
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK: push_error("Failed to change scene to %s. Error code: %d" % [GAME_SCENE_PATH, error])


func _on_load_game_pressed():
	print("Main Menu: Loading Saved Game...")
	# We still need to select *which* game to load.
	# For now, let's keep the simple "load first save" behavior.
	# A proper implementation would go to a LoadScreen or trigger the in-game load modal.
	# For simplicity here, we just set GameManager state.
	# A better approach is needed later.

	# Find the first save path (inefficient, replace with load screen later)
	var first_save_path = ""
	var dir = DirAccess.open(SaveLoadManager.SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"):
				first_save_path = SaveLoadManager.SAVE_DIR.path_join(file_name); break
			file_name = dir.get_next()
		dir.list_dir_end()

	if first_save_path.is_empty():
		push_warning("Load Game pressed, but no save file found.")
		return

	GameManager.start_mode = "load"
	GameManager.load_file_path = first_save_path
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK: push_error("Failed to change scene to %s. Error code: %d" % [GAME_SCENE_PATH, error])


func _on_quit_pressed():
	print("Main Menu: Quitting application.")
	get_tree().quit()

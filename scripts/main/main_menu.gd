# scripts/main/main_menu.gd
extends Control

# Scene path constants
const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn" # Corrected Path

@onready var main_menu_panel = $MainMenuPanel
@onready var race_selection_modal = $RaceSelectionModal
@onready var race_name_label = $RaceSelectionModal/MarginContainer/ModalVBox/RaceNameLabel
@onready var race_sprite = $RaceSelectionModal/MarginContainer/ModalVBox/AspectRatioContainer/RaceSprite
@onready var race_details_label = $RaceSelectionModal/MarginContainer/ModalVBox/RaceDetailsLabel
@onready var choose_race_button = $RaceSelectionModal/MarginContainer/ModalVBox/ChooseRaceButton
# Node References - Use explicit paths assuming standard setup
@onready var new_game_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/QuitButton

# Example race data (replace with your actual data structure)
var races = [
	{
		"name": "Humans",
		"sprite_path": "res://assets/sprites/human_peon1.png",
		"details": "Versatile and adaptable, humans excel in many roles.",
		"id": "human"
	},
	{
		"name": "Elves",
		"sprite_path": "res://assets/sprites/human_peon1.png",
		"details": "Agile archers with ancient wisdom. Masters of the forests.",
		"id": "elf"
	}
]
var current_race_index = 0 # If you add next/prev buttons

func _ready():
	# Ensure SaveLoadManager is ready (Autoloads initialize before scene _ready)
	# We can now directly use it
	if SaveLoadManager == null:
		push_error("SaveLoadManager Autoload not found!")
		return

	# Connect signals
	
	if not is_instance_valid(new_game_button): push_error("Node not found: VBoxContainer/NewGameButton"); return
	if not is_instance_valid(load_game_button): push_error("Node not found: VBoxContainer/LoadGameButton"); return
	if not is_instance_valid(quit_button): push_error("Node not found: VBoxContainer/QuitButton"); return
	if not is_instance_valid(choose_race_button): push_error("Node not found: RaceSelectionModal/ModalVBox/ChooseRaceButton"); return

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	choose_race_button.pressed.connect(_on_choose_race_pressed)
	
	# Setup initial race display if needed immediately,
	# or wait until the modal is shown.
	_display_race(current_race_index)
	
	# Hide modal initially (can also be done in editor)
	race_selection_modal.hide()
	
	# Disable load button if no saves exist using SaveLoadManager
	load_game_button.disabled = not SaveLoadManager.check_saves_exist()
	if load_game_button.disabled:
		load_game_button.tooltip_text = "No saved games found."


func _on_new_game_pressed():
	print("New Game button pressed")
	# Hide the main menu buttons
	main_menu_panel.hide()
	# Show the race selection modal, centered
	race_selection_modal.popup_centered()
	# Ensure the first race is displayed correctly
	_display_race(current_race_index)

func _on_choose_race_pressed():
	var chosen_race_id = choose_race_button.get_meta("selected_race_id", "default_race")
	print("Starting new game with race: ", chosen_race_id)

	# Hide the modal
	race_selection_modal.hide()

	# --- Add your game start logic here ---
	# Example: Load the main game scene
	get_tree().change_scene_to_file("res://scenes/main/game_scene.tscn")
	# You'll likely want to pass the chosen_race_id to the next scene
	# (e.g., via a Singleton/Autoload or by configuring the loaded scene)

	# Optionally, bring back the main menu if game start fails or is cancelled
	# main_menu_panel.show()


func _display_race(index):
	if index >= 0 and index < races.size():
		var race_data = races[index]
		race_name_label.text = race_data["name"]
		race_details_label.text = race_data["details"] # Use .clear() and .append_text() or .parse_bbcode() for RichTextLabel
		race_sprite.texture = load(race_data["sprite_path"])
		# Store the chosen ID somewhere accessible when the button is pressed
		# e.g., on the button itself using metadata
		choose_race_button.set_meta("selected_race_id", race_data["id"])
	else:
		printerr("Invalid race index: ", index)

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

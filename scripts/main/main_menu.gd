extends Control

const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn"

@onready var main_menu_panel = $MainMenuPanel
@onready var map_creation_panel = $MapCreationPanel
@onready var create_map_size_x = $MapCreationPanel/VBoxContainer/SizePanel/VBoxContainer/HBoxContainer2/CreateMapSizeX
@onready var create_map_size_y = $MapCreationPanel/VBoxContainer/SizePanel/VBoxContainer/HBoxContainer3/CreateMapSizeY
@onready var cancel_create_map = $MapCreationPanel/VBoxContainer/HBoxContainer/CancelCreateMapButton
@onready var confirm_create_map = $MapCreationPanel/VBoxContainer/HBoxContainer/ConfirmCreateMapButton
@onready var race_selection_modal = $RaceSelectionModal
@onready var race_name_label = $RaceSelectionModal/MarginContainer/VBoxContainer/ModalVBox/RaceNameLabel
@onready var race_sprite = $RaceSelectionModal/MarginContainer/VBoxContainer/ModalVBox/AspectRatioContainer/RaceSprite
@onready var race_details_label = $RaceSelectionModal/MarginContainer/VBoxContainer/ModalVBox/MarginContainer/VBoxContainer/RaceDetailsLabel
@onready var choose_race_button = $RaceSelectionModal/MarginContainer/VBoxContainer/ModalVBox/MarginContainer/VBoxContainer/HBoxContainer/ChooseRaceButton
@onready var cancel_race_button = $RaceSelectionModal/MarginContainer/VBoxContainer/ModalVBox/MarginContainer/VBoxContainer/HBoxContainer/CancelRaceButton
@onready var new_game_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/QuitButton

var races = [
	{
		"name": "Humans",
		"sprite_path": "res://assets/sprites/human_peon1.png",
		"details": "Versatile and adaptable, humans excel in many roles. \n Uses wood and stone to make buildings on clear land.",
		"id": "human"
	},
	{
		"name": "Elves",
		"sprite_path": "res://assets/sprites/human_peon1.png",
		"details": "Agile archers with ancient wisdom. Masters of the forests.",
		"id": "elf"
	}
]
var current_race_index = 0 

func _ready():
	if SaveLoadManager == null:
		push_error("SaveLoadManager Autoload not found!")
		return
	
	if not is_instance_valid(new_game_button): push_error("Node not found: VBoxContainer/NewGameButton"); return
	if not is_instance_valid(load_game_button): push_error("Node not found: VBoxContainer/LoadGameButton"); return
	if not is_instance_valid(quit_button): push_error("Node not found: VBoxContainer/QuitButton"); return
	if not is_instance_valid(choose_race_button): push_error("Node not found: RaceSelectionModal/ModalVBox/ChooseRaceButton"); return

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	create_map_size_x.text_changed.connect(_on_create_map_size_x_text_changed)
	create_map_size_y.text_changed.connect(_on_create_map_size_y_text_changed)
	cancel_create_map.pressed.connect(_on_cancel_create_map_pressed)
	confirm_create_map.pressed.connect(_on_confirm_create_map_pressed)
	choose_race_button.pressed.connect(_on_choose_race_pressed)
	cancel_race_button.pressed.connect(_on_cancel_race_pressed)
	_display_race(current_race_index)
	
	race_selection_modal.hide()
	map_creation_panel.hide()
	
	load_game_button.disabled = not SaveLoadManager.check_saves_exist()
	if load_game_button.disabled:
		load_game_button.tooltip_text = "No saved games found."
		
func _on_create_map_size_x_text_changed(new_text):
	print("Create Map Size X changed:", new_text)
	
func _on_create_map_size_y_text_changed(new_text):
	print("Create Map Size Y changed:", new_text)
	
func _on_cancel_create_map_pressed():
	print("Cancel Create Map...")
	map_creation_panel.hide()
	main_menu_panel.show()
		
func _on_confirm_create_map_pressed():
	print("Confirm Create Map...")
	map_creation_panel.hide()
	race_selection_modal.show()

func _on_new_game_pressed():
	print("New Game button pressed")
	main_menu_panel.hide()
	map_creation_panel.show()

func _on_choose_race_pressed():
	var chosen_race_id = choose_race_button.get_meta("selected_race_id", "default_race")
	print("Selected Race: ", chosen_race_id)
	GameManager.selected_race = chosen_race_id
	race_selection_modal.hide()
	get_tree().change_scene_to_file("res://scenes/main/game_scene.tscn")
	
func _on_cancel_race_pressed():
	print("Cancel Chose Race")
	race_selection_modal.hide()
	map_creation_panel.show()

func _display_race(index):
	if index >= 0 and index < races.size():
		var race_data = races[index]
		race_name_label.text = race_data["name"]
		race_details_label.text = race_data["details"] 
		race_sprite.texture = load(race_data["sprite_path"])
		choose_race_button.set_meta("selected_race_id", race_data["id"])
	else:
		printerr("Invalid race index: ", index)

func _on_load_game_pressed():
	print("Main Menu: Loading Saved Game...")

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

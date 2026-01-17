# scripts/main/world_creation.gd
extends Control

# Scene path constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main/main_menu_scene.tscn"
const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn"

# Map dimensions
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# Node references
@onready var step_title: Label = $VBoxContainer/StepTitle
@onready var step_description: Label = $VBoxContainer/StepDescription
@onready var tilemap_layer: TileMapLayer = $VBoxContainer/MapPreview/TileMapLayer
@onready var camera: Camera2D = $VBoxContainer/MapPreview/Camera2D
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton
@onready var reset_camera_button: Button = $VBoxContainer/ButtonContainer/ResetCameraButton
@onready var reroll_button: Button = $VBoxContainer/ButtonContainer/RerollButton
@onready var continue_button: Button = $VBoxContainer/ButtonContainer/ContinueButton
@onready var start_game_button: Button = $VBoxContainer/ButtonContainer/StartGameButton

# World generation
const WorldGenerator = preload("res://scripts/world_gen/world_gen.gd")
var generator: WorldGenerator
var world_data: Dictionary = {}
var step_states: Array[Dictionary] = []  # Store state before each step for rerolling
var current_step: int = 0
var rng = RandomNumberGenerator.new()

# Camera control
var camera_controller: Node
var is_dragging: bool = false
var drag_start_pos: Vector2
var camera_start_pos: Vector2

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
	}
]

func _ready():
	print("WorldCreation: Ready")
	
	# Initialize RNG
	rng.randomize()
	generator = WorldGenerator.new()
	
	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	# Initialize tilemap and camera
	_setup_tilemap()
	_setup_camera()
	
	# Start with first step
	_show_current_step()

func _input(event):
	# Handle camera dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				camera_start_pos = camera.position
			else:
				is_dragging = false
		# Handle zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
	
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start_pos
		camera.position = camera_start_pos - delta / camera.zoom

func _setup_tilemap():
	# Load the same tileset as the main game
	if tilemap_layer and is_instance_valid(tilemap_layer):
		# Try to get tileset from project settings or create a basic one
		# For now, we'll assume the tilemap layer will use the same tileset as the game
		tilemap_layer.scale = Vector2(0.5, 0.5)  # Make it smaller for preview

func _setup_camera():
	if camera and is_instance_valid(camera):
		_reset_camera_to_default()
		print("Camera setup complete")

func _reset_camera_to_default():
	if camera and is_instance_valid(camera):
		# Set camera to origin
		camera.position = Vector2(0, 0)
		camera.zoom = Vector2(0.8, 0.8)  # Zoom out to see more of the map
		print("Camera reset to origin at: ", camera.position)

func _show_current_step():
	if current_step >= generation_steps.size():
		return
		
	var step_data = generation_steps[current_step]
	step_title.text = step_data["title"]
	step_description.text = step_data["description"]
	
	# Store current state before executing step (for rerolling)
	if current_step < step_states.size():
		# We're rerolling, restore previous state first
		world_data = step_states[current_step].duplicate(true)
	else:
		# Store state before new step
		step_states.append(world_data.duplicate(true))
	
	# Show/hide buttons based on step
	if current_step == 0:
		reroll_button.visible = false
	else:
		reroll_button.visible = true
		
	if current_step >= generation_steps.size() - 1:
		continue_button.visible = false
		start_game_button.visible = true
	else:
		continue_button.visible = true
		start_game_button.visible = false
	
	# Execute the step action
	call(step_data["action"])

func _step_void():
	"""Step 0: Show empty/black tiles"""
	world_data.clear()
	_clear_and_draw_map()

func _step_water():
	"""Step 1: Fill everything with ocean"""
	world_data.clear()
	generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()

func _step_land():
	"""Step 2: Generate continent"""
	if world_data.is_empty():
		generator._generate_base_ocean(MAP_WIDTH, MAP_HEIGHT, world_data)
	generator._generate_continent(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()

func _step_ice():
	"""Step 3: Add ice caps"""
	if world_data.is_empty():
		_step_land()  # Ensure we have land and water first
	generator._add_ice_caps(MAP_WIDTH, MAP_HEIGHT, world_data)
	_clear_and_draw_map()

func _step_mountains():
	"""Step 4: Add mountain patches"""
	if world_data.is_empty():
		_step_ice()  # Ensure previous steps are done
	# Add only mountains this step
	generator._place_patches(
		generator.NUM_MOUNTAIN_PATCHES,
		generator.MOUNTAIN_PATCH_RADIUS_MIN, 
		generator.MOUNTAIN_PATCH_RADIUS_MAX,
		generator.MOUNTAIN_COORDS,
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()

func _step_forests():
	"""Step 5: Add forest patches"""
	if world_data.is_empty():
		_step_mountains()  # Ensure previous steps are done
	# Add forests on both desert and mountains
	generator._place_patches(
		generator.NUM_FOREST_PATCHES,
		generator.FOREST_PATCH_RADIUS_MIN,
		generator.FOREST_PATCH_RADIUS_MAX, 
		generator.FOREST_COORDS,
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()

func _step_plains():
	"""Step 6: Add grassland patches"""
	if world_data.is_empty():
		_step_forests()  # Ensure previous steps are done
	# Convert some desert areas to grasslands
	generator._place_patches(
		generator.NUM_DESERT_PATCHES,
		generator.DESERT_PATCH_RADIUS_MIN,
		generator.DESERT_PATCH_RADIUS_MAX,
		generator.GRASS_COORDS, 
		MAP_WIDTH, MAP_HEIGHT, world_data
	)
	_clear_and_draw_map()

func _clear_and_draw_map():
	"""Draw the current world data to the preview tilemap"""
	if not is_instance_valid(tilemap_layer):
		return
		
	tilemap_layer.clear()
	
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) == TYPE_DICTIONARY and tile_info.has("source_id") and tile_info.has("atlas_coords"):
			tilemap_layer.set_cell(coords, tile_info["source_id"], tile_info["atlas_coords"])

func _on_back_pressed():
	print("WorldCreation: Going back to main menu")
	var error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error("Failed to change scene to main menu. Error code: %d" % error)

func _on_reset_camera_pressed():
	print("WorldCreation: Resetting camera view")
	_reset_camera_to_default()

func _on_reroll_pressed():
	print("WorldCreation: Rerolling step %d" % current_step)
	# Just regenerate the current step - _show_current_step handles state restoration
	_show_current_step()

func _on_continue_pressed():
	print("WorldCreation: Continuing to next step")
	current_step += 1
	# Don't store duplicate states when advancing
	if current_step < step_states.size():
		step_states.resize(current_step)  # Trim future states if we went back
	_show_current_step()

func _on_start_game_pressed():
	print("WorldCreation: Starting game with generated world")
	# Set up GameManager to use our generated world
	GameManager.start_mode = "new_with_data"
	GameManager.generated_world_data = world_data.duplicate()
	
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to change scene to game. Error code: %d" % error)
# scripts/main/world_creation_footer.gd
extends VBoxContainer

var back_button: Button
var reset_camera_button: Button
var reroll_button: Button
var continue_button: Button
var start_game_button: Button

# Signals for the modal to connect to
signal back_pressed
signal reset_camera_pressed
signal reroll_pressed
signal continue_pressed
signal start_game_pressed

func _ready():
	name = "WorldCreationFooter"
	# Position at bottom center
	var screen_size = get_viewport().get_visible_rect().size
	position = Vector2(200, screen_size.y - 80)
	size = Vector2(800, 60)
	mouse_filter = Control.MOUSE_FILTER_PASS  # Only buttons should capture clicks
	clip_contents = true  # Don't extend beyond our size
	
	_create_background()
	_create_content()

func _create_background():
	# Add semi-transparent background behind buttons only
	var footer_bg = ColorRect.new()
	footer_bg.color = Color(0, 0, 0, 0.7)
	footer_bg.position = Vector2(0, 0)  # Relative to container
	footer_bg.size = Vector2(800, 60)     # Match container size
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_bg)

func _create_content():
	# Add separator
	var separator = HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(separator)
	
	# Create button container
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Create buttons
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back to Menu"
	back_button.pressed.connect(_on_back_pressed)
	button_container.add_child(back_button)
	
	reset_camera_button = Button.new()
	reset_camera_button.name = "ResetCameraButton" 
	reset_camera_button.text = "Reset Camera"
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)
	button_container.add_child(reset_camera_button)
	
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.text = "Reroll Step"
	reroll_button.pressed.connect(_on_reroll_pressed)
	button_container.add_child(reroll_button)
	
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)
	
	start_game_button = Button.new()
	start_game_button.name = "StartGameButton"
	start_game_button.text = "Start Game"
	start_game_button.visible = false
	start_game_button.pressed.connect(_on_start_game_pressed)
	button_container.add_child(start_game_button)
	
	add_child(button_container)

func update_buttons_for_step(current_step: int, max_steps: int):
	if continue_button and start_game_button:
		if current_step >= max_steps - 1:
			continue_button.visible = false
			start_game_button.visible = true
		else:
			continue_button.visible = true
			start_game_button.visible = false

# Button signal handlers
func _on_back_pressed():
	back_pressed.emit()

func _on_reset_camera_pressed():
	reset_camera_pressed.emit()

func _on_reroll_pressed():
	reroll_pressed.emit()

func _on_continue_pressed():
	continue_pressed.emit()

func _on_start_game_pressed():
	start_game_pressed.emit()
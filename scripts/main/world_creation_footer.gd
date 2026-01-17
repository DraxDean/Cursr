# scripts/main/world_creation_footer.gd
extends Control

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
	
	# Create all content as children of this container
	_setup_footer_container()

func _setup_footer_container():
	# Add background as first child (behind everything) - use manual positioning
	var footer_bg = ColorRect.new()
	footer_bg.name = "FooterBackground"
	footer_bg.color = Color(0, 0, 0, 0.25)  # 25% opacity for better visibility
	footer_bg.position = Vector2(0, 0)
	footer_bg.size = Vector2(800, 60)  # Match footer size exactly
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_bg)
	
	# Create content container - positioned over background
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.position = Vector2(10, 5)  # Small padding from edges
	content_container.size = Vector2(780, 50)    # Slightly smaller than footer
	content_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content_container)
	
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
	
	content_container.add_child(button_container)

func update_buttons_for_step(current_step: int, max_steps: int):
	if continue_button and start_game_button:
		if current_step >= max_steps - 1:
			continue_button.visible = false
			start_game_button.visible = true
		else:
			continue_button.visible = true
			start_game_button.visible = false

func update_buttons(button_texts: Array):
	# Hide all buttons first
	if back_button: back_button.visible = false
	if reset_camera_button: reset_camera_button.visible = false
	if reroll_button: reroll_button.visible = false
	if continue_button: continue_button.visible = false
	if start_game_button: start_game_button.visible = false
	
	# Show and update buttons based on the provided texts
	for i in range(button_texts.size()):
		var text = button_texts[i]
		match text:
			"Back":
				if back_button:
					back_button.text = "Back"
					back_button.visible = true
			"Reset Camera":
				if reset_camera_button: reset_camera_button.visible = true
			"Reroll":
				if reroll_button: reroll_button.visible = true
			"Continue":
				if continue_button: continue_button.visible = true
			"Next":
				if continue_button:
					continue_button.text = "Next"
					continue_button.visible = true
			"Start Game":
				if start_game_button: start_game_button.visible = true

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
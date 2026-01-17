# scripts/main/world_creation_header.gd
extends VBoxContainer

var step_title: Label
var step_description: Label

func _ready():
	name = "WorldCreationHeader"
	position = Vector2(200, 20)  # Center horizontally
	size = Vector2(800, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	clip_contents = true  # Don't extend beyond our size
	
	_create_background()
	_create_content()

func _create_background():
	# Add semi-transparent background behind content only
	var header_bg = ColorRect.new()
	header_bg.color = Color(0, 0, 0, 0.0)  # Set opacity to 0 for testing
	header_bg.position = Vector2(0, 0)  # Relative to container
	header_bg.size = Vector2(800, 120)    # Match container size
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_bg)

func _create_content():
	# Create title
	step_title = Label.new()
	step_title.name = "StepTitle"
	step_title.text = "In the beginning..."
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_title.add_theme_font_size_override("font_size", 32)
	step_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(step_title)
	
	# Create description
	step_description = Label.new()
	step_description.name = "StepDescription" 
	step_description.text = "There was nothing but darkness and void..."
	step_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_description.add_theme_font_size_override("font_size", 18)
	step_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(step_description)

func update_step(title: String, description: String):
	if step_title:
		step_title.text = title
	if step_description:
		step_description.text = description
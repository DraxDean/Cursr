# scripts/main/world_creation_header.gd
extends Control

var step_title: Label
var step_description: Label

func _ready():
	name = "WorldCreationHeader"
	position = Vector2(200, 20)  # Center horizontally
	size = Vector2(800, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	clip_contents = true  # Don't extend beyond our size
	
	# Create all content as children of this container
	_setup_header_container()

func _setup_header_container():
	# Add background as first child (behind everything) - use manual positioning
	var header_bg = ColorRect.new()
	header_bg.name = "HeaderBackground"
	header_bg.color = Color(0, 0, 0, 0.25)  # 25% opacity for better visibility
	header_bg.position = Vector2(0, 0)
	header_bg.size = Vector2(800, 120)  # Match header size exactly
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_bg)
	
	# Create content container for text - positioned over background
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.position = Vector2(10, 10)  # Small padding from edges
	content_container.size = Vector2(780, 100)    # Slightly smaller than header
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_container)
	
	# Add title to content container
	step_title = Label.new()
	step_title.name = "StepTitle"
	step_title.text = "In the beginning..."
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_title.add_theme_font_size_override("font_size", 32)
	step_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.add_child(step_title)
	
	# Add description to content container
	step_description = Label.new()
	step_description.name = "StepDescription" 
	step_description.text = "There was nothing but darkness and void..."
	step_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_description.add_theme_font_size_override("font_size", 18)
	step_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.add_child(step_description)

func update_step(title: String, description: String):
	if step_title:
		step_title.text = title
	if step_description:
		step_description.text = description
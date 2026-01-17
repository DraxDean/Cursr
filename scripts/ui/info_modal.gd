# scripts/ui/info_modal.gd
extends Control

signal modal_closed(modal_type: String)

var modal_type: String = ""
var is_open: bool = false
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# UI Components
var background_panel: Panel
var title_label: Label
var close_button: Button
var content_container: VBoxContainer

func _init(type: String, title: String, start_position: Vector2 = Vector2.ZERO):
	modal_type = type
	name = type + "Modal"
	
	# Start hidden
	visible = false
	
	# Store custom position if provided
	if start_position != Vector2.ZERO:
		position = start_position
	
	_setup_ui(title)

func _ready():
	# Set modal size and position after being added to scene tree
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.33)
		size = custom_minimum_size
		# Only set default position if not already positioned
		if position == Vector2.ZERO:
			position = Vector2(10, 60)  # Left margin, below header
		
		# For build selection modal, make it larger to fit content
		if modal_type == "build_selection":
			custom_minimum_size = Vector2(viewport_size.x * 0.35, viewport_size.y * 0.5)
			size = custom_minimum_size

func _setup_ui(title: String):
	# Semi-transparent background panel
	background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create a StyleBox for semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)  # Semi-transparent black
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	background_panel.add_theme_stylebox_override("panel", style_box)
	add_child(background_panel)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Header container with title and close button (draggable area)
	var header_container = HBoxContainer.new()
	header_container.custom_minimum_size.y = 30
	header_container.mouse_filter = Control.MOUSE_FILTER_PASS
	main_container.add_child(header_container)
	
	# Title label (make it draggable)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Enable mouse input for dragging
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header_container.add_child(title_label)
	
	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.flat = false
	close_button.pressed.connect(_on_close_pressed)
	header_container.add_child(close_button)
	
	# Content container for modal-specific content
	content_container = VBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 5)
	main_container.add_child(content_container)
	
	# Add some padding
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is in header area (first 40 pixels)
				if event.position.y <= 40:
					is_dragging = true
					drag_offset = event.position
					move_to_front()  # Bring to front when starting drag
			else:
				is_dragging = false
	elif event is InputEventMouseMotion:
		if is_dragging:
			position += event.relative

func toggle():
	is_open = !is_open
	visible = is_open
	
	if is_open:
		# Bring to front when opened
		move_to_front()
		refresh_content()

func close_modal():
	is_open = false
	visible = false
	modal_closed.emit(modal_type)

func _on_close_pressed():
	close_modal()

# Override this in derived classes to populate content
func refresh_content():
	pass

# Helper function to add content to the modal
func add_content_child(child: Control):
	content_container.add_child(child)

func clear_content():
	for child in content_container.get_children():
		child.queue_free()
# scripts/managers/game_footer.gd
extends Control

# UI Components
var build_button: Button

# Signals for button presses
signal build_pressed

func _init():
	name = "GameFooter"
	
func _ready():
	_setup_footer()

func _setup_footer():
	# Set footer size and position (full width, bottom of screen)
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(viewport_size.x, 50)
		size = custom_minimum_size
		position = Vector2(0, viewport_size.y - 50)
	
	# Footer background
	var background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)  # Dark gray semi-transparent
	style_box.border_width_top = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	
	background_panel.add_theme_stylebox_override("panel", style_box)
	add_child(background_panel)
	
	# Left container for buttons
	var left_container = HBoxContainer.new()
	left_container.position = Vector2(10, 10)
	left_container.custom_minimum_size.y = 30
	left_container.add_theme_constant_override("separation", 10)
	add_child(left_container)
	
	# Build button
	build_button = Button.new()
	build_button.text = "Build"
	build_button.custom_minimum_size = Vector2(80, 30)
	build_button.flat = false
	build_button.pressed.connect(_on_build_pressed)
	left_container.add_child(build_button)

func _on_build_pressed():
	build_pressed.emit()
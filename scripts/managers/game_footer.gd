# scripts/managers/game_footer.gd
extends Control

# UI Components
var build_button: Button
var slow_button: Button
var pause_button: Button
var speedup_button: Button
var end_day_button: Button
var day_label: Label

# Signals for button presses
signal build_pressed
signal slow_pressed
signal pause_pressed
signal speedup_pressed
signal end_day_pressed

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
	
	# Main container to hold left and right sections
	var main_container = HBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	add_child(main_container)
	
	# Left container for build button
	var left_container = HBoxContainer.new()
	left_container.custom_minimum_size.y = 30
	left_container.add_theme_constant_override("separation", 10)
	main_container.add_child(left_container)
	
	# Build button
	build_button = Button.new()
	build_button.text = "Build"
	build_button.custom_minimum_size = Vector2(80, 30)
	build_button.flat = false
	build_button.pressed.connect(_on_build_pressed)
	left_container.add_child(build_button)
	
	# Spacer to push right controls to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(spacer)
	
	# Right container for end day controls
	var right_container = HBoxContainer.new()
	right_container.alignment = BoxContainer.ALIGNMENT_END
	right_container.custom_minimum_size.y = 30
	right_container.add_theme_constant_override("separation", 10)
	main_container.add_child(right_container)
	
	# Day counter label
	day_label = Label.new()
	day_label.text = "Day 1"
	day_label.custom_minimum_size = Vector2(80, 30)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_container.add_child(day_label)
	
	# Speed control buttons container
	var speed_controls = HBoxContainer.new()
	speed_controls.add_theme_constant_override("separation", 5)
	right_container.add_child(speed_controls)
	
	# Slow button
	slow_button = Button.new()
	slow_button.text = "<<"
	slow_button.custom_minimum_size = Vector2(40, 30)
	slow_button.flat = false
	slow_button.tooltip_text = "Slow Down"
	slow_button.pressed.connect(_on_slow_pressed)
	speed_controls.add_child(slow_button)
	
	# Pause/Resume button
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(40, 30)
	pause_button.flat = false
	pause_button.tooltip_text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	speed_controls.add_child(pause_button)
	
	# Speed up button
	speedup_button = Button.new()
	speedup_button.text = ">>"
	speedup_button.custom_minimum_size = Vector2(40, 30)
	speedup_button.flat = false
	speedup_button.tooltip_text = "Speed Up"
	speedup_button.pressed.connect(_on_speedup_pressed)
	speed_controls.add_child(speedup_button)
	
	# End day button
	end_day_button = Button.new()
	end_day_button.text = "End Day"
	end_day_button.custom_minimum_size = Vector2(100, 30)
	end_day_button.flat = false
	end_day_button.pressed.connect(_on_end_day_pressed)
	right_container.add_child(end_day_button)

func _on_build_pressed():
	build_pressed.emit()

func _on_slow_pressed():
	slow_pressed.emit()

func _on_pause_pressed():
	pause_pressed.emit()

func _on_speedup_pressed():
	speedup_pressed.emit()

func _on_end_day_pressed():
	end_day_pressed.emit()

func set_day_text(day: int):
	if day_label:
		day_label.text = "Day %d" % day
# scripts/managers/game_header.gd
extends Control

# UI Components
var players_button: Button
var units_button: Button
var resources_button: Button
var buildings_button: Button
var population_button: Button
var army_button: Button
var science_button: Button
var settings_button: Button
var encyclopedia_button: Button
var log_button: Button

# Signals for button presses
signal players_pressed
signal units_pressed
signal resources_pressed
signal buildings_pressed
signal population_pressed
signal army_pressed
signal science_pressed
signal settings_pressed
signal encyclopedia_pressed
signal log_pressed

func _ready():
	name = "GameHeader"
	# Position at top of screen
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	size.y = 60
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_setup_header_ui()

func _setup_header_ui():
	# Background
	var background = ColorRect.new()
	background.name = "HeaderBackground"
	background.color = Color(0.2, 0.2, 0.2, 0.9)  # Dark semi-transparent
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	# Main container
	var main_container = HBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	add_child(main_container)
	
	# Left side - info buttons
	var left_container = HBoxContainer.new()
	left_container.name = "LeftContainer"
	left_container.add_theme_constant_override("separation", 5)
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(left_container)
	
	# Add margin to left side
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(10, 0)
	left_container.add_child(left_margin)
	
	# Info buttons
	players_button = _create_info_button("Players")
	resources_button = _create_info_button("Resources")
	buildings_button = _create_info_button("Buildings")
	units_button = _create_info_button("Units")
	population_button = _create_info_button("Population")
	army_button = _create_info_button("Army")
	science_button = _create_info_button("🔬 Science")
	log_button = _create_info_button("📋 Log")

	left_container.add_child(players_button)
	left_container.add_child(resources_button)
	left_container.add_child(buildings_button)
	left_container.add_child(units_button)
	left_container.add_child(population_button)
	left_container.add_child(army_button)
	left_container.add_child(science_button)
	left_container.add_child(log_button)
	
	# Right side - settings button
	var right_container = HBoxContainer.new()
	right_container.name = "RightContainer"
	right_container.alignment = BoxContainer.ALIGNMENT_END
	main_container.add_child(right_container)
	
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "⚙ Settings"
	settings_button.custom_minimum_size = Vector2(120, 40)
	settings_button.pressed.connect(_on_settings_pressed)
	right_container.add_child(settings_button)

	encyclopedia_button = Button.new()
	encyclopedia_button.name = "EncyclopediaButton"
	encyclopedia_button.text = "?"
	encyclopedia_button.custom_minimum_size = Vector2(40, 40)
	encyclopedia_button.tooltip_text = "Encyclopedia — Browse game mechanics, buildings, jobs, and world objects."
	encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	right_container.add_child(encyclopedia_button)
	
	# Add margin to right side
	var right_margin = Control.new()
	right_margin.custom_minimum_size = Vector2(10, 0)
	right_container.add_child(right_margin)
	
	# Connect button signals
	players_button.pressed.connect(_on_players_pressed)
	units_button.pressed.connect(_on_units_pressed)
	resources_button.pressed.connect(_on_resources_pressed)
	buildings_button.pressed.connect(_on_buildings_pressed)
	population_button.pressed.connect(_on_population_pressed)
	army_button.pressed.connect(_on_army_pressed)
	science_button.pressed.connect(_on_science_pressed)
	log_button.pressed.connect(_on_log_pressed)

func _create_info_button(label_text: String) -> Button:
	var button = Button.new()
	button.name = label_text + "Button"
	button.custom_minimum_size = Vector2(100, 40)
	button.text = label_text
	button.flat = false
	return button

# Signal handlers
func _on_players_pressed():
	players_pressed.emit()

func _on_units_pressed():
	units_pressed.emit()

func _on_resources_pressed():
	resources_pressed.emit()

func _on_buildings_pressed():
	buildings_pressed.emit()

func _on_population_pressed():
	population_pressed.emit()

func _on_army_pressed():
	army_pressed.emit()

func _on_science_pressed():
	science_pressed.emit()

func _on_settings_pressed():
	settings_pressed.emit()

func _on_encyclopedia_pressed():
	encyclopedia_pressed.emit()

func _on_log_pressed():
	log_pressed.emit()
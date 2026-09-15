# scripts/managers/game_header.gd
extends Control

# Standardized button text style — shared with game_footer.gd so both bars match exactly
const BUTTON_FONT_SIZE: int = 14
const BUTTON_FONT_COLOR: Color = Color(1, 1, 1, 1)

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
var graphs_button: Button

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
signal graphs_pressed

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
	background.offset_bottom = -8   # Trims the visible bar to match the button row's real bottom padding
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	# Main container
	var main_container = HBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.offset_bottom = -8   # Padding at the bottom — buttons are flush-top, so this only
	main_container.add_theme_constant_override("separation", 0)  # bounds their container, doesn't move them
	add_child(main_container)
	
	# Left side - info buttons
	var left_container = HBoxContainer.new()
	left_container.name = "LeftContainer"
	left_container.add_theme_constant_override("separation", 5)
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(left_container)
	
	# Info buttons
	players_button = _create_info_button("Players", "👤")
	resources_button = _create_info_button("Resources", "📦")
	buildings_button = _create_info_button("Buildings", "🏛")
	units_button = _create_info_button("Units", "🧍")
	population_button = _create_info_button("Pop", "👥")
	army_button = _create_info_button("Army", "⚔")
	science_button = _create_info_button("Science", "🔬")
	log_button = _create_info_button("Log", "📋")
	graphs_button = _create_info_button("Graphs", "📊")

	left_container.add_child(players_button)
	left_container.add_child(resources_button)
	left_container.add_child(buildings_button)
	left_container.add_child(units_button)
	left_container.add_child(population_button)
	left_container.add_child(army_button)
	left_container.add_child(science_button)
	left_container.add_child(log_button)
	left_container.add_child(graphs_button)
	
	# Right side - settings button
	var right_container = HBoxContainer.new()
	right_container.name = "RightContainer"
	right_container.alignment = BoxContainer.ALIGNMENT_END
	main_container.add_child(right_container)
	
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.custom_minimum_size = Vector2(120, 48)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # Flush to the top, no top gap
	settings_button.pressed.connect(_on_settings_pressed)
	_set_button_content(settings_button, "⚙", "Settings")
	right_container.add_child(settings_button)

	encyclopedia_button = Button.new()
	encyclopedia_button.name = "EncyclopediaButton"
	encyclopedia_button.custom_minimum_size = Vector2(40, 48)
	encyclopedia_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # Flush to the top, no top gap
	encyclopedia_button.tooltip_text = "Encyclopedia — Browse game mechanics, buildings, jobs, and world objects."
	encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	_set_button_content(encyclopedia_button, "", "?")
	right_container.add_child(encyclopedia_button)
	
	# Connect button signals
	players_button.pressed.connect(_on_players_pressed)
	units_button.pressed.connect(_on_units_pressed)
	resources_button.pressed.connect(_on_resources_pressed)
	buildings_button.pressed.connect(_on_buildings_pressed)
	population_button.pressed.connect(_on_population_pressed)
	army_button.pressed.connect(_on_army_pressed)
	science_button.pressed.connect(_on_science_pressed)
	log_button.pressed.connect(_on_log_pressed)
	graphs_button.pressed.connect(_on_graphs_pressed)

func _create_info_button(label_text: String, icon: String = "") -> Button:
	var button = Button.new()
	button.name = label_text + "Button"
	button.custom_minimum_size = Vector2(100, 48)   # Matches the footer's actual (stretched) button height
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # Flush to the top, no top gap
	button.flat = false
	_set_button_content(button, icon, label_text)
	return button

func _set_button_content(button: Button, icon: String, label_text: String) -> void:
	"""Draw the button's icon+label via child Labels instead of Button.text. Emoji glyphs in
	Button.text inflate its computed minimum height regardless of font_size override — this
	keeps the button's own size locked to custom_minimum_size, matching the footer exactly."""
	button.clip_contents = true
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)

	if icon != "":
		var icon_lbl = Label.new()
		icon_lbl.text = icon
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		row.add_child(icon_lbl)

	var text_lbl = Label.new()
	text_lbl.text = label_text
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	text_lbl.add_theme_color_override("font_color", BUTTON_FONT_COLOR)
	row.add_child(text_lbl)

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

func _on_graphs_pressed():
	graphs_pressed.emit()

# scripts/ui/unit_view_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var current_unit: Dictionary = {}

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("unit_view", "Unit Details: ", start_position)

func display_unit(unit: Dictionary):
	"""Display details for a specific unit"""
	current_unit = unit
	# Update the title with the unit name
	title_label.text = "Unit Details: " + current_unit.get("name", "Unknown")
	refresh_content()

func refresh_content():
	clear_content()
	
	if current_unit.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No unit selected"
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(empty_label)
		fit_to_content()
		return
	
	# Title - Unit Details: (name)
	var title_label = Label.new()
	title_label.text = "Unit Details: " + current_unit.get("name", "Unknown")
	title_label.add_theme_color_override("font_color", Color.CYAN)
	title_label.add_theme_font_size_override("font_size", 18)
	add_content_child(title_label)
	
	# Type and Race on one line
	var type_race_label = Label.new()
	var race = current_unit.get("race", "unknown").to_lower()
	var unit_type = current_unit.get("type", "unknown").to_lower()
	type_race_label.text = "%s %s" % [race, unit_type]
	type_race_label.add_theme_color_override("font_color", Color.YELLOW)
	type_race_label.add_theme_font_size_override("font_size", 14)
	add_content_child(type_race_label)
	
	# Portrait and data container (horizontal layout)
	var main_container = HBoxContainer.new()
	add_content_child(main_container)
	
	# Character Portrait
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/portraits/human-portrait-male-peasant-brownhair.png")
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	portrait.custom_minimum_size = Vector2(120, 150)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(portrait)
	
	# Data fields container (right side)
	var data_container = VBoxContainer.new()
	main_container.add_child(data_container)
	
	# Job
	var job_container = HBoxContainer.new()
	data_container.add_child(job_container)
	var job_label = Label.new()
	job_label.text = "Job: "
	job_label.add_theme_color_override("font_color", Color.WHITE)
	job_label.custom_minimum_size = Vector2(80, 20)
	job_container.add_child(job_label)
	var job_value = Label.new()
	var job = current_unit.get("job", null)
	job_value.text = "Unemployed" if job == null else str(job)
	job_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	job_container.add_child(job_value)
	
	# Living Quarters
	var living_container = HBoxContainer.new()
	data_container.add_child(living_container)
	var living_label = Label.new()
	living_label.text = "Living: "
	living_label.add_theme_color_override("font_color", Color.WHITE)
	living_label.custom_minimum_size = Vector2(80, 20)
	living_container.add_child(living_label)
	var living_value = Label.new()
	var living_quarters = current_unit.get("living_quarters", null)
	living_value.text = "None" if living_quarters == null else str(living_quarters)
	living_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	living_container.add_child(living_value)
	
	# Speed Multiplier
	var speed_container = HBoxContainer.new()
	data_container.add_child(speed_container)
	var speed_label = Label.new()
	speed_label.text = "Speed: "
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.custom_minimum_size = Vector2(80, 20)
	speed_container.add_child(speed_label)
	var speed_value = Label.new()
	var speed_mult = current_unit.get("speed_multiplier", 1.0)
	var speed_percent = int(speed_mult * 100)
	speed_value.text = str(speed_percent) + "%"
	speed_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	speed_container.add_child(speed_value)
	
	# Unit ID (underneath everything)
	var id_container = HBoxContainer.new()
	add_content_child(id_container)
	var id_label = Label.new()
	id_label.text = "ID: "
	id_label.add_theme_color_override("font_color", Color.WHITE)
	id_label.custom_minimum_size = Vector2(60, 20)
	id_container.add_child(id_label)
	var id_value = Label.new()
	id_value.text = current_unit.get("unique_id", "unknown")
	id_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	id_container.add_child(id_value)
	
	fit_to_content()

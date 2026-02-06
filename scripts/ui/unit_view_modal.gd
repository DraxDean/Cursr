# scripts/ui/unit_view_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var current_unit: Dictionary = {}

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("unit_view", "Unit Details", start_position)

func display_unit(unit: Dictionary):
	"""Display details for a specific unit"""
	current_unit = unit
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
	
	# Title - Unit Name
	var name_label = Label.new()
	name_label.text = current_unit.get("name", "Unknown")
	name_label.add_theme_color_override("font_color", Color.CYAN)
	name_label.add_theme_font_size_override("font_size", 18)
	add_content_child(name_label)
	
	# Separator
	var separator1 = HSeparator.new()
	add_content_child(separator1)
	
	# Basic Information
	var basic_title = Label.new()
	basic_title.text = "Basic Information"
	basic_title.add_theme_color_override("font_color", Color.YELLOW)
	basic_title.add_theme_font_size_override("font_size", 14)
	add_content_child(basic_title)
	
	# Unit ID
	var id_container = HBoxContainer.new()
	add_content_child(id_container)
	var id_label = Label.new()
	id_label.text = "ID: "
	id_label.add_theme_color_override("font_color", Color.WHITE)
	id_label.custom_minimum_size = Vector2(80, 20)
	id_container.add_child(id_label)
	var id_value = Label.new()
	id_value.text = current_unit.get("unique_id", "unknown")
	id_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	id_container.add_child(id_value)
	
	# Type
	var type_container = HBoxContainer.new()
	add_content_child(type_container)
	var type_label = Label.new()
	type_label.text = "Type: "
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.custom_minimum_size = Vector2(80, 20)
	type_container.add_child(type_label)
	var type_value = Label.new()
	type_value.text = current_unit.get("type", "unknown")
	type_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	type_container.add_child(type_value)
	
	# Race
	var race_container = HBoxContainer.new()
	add_content_child(race_container)
	var race_label = Label.new()
	race_label.text = "Race: "
	race_label.add_theme_color_override("font_color", Color.WHITE)
	race_label.custom_minimum_size = Vector2(80, 20)
	race_container.add_child(race_label)
	var race_value = Label.new()
	race_value.text = current_unit.get("race", "unknown")
	race_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	race_container.add_child(race_value)
	
	# Separator
	var separator2 = HSeparator.new()
	add_content_child(separator2)
	
	# Assignment Information
	var assignment_title = Label.new()
	assignment_title.text = "Assignments"
	assignment_title.add_theme_color_override("font_color", Color.YELLOW)
	assignment_title.add_theme_font_size_override("font_size", 14)
	add_content_child(assignment_title)
	
	# Living Quarters
	var living_container = HBoxContainer.new()
	add_content_child(living_container)
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
	
	# Job
	var job_container = HBoxContainer.new()
	add_content_child(job_container)
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
	
	# Separator
	var separator3 = HSeparator.new()
	add_content_child(separator3)
	
	# Movement Information
	var movement_title = Label.new()
	movement_title.text = "Movement"
	movement_title.add_theme_color_override("font_color", Color.YELLOW)
	movement_title.add_theme_font_size_override("font_size", 14)
	add_content_child(movement_title)
	
	# Speed Multiplier
	var speed_container = HBoxContainer.new()
	add_content_child(speed_container)
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
	
	# Position
	var pos_container = HBoxContainer.new()
	add_content_child(pos_container)
	var pos_label = Label.new()
	pos_label.text = "Position: "
	pos_label.add_theme_color_override("font_color", Color.WHITE)
	pos_label.custom_minimum_size = Vector2(80, 20)
	pos_container.add_child(pos_label)
	var pos_value = Label.new()
	var position = current_unit.get("position", Vector2.ZERO)
	pos_value.text = "%.0f, %.0f" % [position.x, position.y]
	pos_value.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	pos_container.add_child(pos_value)
	
	fit_to_content()

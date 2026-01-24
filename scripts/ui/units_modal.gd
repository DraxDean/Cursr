# scripts/ui/units_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("units", "Units Overview", start_position)

func refresh_content():
	clear_content()
	
	# Title
	var header_label = Label.new()
	header_label.text = "Unit Management"
	header_label.add_theme_color_override("font_color", Color.CYAN)
	header_label.add_theme_font_size_override("font_size", 16)
	add_content_child(header_label)
	
	# Get all players' units
	var all_units = []
	for player_id in game_ref.players_data:
		if str(player_id) == "environment":
			continue
		var player_data = game_ref.players_data[player_id]
		if player_data.has("units"):
			for unit in player_data["units"]:
				all_units.append(unit)
	
	if all_units.is_empty():
		var no_units_label = Label.new()
		no_units_label.text = "No units found."
		no_units_label.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(no_units_label)
		fit_to_content()
		return
	
	# Create header row
	var header_container = HBoxContainer.new()
	add_content_child(header_container)
	
	_add_header_cell(header_container, "ID", 70)
	_add_header_cell(header_container, "Name", 90)
	_add_header_cell(header_container, "Type", 70)
	_add_header_cell(header_container, "Living", 90)
	_add_header_cell(header_container, "Job", 70)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Add unit rows
	for unit in all_units:
		var row_container = HBoxContainer.new()
		add_content_child(row_container)
		
		_add_unit_cell(row_container, unit.get("unique_id", "unknown"), 70)
		_add_unit_cell(row_container, unit.get("name", "unnamed"), 90)
		_add_unit_cell(row_container, unit.get("type", "unknown"), 70)
		
		var living_quarters = unit.get("living_quarters", null)
		var living_text = "None" if living_quarters == null else str(living_quarters)
		_add_unit_cell(row_container, living_text, 90)
		
		var job = unit.get("job", null)
		var job_text = "Unemployed" if job == null else str(job)
		_add_unit_cell(row_container, job_text, 70)
	
	# Add summary
	var summary_separator = HSeparator.new()
	add_content_child(summary_separator)
	
	var summary_label = Label.new()
	summary_label.text = "Total Units: " + str(all_units.size())
	summary_label.add_theme_color_override("font_color", Color.YELLOW)
	summary_label.add_theme_font_size_override("font_size", 12)
	add_content_child(summary_label)
	
	# Fit the modal to content
	fit_to_content()

func _add_header_cell(container: HBoxContainer, text: String, min_width: int):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(label)

func _add_unit_cell(container: HBoxContainer, text: String, min_width: int):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 20)
	label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(label)
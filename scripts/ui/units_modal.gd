# scripts/ui/units_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var unit_view_modal: Control = null

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
	
	_add_header_cell(header_container, "Name", 100)
	_add_header_cell(header_container, "Type", 70)
	_add_header_cell(header_container, "Living", 90)
	_add_header_cell(header_container, "Job", 70)
	_add_header_cell(header_container, "Speed", 60)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Add unit rows
	for unit in all_units:
		var row_container = HBoxContainer.new()
		add_content_child(row_container)
		
		# Make unit name clickable
		_add_clickable_unit_cell(row_container, unit.get("name", "unnamed"), unit, 100)
		_add_unit_cell(row_container, unit.get("type", "unknown"), 70)
		
		var living_quarters = unit.get("living_quarters", null)
		if living_quarters == null:
			_add_unit_cell(row_container, "None", 90)
		else:
			_add_clickable_building_cell(row_container, str(living_quarters), 90)
		
		var job = unit.get("job", null)
		if job == null:
			_add_unit_cell(row_container, "Unemployed", 70)
		else:
			_add_clickable_building_cell(row_container, str(job), 70)
		
		var speed_mult = unit.get("speed_multiplier", 1.0)
		var speed_percent = int(speed_mult * 100)
		_add_unit_cell(row_container, str(speed_percent) + "%", 60)
	
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
func _add_clickable_unit_cell(container: HBoxContainer, text: String, unit: Dictionary, min_width: int):
	"""Add a clickable unit name cell that opens the unit view modal"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 20)
	button.add_theme_color_override("font_color", Color.CYAN)
	button.add_theme_font_size_override("font_size", 11)
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Store the unit data in the button's metadata
	button.set_meta("unit_data", unit)
	button.pressed.connect(_on_unit_name_clicked.bindv([unit]))
	
	container.add_child(button)

func _on_unit_name_clicked(unit: Dictionary):
	"""Handle unit name click - open unit view modal"""
	print("Units Modal: Unit name clicked: %s" % unit.get("name", "unknown"))
	
	if not unit_view_modal:
		print("Units Modal: Creating new unit view modal...")
		unit_view_modal = preload("res://scripts/ui/unit_view_modal.gd").new(game_ref, position + Vector2(100, 100))
		print("Units Modal: Unit view modal created successfully")
		
		# Add to parent's parent (UI layer) so it's alongside other modals
		var parent = get_parent()
		if parent:
			parent.add_child(unit_view_modal)
			print("Units Modal: Unit view modal added to parent: %s" % parent.name)
		else:
			print("Units Modal: ERROR - No parent found!")
			return
	
	# Update the modal with the selected unit and show it
	if unit_view_modal.has_method("display_unit"):
		unit_view_modal.display_unit(unit)
		print("Units Modal: Unit details displayed for: %s" % unit.get("name", "unknown"))
	else:
		print("Units Modal: ERROR - unit_view_modal has no display_unit method!")
		return
	
	unit_view_modal.show()
	print("Units Modal: Unit view modal shown")
func _add_unit_cell(container: HBoxContainer, text: String, min_width: int):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 20)
	label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(label)

func _add_clickable_building_cell(container: HBoxContainer, building_name: String, min_width: int):
	"""Add a clickable building cell with icon"""
	# Create a sub-container for icon + name
	var building_container = HBoxContainer.new()
	building_container.custom_minimum_size = Vector2(min_width, 20)
	container.add_child(building_container)
	
	# Get building type and icon
	var building_type = _get_building_type_from_name(building_name)
	var icon = _get_building_icon(building_type)
	
	# Add icon
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size = Vector2(20, 20)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	building_container.add_child(icon_label)
	
	# Add clickable building name
	var button = Button.new()
	button.text = building_name
	button.custom_minimum_size = Vector2(50, 20)
	button.add_theme_color_override("font_color", Color.CYAN)
	button.add_theme_font_size_override("font_size", 11)
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Store building name in metadata for the click handler
	button.set_meta("building_name", building_name)
	button.pressed.connect(_on_building_clicked.bindv([building_name]))
	
	building_container.add_child(button)

func _on_building_clicked(building_name: String):
	"""Handle building click - open building details modal"""
	print("Units Modal: Building clicked: %s" % building_name)
	
	# Find the building node in the map
	if game_ref and game_ref.has_node("MapObjects"):
		var map_objects_holder = game_ref.get_node("MapObjects")
		var building = map_objects_holder.get_node_or_null(building_name)
		
		if building and game_ref.has_method("_open_building_details_modal"):
			game_ref._open_building_details_modal(building)
			print("Units Modal: Opened building details for: %s" % building_name)
		else:
			print("Units Modal: Could not find building '%s' or method not available" % building_name)
	else:
		print("Units Modal: Could not access map objects")

func _get_building_type_from_name(building_name: String) -> String:
	"""Extract the building type from the building name - use game_ref method if available"""
	if game_ref and game_ref.has_method("_extract_building_type_from_name"):
		return game_ref._extract_building_type_from_name(building_name)
	
	# Fallback implementation
	var building_types = ["fishing_hut", "town_center", "lumber_mill", "lumberjack", "stoneworker", "house", "barracks", "farm", "farmhouse"]
	for building_type in building_types:
		if building_name.contains(building_type):
			return building_type
	return "unknown_building"

func _get_building_icon(building_type: String) -> String:
	"""Get emoji icon for building type"""
	match building_type:
		"town_center":
			return "🏛️"
		"house":
			return "🏠"
		"barracks":
			return "⚔️"
		"fishing_hut":
			return "🎣"
		"farmhouse":
			return "🏘️"
		"farm":
			return "🌾"
		"lumberjack":
			return "🌲"
		"lumber_mill":
			return "🏭"
		"stoneworker":
			return "⛏️"
		_:
			return "🏗️"

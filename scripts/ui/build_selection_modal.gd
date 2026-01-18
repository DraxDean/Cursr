# scripts/ui/build_selection_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var building_grid: GridContainer
var selected_building: String = ""

signal building_selected(building_type: String, building_name: String)

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("build_selection", "Select Building", start_position)

func refresh_content():
	clear_content()
	
	var instruction_label = Label.new()
	instruction_label.text = "Choose a building to construct:"
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(instruction_label)
	
	# Create building grid similar to race selector
	building_grid = GridContainer.new()
	building_grid.columns = 2
	building_grid.add_theme_constant_override("h_separation", 10)
	building_grid.add_theme_constant_override("v_separation", 10)
	building_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(building_grid)
	
	# Available buildings
	var buildings = [
		{"type": "house", "name": "House", "icon": "res://assets/buildings/human_house.png"},
		{"type": "barracks", "name": "Barracks", "icon": "res://assets/buildings/human_barracks.png"},
		{"type": "fishing_hut", "name": "Fishing Hut", "icon": "res://assets/buildings/human_finshinghut.png"},
		{"type": "lumberjack", "name": "Lumberjack", "icon": "res://assets/buildings/human_lumberjack.png"},
		{"type": "stoneworker", "name": "Stoneworker", "icon": "res://assets/buildings/human_stoneworker.png"},
		{"type": "town_center", "name": "Town Center", "icon": "res://assets/buildings/human_towncentre-export.png"}
	]
	
	for building in buildings:
		_create_building_button(building)
	
	# Confirm button (initially disabled)
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(button_container)
	
	var confirm_button = Button.new()
	confirm_button.text = "Build Selected"
	confirm_button.disabled = true
	confirm_button.name = "ConfirmButton"
	confirm_button.custom_minimum_size = Vector2(120, 30)
	confirm_button.pressed.connect(_on_confirm_building)
	button_container.add_child(confirm_button)

func _create_building_button(building_data: Dictionary):
	var button_container = VBoxContainer.new()
	button_container.custom_minimum_size = Vector2(100, 120)
	building_grid.add_child(button_container)
	
	# Building image button
	var building_button = Button.new()
	building_button.custom_minimum_size = Vector2(80, 80)
	building_button.flat = false
	building_button.name = building_data["type"]
	
	# Load building texture if available
	if ResourceLoader.exists(building_data["icon"]):
		var texture = load(building_data["icon"])
		building_button.icon = texture
		building_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	building_button.pressed.connect(_on_building_selected.bind(building_data))
	button_container.add_child(building_button)
	
	# Building name label
	var name_label = Label.new()
	name_label.text = building_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 12)
	button_container.add_child(name_label)

func _on_building_selected(building_data: Dictionary):
	selected_building = building_data["type"]
	
	# Update visual selection (highlight selected button)
	for child in building_grid.get_children():
		if child is VBoxContainer:
			var button = child.get_child(0)
			if button.name == selected_building:
				button.modulate = Color.CYAN
			else:
				button.modulate = Color.WHITE
	
	# Enable confirm button - search through the content container
	_enable_confirm_button()
	
	print("Building selected: ", building_data["name"])

func _enable_confirm_button():
	# Find the confirm button in the content container
	for child in content_container.get_children():
		if child is HBoxContainer:
			for button_child in child.get_children():
				if button_child.name == "ConfirmButton":
					button_child.disabled = false
					return

func _on_confirm_building():
	if selected_building != "":
		# Get building name for display
		var building_name = ""
		var buildings = [
			{"type": "house", "name": "House"},
			{"type": "barracks", "name": "Barracks"},
			{"type": "fishing_hut", "name": "Fishing Hut"},
			{"type": "town_center", "name": "Town Center"}
		]
		
		for building in buildings:
			if building["type"] == selected_building:
				building_name = building["name"]
				break
		
		building_selected.emit(selected_building, building_name)
		close_modal()
# scripts/ui/build_selection_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var building_grid: GridContainer
var selected_building: String = ""
var selected_building_name: String = ""
var details_container: VBoxContainer
var build_more_mode: bool = false
var keep_modal_open: bool = false

signal building_selected(building_type: String, building_name: String)
signal place_building_confirmed(build_more: bool, building_type: String)

# Building data for easy lookup
var buildings_data = [
	{"type": "house", "name": "House", "icon": "res://assets/buildings/human_house.png"},
	{"type": "barracks", "name": "Barracks", "icon": "res://assets/buildings/human_barracks.png"},
	{"type": "fishing_hut", "name": "Fishing Hut", "icon": "res://assets/buildings/human_finshinghut.png"},
	{"type": "lumberjack", "name": "Lumberjack", "icon": "res://assets/buildings/human_lumberjack.png"},
	{"type": "stoneworker", "name": "Stoneworker", "icon": "res://assets/buildings/human_stoneworker.png"},
	{"type": "research", "name": "Research", "icon": "res://assets/buildings/human_research.png"},
	{"type": "town_center", "name": "Town Center", "icon": "res://assets/buildings/human_towncentre-export.png"},
	{"type": "farmhouse", "name": "Farmhouse", "icon": "res://assets/buildings/human_farmhouse.png"},
	{"type": "farm", "name": "Farm", "icon": "res://assets/buildings/human_farm_tilled.png"}
]

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("build_selection", "Build Structure", start_position)

func refresh_content():
	clear_content()
	
	# Create main horizontal layout: left (grid) and right (details)
	var main_container = HBoxContainer.new()
	main_container.add_theme_constant_override("separation", 20)
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.custom_minimum_size = Vector2(600, 400)
	add_content_child(main_container)
	
	# LEFT SIDE: Building Grid with Scroll
	var left_container = VBoxContainer.new()
	left_container.custom_minimum_size = Vector2(280, 400)
	left_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(left_container)
	
	var grid_label = Label.new()
	grid_label.text = "Available Buildings:"
	grid_label.add_theme_color_override("font_color", Color.WHITE)
	grid_label.add_theme_font_size_override("font_size", 12)
	left_container.add_child(grid_label)
	
	# Create scroll container for the building grid
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(280, 300)
	left_container.add_child(scroll_container)
	
	# Building grid inside scroll
	building_grid = GridContainer.new()
	building_grid.columns = 2
	building_grid.add_theme_constant_override("h_separation", 10)
	building_grid.add_theme_constant_override("v_separation", 10)
	building_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(building_grid)
	
	# Add building buttons to grid
	for building in buildings_data:
		_create_building_button(building)
	
	# RIGHT SIDE: Building Details
	details_container = VBoxContainer.new()
	details_container.custom_minimum_size = Vector2(280, 400)
	details_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_container.add_theme_constant_override("separation", 10)
	main_container.add_child(details_container)
	
	_refresh_details_panel()

func _refresh_details_panel():
	# Clear existing details
	for child in details_container.get_children():
		child.queue_free()
	
	if selected_building == "":
		# No building selected - show placeholder
		var placeholder = Label.new()
		placeholder.text = "Select a building\nto view details"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override("font_color", Color.GRAY)
		details_container.add_child(placeholder)
		return
	
	# Building name/title
	var title = Label.new()
	title.text = selected_building_name
	title.add_theme_color_override("font_color", Color.CYAN)
	title.add_theme_font_size_override("font_size", 14)
	details_container.add_child(title)
	
	# Building description
	var description = _get_building_description(selected_building)
	if description != "":
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_container.add_child(desc_label)
	
	# Resource costs section
	var costs_label = Label.new()
	costs_label.text = "Resource Requirements:"
	costs_label.add_theme_color_override("font_color", Color.WHITE)
	costs_label.add_theme_font_size_override("font_size", 11)
	details_container.add_child(costs_label)
	
	var costs = _get_building_costs(selected_building)
	
	for resource in costs:
		var cost_container = HBoxContainer.new()
		cost_container.add_theme_constant_override("separation", 10)
		details_container.add_child(cost_container)
		
		var resource_label = Label.new()
		resource_label.text = resource + ":"
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		resource_label.custom_minimum_size = Vector2(70, 0)
		cost_container.add_child(resource_label)
		
		var cost_amount = costs[resource]
		var available_amount = _get_available_resources(resource)
		
		var cost_display = Label.new()
		cost_display.text = str(available_amount) + "/" + str(cost_amount)
		
		# Color based on availability
		if available_amount >= cost_amount:
			cost_display.add_theme_color_override("font_color", Color.GREEN)
		else:
			cost_display.add_theme_color_override("font_color", Color.RED)
		
		cost_container.add_child(cost_display)
	
	# Add separator
	var separator = HSeparator.new()
	details_container.add_child(separator)
	
	# Build options (Build More and Keep Modal Open)
	var build_options_container = HBoxContainer.new()
	build_options_container.add_theme_constant_override("separation", 15)
	details_container.add_child(build_options_container)
	
	var build_more_checkbox = CheckBox.new()
	build_more_checkbox.text = "Build More"
	build_more_checkbox.button_pressed = build_more_mode
	build_more_checkbox.toggled.connect(_on_build_more_toggled)
	build_options_container.add_child(build_more_checkbox)
	
	var keep_modal_checkbox = CheckBox.new()
	keep_modal_checkbox.text = "Keep Open"
	keep_modal_checkbox.button_pressed = keep_modal_open
	keep_modal_checkbox.toggled.connect(_on_keep_modal_open_toggled)
	build_options_container.add_child(keep_modal_checkbox)
	
	# Spacer
	details_container.add_child(Control.new())
	
	# Action buttons
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	details_container.add_child(button_container)
	
	var place_button = Button.new()
	place_button.text = "Place Building"
	place_button.custom_minimum_size = Vector2(0, 30)
	place_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Check if player can afford the building
	var can_afford = _can_afford_building(selected_building)
	place_button.disabled = !can_afford
	
	if !can_afford:
		place_button.text = "Insufficient Resources"
	
	place_button.pressed.connect(_on_place_confirmed)
	button_container.add_child(place_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 30)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

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
	name_label.add_theme_font_size_override("font_size", 11)
	button_container.add_child(name_label)

func _on_building_selected(building_data: Dictionary):
	selected_building = building_data["type"]
	selected_building_name = building_data["name"]
	
	# Update visual selection
	for child in building_grid.get_children():
		if child is VBoxContainer:
			var button = child.get_child(0)
			if button.name == selected_building:
				button.modulate = Color.CYAN
			else:
				button.modulate = Color.WHITE
	
	# Refresh details panel
	_refresh_details_panel()
	
	print("Building selected: ", building_data["name"])

func _get_building_costs(btype: String) -> Dictionary:
	var costs = {
		"house": {"Wood": 10, "Stone": 5, "Labor": 100},
		"barracks": {"Wood": 10, "Stone": 5, "Labor": 120},
		"fishing_hut": {"Wood": 12, "Stone": 3, "Labor": 60},
		"lumberjack": {"Wood": 15, "Stone": 8, "Labor": 80},
		"stoneworker": {"Wood": 8, "Stone": 15, "Labor": 150},
		"research": {"Wood": 20, "Stone": 10, "Labor": 120},
		"town_center": {"Wood": 30, "Stone": 25, "Gold": 15, "Labor": 300},
		"farmhouse": {"Wood": 15},
		"farm": {"Wood": 10}
	}
	
	return costs.get(btype, {"Wood": 10, "Labor": 100})

func _get_building_description(btype: String) -> String:
	var descriptions = {
		"house": "Residential housing. Provides population capacity.",
		"barracks": "Military facility. Trains and houses military units.",
		"fishing_hut": "Harvests fish from nearby water. +5 food per worker.",
		"lumberjack": "Harvests wood from nearby forests. +1 wood per worker.",
		"stoneworker": "Quarries stone from nearby mountains. +1 stone per worker.",
		"research": "Advances civilization through research. +3 science per researcher.",
		"town_center": "Administrative center. Provides science production.",
		"farmhouse": "Agricultural center. Manages nearby food production.",
		"farm": "Food production field. Managed by farmhouse."
	}
	
	return descriptions.get(btype, "")

func _get_available_resources(resource: String) -> int:
	if not game_ref or not game_ref.players_data:
		return 0
	
	var player_id = 1
	var player_data = game_ref.players_data.get(player_id, {})
	var current_resources = player_data.get("resources", {})
	
	var resource_key = resource.to_lower()
	
	if resource_key == "labor":
		return 200  # Placeholder for labor
	
	return current_resources.get(resource_key, 0)

func _can_afford_building(btype: String) -> bool:
	var costs = _get_building_costs(btype)
	
	for resource in costs:
		if _get_available_resources(resource) < costs[resource]:
			return false
	
	return true

func _on_place_confirmed():
	place_building_confirmed.emit(build_more_mode, selected_building)
	# Also emit old signal for compatibility
	building_selected.emit(selected_building, selected_building_name)
	
	if not build_more_mode and not keep_modal_open:
		close_modal()
	else:
		# Reset selection for next building if in build more mode
		if build_more_mode:
			selected_building = ""
			selected_building_name = ""
			_refresh_details_panel()

func _on_build_more_toggled(pressed: bool):
	build_more_mode = pressed
	print("Build more mode: ", build_more_mode)

func _on_keep_modal_open_toggled(pressed: bool):
	keep_modal_open = pressed
	print("Keep modal open: ", keep_modal_open)

func _on_cancel_pressed():
	close_modal()
# scripts/ui/building_placement_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var building_type: String
var building_name: String
var build_more_mode: bool = false  # Track if user wants to keep building

signal place_building_confirmed(build_more: bool)
signal placement_cancelled

func _init(game_reference: Node, btype: String, bname: String, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	building_type = btype
	building_name = bname
	super("building_placement", "Place " + bname, start_position)

func refresh_content():
	clear_content()
	
	# Building info
	var info_label = Label.new()
	info_label.text = "Placing: " + building_name
	info_label.add_theme_color_override("font_color", Color.CYAN)
	info_label.add_theme_font_size_override("font_size", 14)
	add_content_child(info_label)
	
	# Building image (if available)
	var icon_path = _get_building_icon(building_type)
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(icon_path)
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		add_content_child(texture_rect)
	
	# Resource costs
	var costs_label = Label.new()
	costs_label.text = "Resource Requirements:"
	costs_label.add_theme_color_override("font_color", Color.WHITE)
	costs_label.add_theme_font_size_override("font_size", 12)
	add_content_child(costs_label)
	
	# Get building costs
	var costs = _get_building_costs(building_type)
	
	for resource in costs:
		var cost_container = HBoxContainer.new()
		add_content_child(cost_container)
		
		var resource_label = Label.new()
		resource_label.text = resource + ": "
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		resource_label.custom_minimum_size = Vector2(60, 20)
		cost_container.add_child(resource_label)
		
		var cost_amount = costs[resource]
		var available_amount = _get_available_resources(resource)
		
		var cost_label = Label.new()
		cost_label.text = str(available_amount) + "/" + str(cost_amount)
		
		# Color code based on availability
		if available_amount >= cost_amount:
			cost_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			cost_label.add_theme_color_override("font_color", Color.RED)
		
		cost_container.add_child(cost_label)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Build More checkbox
	var build_more_container = HBoxContainer.new()
	add_content_child(build_more_container)
	
	var build_more_checkbox = CheckBox.new()
	build_more_checkbox.text = "Build More"
	build_more_checkbox.button_pressed = build_more_mode
	build_more_checkbox.toggled.connect(_on_build_more_toggled)
	build_more_container.add_child(build_more_checkbox)
	
	var build_more_label = Label.new()
	build_more_label.text = "Keep modal open after building"
	build_more_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	build_more_label.add_theme_font_size_override("font_size", 10)
	build_more_container.add_child(build_more_label)
	
	# Action buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	add_content_child(button_container)
	
	var place_button = Button.new()
	place_button.text = "Place Building"
	place_button.custom_minimum_size = Vector2(100, 30)
	
	# Check if player can afford the building
	var can_afford = _can_afford_building(building_type)
	place_button.disabled = !can_afford
	
	if !can_afford:
		place_button.text = "Insufficient Resources"
	
	place_button.pressed.connect(_on_place_confirmed)
	button_container.add_child(place_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(80, 30)
	cancel_button.pressed.connect(_on_placement_cancelled)
	button_container.add_child(cancel_button)

func _get_building_costs(btype: String) -> Dictionary:
	# Define building costs (Labor = days of work)
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

func _get_building_icon(building_type: String) -> String:
	# Return appropriate icon path for building type
	var building_icons = {
		"house": "res://assets/buildings/human_house.png",
		"barracks": "res://assets/buildings/human_barracks.png",
		"fishing_hut": "res://assets/buildings/human_finshinghut.png",
		"lumberjack": "res://assets/buildings/human_lumberjack.png",
		"stoneworker": "res://assets/buildings/human_stoneworker.png",
		"research": "res://assets/buildings/human_research.png",
		"town_center": "res://assets/buildings/human_towncentre-export.png",
		"farmhouse": "res://assets/buildings/human_farmhouse.png",
		"farm": "res://assets/buildings/human_farm_tilled.png"  # Default farm state
	}
	return building_icons.get(building_type, "")

func _get_available_resources(resource: String) -> int:
	# Get actual resources from game
	if not game_ref or not game_ref.players_data:
		return 0
	
	var player_id = 1  # Assuming player 1
	var player_data = game_ref.players_data.get(player_id, {})
	var current_resources = player_data.get("resources", {})
	
	# Normalize resource name to lowercase for lookup
	var resource_key = resource.to_lower()
	
	# Special case for "labor" which might not be in resources
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
	place_building_confirmed.emit(build_more_mode)
	# Only close modal if not in build more mode
	if not build_more_mode:
		close_modal()

func _on_build_more_toggled(pressed: bool):
	build_more_mode = pressed
	DebugConfig.dprint("ui", ["Build more mode: ", build_more_mode])

func _on_placement_cancelled():
	placement_cancelled.emit()
	close_modal()
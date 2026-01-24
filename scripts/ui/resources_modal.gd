# scripts/ui/resources_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("resources", "Resources", start_position)

func refresh_content():
	clear_content()
	
	# Ensure resource rates are calculated before displaying
	var player_id = 1
	if game_ref and game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(player_id)
	
	var resources_label = Label.new()
	resources_label.text = "Available Resources:"
	resources_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(resources_label)
	
	# Get current player (for now, assume player 1)
	var player_data = game_ref.players_data.get(player_id, {}) if game_ref else {}
	var current_resources = player_data.get("resources", {})
	
	# Define resource info with proper order and colors
	var resources_info = [
		{"key": "food", "name": "Food", "color": Color.YELLOW},
		{"key": "wood", "name": "Wood", "color": Color.GREEN},
		{"key": "stone", "name": "Stone", "color": Color.GRAY},
		{"key": "gold", "name": "Gold", "color": Color.GOLD}
	]
	
	for res_info in resources_info:
		var amount = current_resources.get(res_info["key"], 0)
		
		var resource_container = HBoxContainer.new()
		add_content_child(resource_container)
		
		var resource_icon = Label.new()
		resource_icon.text = "●"
		resource_icon.add_theme_color_override("font_color", res_info["color"])
		resource_icon.custom_minimum_size = Vector2(20, 20)
		resource_container.add_child(resource_icon)
		
		var resource_label = Label.new()
		resource_label.text = res_info["name"] + ": " + str(amount)
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_container.add_child(resource_label)
	
	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 5)
	add_content_child(separator)
	
	# Resource rates per day
	var rates_label = Label.new()
	rates_label.text = "Per Day Production/Consumption:"
	rates_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	add_content_child(rates_label)
	
	# Get resource rates
	var resource_rates = {}
	if game_ref and game_ref.has_method("get_resource_rates"):
		resource_rates = game_ref.get_resource_rates(player_id)
	
	# Display rates for each resource
	for res_info in resources_info:
		var rate = resource_rates.get(res_info["key"], 0)
		if rate != 0:  # Only show resources with non-zero rates
			var rate_container = HBoxContainer.new()
			add_content_child(rate_container)
			
			var rate_icon = Label.new()
			rate_icon.text = "→"
			var rate_color = Color.GREEN if rate > 0 else Color.RED
			rate_icon.add_theme_color_override("font_color", rate_color)
			rate_icon.custom_minimum_size = Vector2(20, 20)
			rate_container.add_child(rate_icon)
			
			var rate_label = Label.new()
			var rate_text = "%s%d %s/day" % ["+" if rate > 0 else "", rate, res_info["name"]]
			rate_label.text = rate_text
			rate_label.add_theme_color_override("font_color", rate_color)
			rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rate_container.add_child(rate_label)
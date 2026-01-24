# scripts/ui/resources_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("resources", "Resources", start_position)

func refresh_content():
	clear_content()
	
	# Clear footer and add day/end turn controls
	for child in footer_container.get_children():
		child.queue_free()
	
	# Ensure resource rates are calculated before displaying
	var player_id = 1
	if game_ref and game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(player_id)
	
	# Get current player (for now, assume player 1)
	var player_data = game_ref.players_data.get(player_id, {}) if game_ref else {}
	var current_resources = player_data.get("resources", {})
	
	# Get resource rates
	var resource_rates = {}
	if game_ref and game_ref.has_method("get_resource_rates"):
		resource_rates = game_ref.get_resource_rates(player_id)
	
	# Define resource info with proper order and colors
	var resources_info = [
		{"key": "food", "name": "Food", "color": Color.YELLOW},
		{"key": "wood", "name": "Wood", "color": Color.GREEN},
		{"key": "stone", "name": "Stone", "color": Color.GRAY},
		{"key": "gold", "name": "Gold", "color": Color.GOLD}
	]
	
	# Display combined resources and rates
	for res_info in resources_info:
		var amount = current_resources.get(res_info["key"], 0)
		var rate = resource_rates.get(res_info["key"], 0)
		
		var resource_container = HBoxContainer.new()
		add_content_child(resource_container)
		
		var resource_icon = Label.new()
		resource_icon.text = "●"
		resource_icon.add_theme_color_override("font_color", res_info["color"])
		resource_icon.custom_minimum_size = Vector2(20, 20)
		resource_container.add_child(resource_icon)
		
		var resource_label = Label.new()
		var label_text = res_info["name"] + ": " + str(amount)
		
		# Add rate in parentheses if there's production/consumption
		if rate != 0:
			var rate_text = "%s%d" % ["+" if rate > 0 else "", rate]
			label_text += " (" + rate_text + ")"
		
		resource_label.text = label_text
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_container.add_child(resource_label)
# scripts/ui/resources_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("resources", "Resources", start_position)

func refresh_content():
	clear_content()
	
	var resources_label = Label.new()
	resources_label.text = "Available Resources:"
	resources_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(resources_label)
	
	# Resource list (placeholder values for now)
	var resources = [
		{"name": "Wood", "amount": 150, "color": Color.GREEN},
		{"name": "Stone", "amount": 75, "color": Color.GRAY},
		{"name": "Food", "amount": 200, "color": Color.YELLOW},
		{"name": "Gold", "amount": 50, "color": Color.GOLD}
	]
	
	for resource in resources:
		var resource_container = HBoxContainer.new()
		add_content_child(resource_container)
		
		var resource_icon = Label.new()
		resource_icon.text = "●"
		resource_icon.add_theme_color_override("font_color", resource["color"])
		resource_icon.custom_minimum_size = Vector2(20, 20)
		resource_container.add_child(resource_icon)
		
		var resource_label = Label.new()
		resource_label.text = resource["name"] + ": " + str(resource["amount"])
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_container.add_child(resource_label)
	
	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 5)
	add_content_child(separator)
	
	# Resource income (placeholder)
	var income_label = Label.new()
	income_label.text = "Daily Income:"
	income_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	add_content_child(income_label)
	
	var income_info = Label.new()
	income_info.text = "+5 Food, +2 Wood per turn"
	income_info.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	add_content_child(income_info)
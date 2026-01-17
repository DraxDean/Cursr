# scripts/ui/population_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("population", "Population", start_position)

func refresh_content():
	clear_content()
	
	var pop_label = Label.new()
	pop_label.text = "Population Overview:"
	pop_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(pop_label)
	
	# Population stats (placeholder values calculated from buildings)
	var building_count = 0
	if game_ref and game_ref.map_objects_holder:
		for child in game_ref.map_objects_holder.get_children():
			if child.name.begins_with("TownCenter_") or child.name.contains("Building_"):
				building_count += 1
	
	var population = building_count * 10  # 10 people per building as placeholder
	
	var total_container = HBoxContainer.new()
	add_content_child(total_container)
	
	var pop_icon = Label.new()
	pop_icon.text = "👥"
	pop_icon.custom_minimum_size = Vector2(25, 20)
	total_container.add_child(pop_icon)
	
	var total_pop = Label.new()
	total_pop.text = "Total Population: " + str(population)
	total_pop.add_theme_color_override("font_color", Color.CYAN)
	total_container.add_child(total_pop)
	
	# Population breakdown
	var breakdown_label = Label.new()
	breakdown_label.text = "Population Breakdown:"
	breakdown_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	add_content_child(breakdown_label)
	
	var categories = [
		{"name": "Workers", "count": int(population * 0.6), "color": Color.GREEN},
		{"name": "Military", "count": int(population * 0.2), "color": Color.RED},
		{"name": "Children", "count": int(population * 0.15), "color": Color.YELLOW},
		{"name": "Elders", "count": int(population * 0.05), "color": Color.GRAY}
	]
	
	for category in categories:
		var cat_container = HBoxContainer.new()
		add_content_child(cat_container)
		
		var cat_icon = Label.new()
		cat_icon.text = "●"
		cat_icon.add_theme_color_override("font_color", category["color"])
		cat_icon.custom_minimum_size = Vector2(20, 20)
		cat_container.add_child(cat_icon)
		
		var cat_label = Label.new()
		cat_label.text = category["name"] + ": " + str(category["count"])
		cat_label.add_theme_color_override("font_color", Color.WHITE)
		cat_container.add_child(cat_label)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Population growth
	var growth_label = Label.new()
	growth_label.text = "Growth Rate: +2% per turn"
	growth_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	add_content_child(growth_label)
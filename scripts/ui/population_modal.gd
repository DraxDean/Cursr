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
	
	# Get actual player population data
	var population = 0
	var housed = 0
	var unhoused = 0
	var working = 0
	var unemployed = 0
	
	if game_ref and game_ref.has_method("get_player_population_data"):
		var pop_data = game_ref.get_player_population_data(1)  # Player 1
		if not pop_data.is_empty():
			population = pop_data.get("total", 30)
			housed = pop_data.get("housed", 0)
			unhoused = pop_data.get("unhoused", 30)
			working = pop_data.get("working", 0)
			unemployed = pop_data.get("unemployed", 30)
	
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
	
	# Population breakdown with actual data
	var breakdown_label = Label.new()
	breakdown_label.text = "Population Status:"
	breakdown_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	add_content_child(breakdown_label)
	
	var categories = [
		{"name": "Housed", "count": housed, "color": Color.GREEN},
		{"name": "Unhoused", "count": unhoused, "color": Color.ORANGE},
		{"name": "Working", "count": working, "color": Color.BLUE},
		{"name": "Unemployed", "count": unemployed, "color": Color.GRAY}
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
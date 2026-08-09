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
	
	# Calculate turns until +1 population is gained
	var growth_accumulator = 0.0
	var turns_for_one = 0
	if game_ref and game_ref.has_method("get_player_population_data"):
		var pop_data = game_ref.get_player_population_data(1)
		if not pop_data.is_empty():
			growth_accumulator = pop_data.get("growth_accumulator", 0.0)
	
	# Calculate how many turns until next population increase
	var growth_rate = 0.01  # 1% of population per turn
	if population > 0:
		var daily_growth = population * growth_rate
		if daily_growth > 0:
			turns_for_one = int(ceil((1.0 - growth_accumulator) / daily_growth))
	
	var total_pop = Label.new()
	var pop_text = "Population: " + str(population)
	if turns_for_one > 0:
		pop_text += " (+1 in " + str(turns_for_one) + " turn" + ("s" if turns_for_one != 1 else "") + ")"
	total_pop.text = pop_text
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
	
	# Growth rate field
	var growth_label = Label.new()
	growth_label.text = "Growth Rate: " + str(growth_rate)
	growth_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	add_content_child(growth_label)
	
	# --- Unit Roster by Type ---
	var sep2 = HSeparator.new()
	add_content_child(sep2)
	
	var roster_header = Label.new()
	roster_header.text = "Unit Roster:"
	roster_header.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(roster_header)
	
	# Count units by type
	var type_counts: Dictionary = {}
	var training_count := 0
	if game_ref and game_ref.get("players_data") != null:
		for unit in game_ref.players_data.get(1, {}).get("units", []):
			var utype = unit.get("type", "peasant")
			type_counts[utype] = type_counts.get(utype, 0) + 1
			if unit.get("training") != null:
				training_count += 1
	
	var type_icons := {
		"peasant": "🧑",
		"soldier": "⚔️",
		"scholar": "📚"
	}
	var type_colors := {
		"peasant": Color.LIGHT_GRAY,
		"soldier": Color.CRIMSON,
		"scholar": Color.CORNFLOWER_BLUE
	}
	
	if type_counts.is_empty():
		var no_units = Label.new()
		no_units.text = "No units"
		no_units.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(no_units)
	else:
		for utype in type_counts:
			var row = HBoxContainer.new()
			add_content_child(row)
			var icon = Label.new()
			icon.text = type_icons.get(utype, "👤")
			icon.custom_minimum_size = Vector2(25, 20)
			row.add_child(icon)
			var lbl = Label.new()
			lbl.text = "%s: %d" % [utype.capitalize(), type_counts[utype]]
			lbl.add_theme_color_override("font_color", type_colors.get(utype, Color.WHITE))
			row.add_child(lbl)
	
	if training_count > 0:
		var train_row = HBoxContainer.new()
		add_content_child(train_row)
		var t_icon = Label.new()
		t_icon.text = "🎓"
		t_icon.custom_minimum_size = Vector2(25, 20)
		train_row.add_child(t_icon)
		var t_lbl = Label.new()
		t_lbl.text = "In Training: %d" % training_count
		t_lbl.add_theme_color_override("font_color", Color.CYAN)
		train_row.add_child(t_lbl)
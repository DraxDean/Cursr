# scripts/ui/army_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("army", "Army", start_position)

func refresh_content():
	clear_content()
	
	var army_label = Label.new()
	army_label.text = "Military Forces:"
	army_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(army_label)
	
	# Count military buildings to determine army size
	var barracks_count = 0
	if game_ref and game_ref.map_objects_holder:
		for child in game_ref.map_objects_holder.get_children():
			if child.name.contains("Barracks"):
				barracks_count += 1
	
	var army_size = barracks_count * 5  # 5 soldiers per barracks
	
	var total_container = HBoxContainer.new()
	add_content_child(total_container)
	
	var army_icon = Label.new()
	army_icon.text = "⚔️"
	army_icon.custom_minimum_size = Vector2(25, 20)
	total_container.add_child(army_icon)
	
	var total_army = Label.new()
	total_army.text = "Total Forces: " + str(army_size)
	total_army.add_theme_color_override("font_color", Color.RED)
	total_container.add_child(total_army)
	
	if army_size == 0:
		var no_army = Label.new()
		no_army.text = "No military units trained yet"
		no_army.add_theme_color_override("font_color", Color.GRAY)
		add_content_child(no_army)
		
		var recruit_info = Label.new()
		recruit_info.text = "Build barracks to train soldiers"
		recruit_info.add_theme_color_override("font_color", Color.YELLOW)
		add_content_child(recruit_info)
	else:
		# Army breakdown
		var breakdown_label = Label.new()
		breakdown_label.text = "Unit Composition:"
		breakdown_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		add_content_child(breakdown_label)
		
		var units = [
			{"name": "Infantry", "count": int(army_size * 0.6), "color": Color.GREEN},
			{"name": "Archers", "count": int(army_size * 0.3), "color": Color.BLUE},
			{"name": "Cavalry", "count": int(army_size * 0.1), "color": Color.PURPLE}
		]
		
		for unit in units:
			if unit["count"] > 0:
				var unit_container = HBoxContainer.new()
				add_content_child(unit_container)
				
				var unit_icon = Label.new()
				unit_icon.text = "●"
				unit_icon.add_theme_color_override("font_color", unit["color"])
				unit_icon.custom_minimum_size = Vector2(20, 20)
				unit_container.add_child(unit_icon)
				
				var unit_label = Label.new()
				unit_label.text = unit["name"] + ": " + str(unit["count"])
				unit_label.add_theme_color_override("font_color", Color.WHITE)
				unit_container.add_child(unit_label)
	
	# Add separator
	var separator = HSeparator.new()
	add_content_child(separator)
	
	# Military strength
	var strength_label = Label.new()
	strength_label.text = "Military Strength: " + _get_strength_rating(army_size)
	strength_label.add_theme_color_override("font_color", _get_strength_color(army_size))
	add_content_child(strength_label)

func _get_strength_rating(army_size: int) -> String:
	if army_size == 0:
		return "Defenseless"
	elif army_size <= 5:
		return "Weak"
	elif army_size <= 15:
		return "Moderate"
	elif army_size <= 30:
		return "Strong"
	else:
		return "Mighty"

func _get_strength_color(army_size: int) -> Color:
	if army_size == 0:
		return Color.GRAY
	elif army_size <= 5:
		return Color.RED
	elif army_size <= 15:
		return Color.YELLOW
	elif army_size <= 30:
		return Color.GREEN
	else:
		return Color.GOLD
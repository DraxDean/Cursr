# scripts/ui/players_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("players", "Players", start_position)

func refresh_content():
	clear_content()
	
	var players_label = Label.new()
	players_label.text = "Active Players:"
	players_label.add_theme_color_override("font_color", Color.WHITE)
	add_content_child(players_label)
	
	# Get players data from game reference
	if not game_ref or not game_ref.has_method("get") or not game_ref.players_data:
		var error_label = Label.new()
		error_label.text = "No player data available"
		error_label.add_theme_color_override("font_color", Color.RED)
		add_content_child(error_label)
		return
	
	var players_data = game_ref.players_data
	
	# Display each player
	for player_id in players_data:
		var player_data = players_data[player_id]
		
		# Create container for this player
		var player_container = VBoxContainer.new()
		player_container.add_theme_constant_override("separation", 5)
		add_content_child(player_container)
		
		# Player header
		var header_container = HBoxContainer.new()
		player_container.add_child(header_container)
		
		var player_icon = Label.new()
		if str(player_id) == "environment":
			player_icon.text = "🌍"
		else:
			player_icon.text = "👤"
		player_icon.custom_minimum_size = Vector2(20, 20)
		header_container.add_child(player_icon)
		
		var player_info = VBoxContainer.new()
		header_container.add_child(player_info)
		
		var player_name = Label.new()
		if str(player_id) == "environment":
			player_name.text = "Environment"
			player_name.add_theme_color_override("font_color", Color.LIME_GREEN)
		else:
			player_name.text = "Player " + str(player_id) + " (" + player_data.get("race", "Human").capitalize() + ")"
			player_name.add_theme_color_override("font_color", Color.CYAN)
		player_info.add_child(player_name)
		
		# Show resources/objects
		if str(player_id) == "environment":
			# Show environment objects
			var counts = player_data.get("counts", {})
			var objects_label = Label.new()
			objects_label.text = "Environment Objects:"
			objects_label.add_theme_color_override("font_color", Color.WHITE)
			player_info.add_child(objects_label)
			
			# Mountains
			var mountains_label = Label.new()
			mountains_label.text = "  🏔️ Mountains: " + str(counts.get("mountains", 0))
			mountains_label.add_theme_color_override("font_color", Color.GRAY)
			player_info.add_child(mountains_label)
			
			# Trees
			var trees_label = Label.new()
			trees_label.text = "  🌲 Trees: " + str(counts.get("trees", 0))
			trees_label.add_theme_color_override("font_color", Color.GREEN)
			player_info.add_child(trees_label)
			
		else:
			# Show regular player resources
			var resources = player_data.get("resources", {})
			var resources_label = Label.new()
			resources_label.text = "Resources:"
			resources_label.add_theme_color_override("font_color", Color.WHITE)
			player_info.add_child(resources_label)
			
			# Gold
			var gold_label = Label.new()
			gold_label.text = "  🪙 Gold: " + str(resources.get("gold", 0))
			gold_label.add_theme_color_override("font_color", Color.GOLD)
			player_info.add_child(gold_label)
			
			# Food
			var food_label = Label.new()
			food_label.text = "  🍞 Food: " + str(resources.get("food", 0))
			food_label.add_theme_color_override("font_color", Color.ORANGE)
			player_info.add_child(food_label)
			
			# Wood
			var wood_label = Label.new()
			wood_label.text = "  🪵 Wood: " + str(resources.get("wood", 0))
			wood_label.add_theme_color_override("font_color", Color.SADDLE_BROWN)
			player_info.add_child(wood_label)
			
			# Population
			var population = player_data.get("population", {})
			var pop_label = Label.new()
			pop_label.text = "Population: " + str(population.get("current", 0)) + "/" + str(population.get("max", 0))
			pop_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
			player_info.add_child(pop_label)
			
			# Buildings count
			var buildings = player_data.get("buildings", [])
			var buildings_label = Label.new()
			buildings_label.text = "Buildings: " + str(buildings.size())
			buildings_label.add_theme_color_override("font_color", Color.YELLOW)
			player_info.add_child(buildings_label)
		
		# Add separator between players
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, 10)
		add_content_child(separator)
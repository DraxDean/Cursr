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
	
	# Player 1 info
	var player_container = HBoxContainer.new()
	add_content_child(player_container)
	
	var player_icon = Label.new()
	player_icon.text = "👤"
	player_icon.custom_minimum_size = Vector2(20, 20)
	player_container.add_child(player_icon)
	
	var player_info = VBoxContainer.new()
	player_container.add_child(player_info)
	
	var player_name = Label.new()
	player_name.text = "Player 1 (Human)"
	player_name.add_theme_color_override("font_color", Color.CYAN)
	player_info.add_child(player_name)
	
	var player_status = Label.new()
	player_status.text = "Status: Active"
	player_status.add_theme_color_override("font_color", Color.GREEN)
	player_info.add_child(player_status)
	
	# Race info if available
	if game_ref and game_ref.world_data.has("player_data"):
		var player_data = game_ref.world_data["player_data"]
		var race = player_data.get("race", "Unknown")
		var race_label = Label.new()
		race_label.text = "Race: " + race.capitalize()
		race_label.add_theme_color_override("font_color", Color.YELLOW)
		player_info.add_child(race_label)
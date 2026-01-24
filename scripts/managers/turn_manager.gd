# scripts/managers/turn_manager.gd
extends Node

# Reference (set via setup)
var day_counter_label: Label

# State
var current_day: int = 1

# signal turn_computed # Optional: Emit when turn logic is done - currently unused


func _ready():
	print("TurnManager ready.")


func setup(_label: Label):
	day_counter_label = _label
	if not is_instance_valid(day_counter_label):
		push_error("TurnManager: Invalid day counter label provided.")
	_update_label() # Update label with initial day
	print("TurnManager setup complete.")


func end_turn():
	print("TurnManager: Ending Day %d..." % current_day)
	current_day += 1
	_update_label()
	_compute_turn_results()
	# Optional: emit_signal("turn_computed")
	print("TurnManager: Started Day %d." % current_day)


func set_day(day: int):
	current_day = max(1, day) # Ensure day is at least 1
	_update_label()


func get_day() -> int:
	return current_day


func _update_label():
	if is_instance_valid(day_counter_label):
		day_counter_label.text = "Day: %d" % current_day


func _compute_turn_results():
	print("TurnManager: Computing turn results for end of Day %d..." % (current_day - 1))
	
	# Get reference to game node for applying effects
	var game_node = get_parent()
	if game_node:
		# First, recalculate resource rates for all players
		if game_node.has_method("calculate_resource_rates"):
			for player_id in game_node.players_data.keys():
				if typeof(player_id) == TYPE_INT:  # Only for actual players, not environment
					game_node.calculate_resource_rates(player_id)
		
		# Apply resource production for all players
		if game_node.has_method("apply_resource_production"):
			for player_id in game_node.players_data.keys():
				if typeof(player_id) == TYPE_INT:  # Only for actual players, not environment
					game_node.apply_resource_production(player_id)
		
		# Apply population growth for all players
		if game_node.has_method("apply_population_growth"):
			for player_id in game_node.players_data.keys():
				if typeof(player_id) == TYPE_INT:  # Only for actual players, not environment
					game_node.apply_population_growth(player_id)
	# Access other managers via get_node() or singletons if needed,
	# or have game.gd coordinate actions based on turn_computed signal.
	print("TurnManager: Turn computations complete.")

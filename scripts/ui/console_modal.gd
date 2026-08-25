# scripts/ui/console_modal.gd
extends Control

signal modal_closed

var is_open: bool = false
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# UI Components
var background_panel: Panel
var title_label: Label
var close_button: Button
var output_container: VBoxContainer
var output_scroll: ScrollContainer
var output_text: RichTextLabel
var separator: HSeparator
var input_field: LineEdit
var command_history: Array = []
var history_index: int = -1

# Debug message buffer
var debug_messages: Array = []
var max_messages: int = 100

func _init():
	name = "ConsoleModal"
	visible = false
	_setup_ui()

func _ready():
	# Set modal size and position after being added to scene tree
	if get_viewport():
		var viewport_size = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(viewport_size.x * 0.6, viewport_size.y * 0.4)
		size = custom_minimum_size
		position = Vector2(viewport_size.x * 0.2, viewport_size.y * 0.1)
	
	# Add initial help message
	add_debug_message("Debug Console Ready - Press ~ to close, type 'help' for commands")

func _setup_ui():
	# Semi-transparent background panel
	background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create a StyleBox for semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	background_panel.add_theme_stylebox_override("panel", style_box)
	add_child(background_panel)
	
	# Create main VBox container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 5)
	background_panel.add_child(main_vbox)
	
	# Title bar
	var title_container = HBoxContainer.new()
	title_container.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(title_container)
	
	title_label = Label.new()
	title_label.text = "Debug Console"
	title_label.add_theme_font_size_override("font_size", 16)
	title_container.add_child(title_label)
	
	# Spacer
	title_container.add_child(Control.new())
	
	# Close button
	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	title_container.add_child(close_button)
	
	# Output area with scroll
	output_scroll = ScrollContainer.new()
	output_scroll.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(output_scroll)
	
	output_text = RichTextLabel.new()
	output_text.text = "Debug console initialized. Messages will appear here.\n"
	output_text.fit_content = true
	output_text.scroll_active = false
	output_text.selection_enabled = true
	output_text.context_menu_enabled = true
	output_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_text.add_theme_color_override("default_color", Color.WHITE)
	output_text.add_theme_font_size_override("normal_font_size", 12)
	output_scroll.add_child(output_text)
	
	# Separator
	separator = HSeparator.new()
	main_vbox.add_child(separator)
	
	# Input field
	input_field = LineEdit.new()
	input_field.placeholder_text = "Enter command (help for list)..."
	input_field.custom_minimum_size = Vector2(0, 30)
	input_field.text_submitted.connect(_on_command_submitted)
	main_vbox.add_child(input_field)
	
	# Make title bar draggable
	title_container.gui_input.connect(_on_title_gui_input)

func _on_title_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func toggle_console():
	if is_open:
		close_console()
	else:
		open_console()

func open_console():
	is_open = true
	visible = true
	input_field.grab_focus()

func close_console():
	is_open = false
	visible = false

func add_debug_message(message: String):
	# Add message to the buffer
	debug_messages.append(message)
	
	# Keep only the last max_messages
	if debug_messages.size() > max_messages:
		debug_messages.pop_front()
	
	# Update the display
	_update_output_display()

func _update_output_display():
	output_text.text = "\n".join(debug_messages)
	# Auto-scroll to bottom
	await get_tree().process_frame
	if output_scroll:
		output_scroll.get_v_scroll_bar().value = output_scroll.get_v_scroll_bar().max_value

func _on_command_submitted(command: String):
	# Add command to history
	command_history.append(command)
	history_index = -1
	
	# Echo the command
	add_debug_message("> " + command)
	
	# Process the command
	_process_command(command)
	
	# Clear input
	input_field.clear()

func _process_command(command: String):
	var parts = command.split(" ", false)
	if parts.is_empty():
		return
	
	var full_cmd = command.strip_edges().to_lower()
	var cmd = parts[0].to_lower()
	
	if cmd == "event":
		var query = " ".join(parts.slice(1)) if parts.size() > 1 else ""
		_cmd_fire_event(query)
		return
	
	match full_cmd:
		"help":
			_show_help()
		"clear":
			debug_messages.clear()
			_update_output_display()
		"players":
			_show_players_info()
		"buildings":
			_show_buildings_info()
		"objects":
			_show_objects_info()
		"units":
			_show_units_info()
		"map":
			_show_map_info()
		"list":
			_list_scene_nodes()
		"test":
			_create_test_sprite()
		"spritemap":
			_show_sprite_map()
		"sync":
			_sync_unit_sprites()
		"duplicates":
			_check_for_duplicates()
		"save":
			add_debug_message("Executing save command...")
			if get_parent().get_parent().has_method("_execute_save"):
				get_parent().get_parent()._execute_save()
				add_debug_message("Save executed!")
		"load":
			add_debug_message("Load command not yet implemented")
		"ff", "surrender", "forfeit":
			_cmd_forfeit()
		"wave":
			_cmd_spawn_wave()
		"events":
			_cmd_list_events()
		"fake notification", "fake", "random event":
			_cmd_fake_notification()
		"the path", "cipher":
			_cmd_fire_secret_event()
		"demo achievement":
			_cmd_demo_achievement()
		_:
			add_debug_message("Unknown command: " + full_cmd + ". Type 'help' for commands.")

func _show_help():
	add_debug_message("\n=== Debug Console Commands ===")
	add_debug_message("help - Show this help message")
	add_debug_message("clear - Clear console output")
	add_debug_message("players - Show player information")
	add_debug_message("buildings - Show buildings information")
	add_debug_message("objects - Show environment objects (trees, mountains)")
	add_debug_message("units - Show units information with sprite status")
	add_debug_message("map - Show map and world creation info")
	add_debug_message("list - List all scene nodes in tree")
	add_debug_message("test - Create a test sprite at camera center")
	add_debug_message("spritemap - Show unit-to-sprite mapping status")
	add_debug_message("sync - Sync unit sprite_id with actual sprites in scene")
	add_debug_message("duplicates - Check for duplicate unit IDs and fix them")
	add_debug_message("save - Execute save game")
	add_debug_message("load - Load saved game")
	add_debug_message("ff / surrender / forfeit - Immediately forfeit and return to main menu")
	add_debug_message("wave - Force-spawn the next enemy wave immediately")
	add_debug_message("events - List all pending turn events")
	add_debug_message("event <keyword> - Manually fire a world event by id/title match (e.g. 'event marauders'); no keyword = random")
	add_debug_message("fake notification - Push a test notification card")
	add_debug_message("the path / cipher - Fire the secret encoded legendary event")
	add_debug_message("demo achievement - Unlock the demo achievement for testing")
	add_debug_message("===============================\n")

func _show_players_info():
	var game = get_parent().get_parent()
	add_debug_message("Players Data:")
	for player_id in game.players_data.keys():
		if str(player_id) != "environment":
			var player = game.players_data[player_id]
			add_debug_message("  Player %s: %s" % [str(player_id), player.get("name", "Unknown")])
			add_debug_message("    Race: %s" % [player.get("race", "Unknown")])
			var resources = player.get("resources", {})
			add_debug_message("    Resources: Gold=%d, Food=%d, Wood=%d" % [
				resources.get("gold", 0),
				resources.get("food", 0),
				resources.get("wood", 0)
			])

func _show_buildings_info():
	var game = get_parent().get_parent()
	add_debug_message("\n=== BUILDING INFO ===")
	if game.has_meta("map_objects_holder"):
		var buildings = game.players_data.get(1, {}).get("buildings", [])
		if buildings.size() > 0:
			add_debug_message("Player 1 buildings: " + str(buildings.size()))
			for building_name in buildings:
				add_debug_message("  - " + building_name)
		else:
			add_debug_message("No buildings for Player 1")
	else:
		add_debug_message("Building counters: " + str(game.building_counter))
	add_debug_message("====================\n")

func _on_close_pressed():
	close_console()

func _show_objects_info():
	var game = get_parent().get_parent()
	add_debug_message("\n=== ENVIRONMENT OBJECTS ===")
	if game.players_data.has("environment"):
		var env = game.players_data["environment"]
		var objects = env.get("objects", {})
		var counts = env.get("counts", {})
		
		add_debug_message("Mountains: " + str(counts.get("mountains", 0)))
		var mountains = objects.get("mountains", {})
		for m_id in mountains.keys():
			var m = mountains[m_id]
			add_debug_message("  - %s at %s" % [m.get("name", "Unknown"), str(m.get("position", Vector2.ZERO))])
		
		add_debug_message("Trees: " + str(counts.get("trees", 0)))
		var trees = objects.get("trees", {})
		for t_id in trees.keys():
			var t = trees[t_id]
			add_debug_message("  - %s at %s" % [t.get("name", "Unknown"), str(t.get("position", Vector2.ZERO))])
	add_debug_message("===========================\n")

func _show_units_info():
	var game = get_parent().get_parent()
	add_debug_message("\n=== UNITS INFO ===")
	
	# Get all units from all players
	var total_units = 0
	var total_with_sprites = 0
	var units_without_both_assignments = 0
	
	for player_id in game.players_data.keys():
		if str(player_id) == "environment":
			continue
		var player = game.players_data[player_id]
		var player_units = player.get("units", [])
		
		if player_units.size() > 0:
			add_debug_message("Player %s units (%d):" % [str(player_id), player_units.size()])
			for unit in player_units:
				var unit_name = unit.get("name", "Unknown")
				var unit_id = unit.get("unique_id", "?")
				var pos = unit.get("position", Vector2.ZERO)
				var living = unit.get("living_quarters", "None")
				var job = unit.get("job", "None")
				var speed_mult = unit.get("speed_multiplier", 1.0)
				var speed_percent = int(speed_mult * 100)
				var has_sprite = unit.has("sprite_id") and unit.get("sprite_id") != ""
				var sprite_status = "[SPRITE]" if has_sprite else "[NO SPRITE]"
				
				# Check if unit should have a sprite
				var should_have_sprite = living != "None" and job != "None"
				
				var detail = ""
				if not should_have_sprite:
					detail = " (Missing assignments: "
					if living == "None":
						detail += "living "
					if job == "None":
						detail += "job"
					detail += ")"
					units_without_both_assignments += 1
				elif not has_sprite:
					detail = " [ERROR: Should have sprite but doesn't!]"
				
				add_debug_message("  %s %s: %s at %s (Living: %s, Job: %s, Speed: %d%%)%s" % [sprite_status, unit_id, unit_name, str(pos), living, job, speed_percent, detail])
				
				# Show path info if unit has a path
				var current_path = unit.get("current_path", [])
				var path_index = unit.get("path_index", 0)
				var movement_state = unit.get("movement_state", "idle")
				
				if not current_path.is_empty():
					var path_info = "Path [%d/%d]: " % [path_index, current_path.size()]
					for i in range(current_path.size()):
						var waypoint = current_path[i]
						if i == path_index:
							path_info += "*%s* " % str(waypoint)  # Mark current waypoint
						else:
							path_info += "%s " % str(waypoint)
					add_debug_message("    %s (State: %s)" % [path_info, movement_state])
				
				total_units += 1
				if has_sprite:
					total_with_sprites += 1
	
	if total_units == 0:
		add_debug_message("No units spawned")
	else:
		add_debug_message("Total units: %d (%d with sprites, %d missing assignments)" % [total_units, total_with_sprites, units_without_both_assignments])
	add_debug_message("==================\n")

func _show_map_info():
	var game = get_parent().get_parent()
	add_debug_message("\n=== MAP INFO ===")
	add_debug_message("Map dimensions: %dx%d" % [game.MAP_WIDTH, game.MAP_HEIGHT])
	add_debug_message("Is in world creation: " + str(game.is_in_world_creation))
	if game.world_data.has("size"):
		add_debug_message("World seed: " + str(game.world_data.get("seed", "Unknown")))
	add_debug_message("Loaded buildings: " + str(game.loaded_buildings_data.size()))
	add_debug_message("Loaded units: " + str(game.loaded_units_data.size()))
	add_debug_message("Loaded environment objects: " + str(game.loaded_environment_objects_data.size()))
	add_debug_message("================\n")

func _list_scene_nodes():
	var game = get_parent().get_parent()
	add_debug_message("\n=== SCENE TREE (Top 20) ===")
	var nodes: Array = []
	_recursive_list_nodes(game, 0, 20, nodes)
	for node_info in nodes:
		add_debug_message(node_info)
	add_debug_message("============================\n")

func _recursive_list_nodes(node: Node, indent: int, max_depth: int, nodes: Array) -> void:
	if indent > max_depth or nodes.size() >= 20:
		return
	
	var indent_str = "  ".repeat(indent)
	var node_info = indent_str + node.name + " (" + node.get_class() + ")"
	nodes.append(node_info)
	
	for child in node.get_children():
		if nodes.size() >= 20:
			break
		_recursive_list_nodes(child, indent + 1, max_depth, nodes)

func _create_test_sprite():
	"""Create a visible test sprite at the center of the screen"""
	var game = get_parent().get_parent()
	if not game or not game.map_objects_holder:
		add_debug_message("ERROR: Cannot access game or map_objects_holder")
		return
	
	# Get camera center position
	var camera = game.camera
	if not camera:
		add_debug_message("ERROR: No camera found")
		return
	
	var center_pos = camera.get_screen_center_position()
	add_debug_message("Creating test sprite at screen center: " + str(center_pos))
	
	# Create a simple test sprite
	var test_sprite = Sprite2D.new()
	test_sprite.name = "test_sprite_debug"
	test_sprite.position = center_pos
	test_sprite.z_index = 10  # Above units
	test_sprite.centered = true
	
	# Try to load the unit texture
	var texture_path = "res://assets/units/human_male_peasant_side.png"  # Use male sprite for console
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		test_sprite.texture = texture
		add_debug_message("Test sprite: Loaded texture (size: " + str(texture.get_size()) + ")")
	else:
		# Use a colored rectangle instead
		var rect = ColorRect.new()
		rect.size = Vector2(16, 16)
		rect.color = Color.CYAN
		test_sprite.add_child(rect)
		add_debug_message("Test sprite: Using colored rectangle (no texture found)")
	
	game.map_objects_holder.add_child(test_sprite)
	add_debug_message("Test sprite created and added to scene!")

func _show_sprite_map():
	"""Show the unit sprite mapping status"""
	var game = get_parent().get_parent()
	add_debug_message("\n=== UNIT SPRITE MAPPING ===")
	add_debug_message("Mapped units: " + str(game.unit_sprite_map.size()))
	
	if game.unit_sprite_map.is_empty():
		add_debug_message("No unit-sprite mappings found")
	else:
		for unit_id in game.unit_sprite_map.keys():
			var sprite = game.unit_sprite_map[unit_id]
			if is_instance_valid(sprite):
				add_debug_message("  %s -> Sprite (pos: %s)" % [unit_id, str(sprite.position)])
			else:
				add_debug_message("  %s -> [INVALID/FREED]" % unit_id)
	
	add_debug_message("===========================\n")

func _sync_unit_sprites():
	"""Sync unit sprite_id values with actual sprites in scene"""
	var game = get_parent().get_parent()
	add_debug_message("\n=== SYNCING UNIT SPRITES ===")
	
	var synced = 0
	var already_valid = 0
	var missing_sprites = []
	var missing_sprite_ids = []
	var map_objects = game.map_objects_holder
	
	if not map_objects:
		add_debug_message("ERROR: map_objects_holder not found")
		return
	
	# Check all units and ensure they have sprite_id set if sprite exists
	for player_id in game.players_data.keys():
		if str(player_id) == "environment":
			continue
		
		var player = game.players_data[player_id]
		var player_units = player.get("units", [])
		
		for unit in player_units:
			var unit_id = unit.get("unique_id", "?")
			var unit_name = unit.get("name", "Unknown")
			var has_sprite_id = unit.has("sprite_id") and unit.get("sprite_id") != ""
			var sprite_in_scene = map_objects.get_node_or_null(unit_id)
			
			if sprite_in_scene:
				if has_sprite_id:
					already_valid += 1
					add_debug_message("  ✓ %s (%s) has sprite_id (valid)" % [unit_id, unit_name])
				else:
					# Sprite exists but sprite_id not set - FIX IT
					unit["sprite_id"] = unit_id
					game.unit_sprite_map[unit_id] = sprite_in_scene
					synced += 1
					add_debug_message("  ⚠ %s (%s) SYNCED - sprite exists but sprite_id was missing!" % [unit_id, unit_name])
			else:
				if has_sprite_id:
					add_debug_message("  ✗ %s (%s) has sprite_id but NO SPRITE IN SCENE!" % [unit_id, unit_name])
					missing_sprites.append(unit_id)
				else:
					add_debug_message("  ✗ %s (%s) has NO SPRITE and NO sprite_id" % [unit_id, unit_name])
					missing_sprite_ids.append(unit_id)
	
	add_debug_message("Sync complete: %d synced, %d already valid" % [synced, already_valid])
	if missing_sprites.size() > 0:
		add_debug_message("Units with sprite_id but no sprite in scene: %s" % str(missing_sprites))
	if missing_sprite_ids.size() > 0:
		add_debug_message("Units with no sprite_id and no sprite: %s" % str(missing_sprite_ids))
	add_debug_message("============================\n")

func _check_for_duplicates():
	"""Check for and report duplicate unit IDs"""
	var game = get_parent().get_parent()
	add_debug_message("\n=== CHECKING FOR DUPLICATE UNIT IDs ===")
	
	var all_unit_ids = {}
	var duplicates = []
	
	for player_id in game.players_data.keys():
		if str(player_id) == "environment":
			continue
		
		var player = game.players_data[player_id]
		var player_units = player.get("units", [])
		
		for unit in player_units:
			var unit_id = unit.get("unique_id", "")
			if unit_id == "":
				continue
			
			if unit_id not in all_unit_ids:
				all_unit_ids[unit_id] = []
			all_unit_ids[unit_id].append({"player": player_id, "name": unit.get("name", "Unknown")})
	
	# Report duplicates
	for unit_id in all_unit_ids.keys():
		if all_unit_ids[unit_id].size() > 1:
			add_debug_message("✗ DUPLICATE: %s appears %d times:" % [unit_id, all_unit_ids[unit_id].size()])
			for occurrence in all_unit_ids[unit_id]:
				add_debug_message("  - Player %s: %s" % [str(occurrence["player"]), occurrence["name"]])
			duplicates.append(unit_id)
	
	if duplicates.size() == 0:
		add_debug_message("✓ No duplicate unit IDs found")
	else:
		add_debug_message("Found %d duplicate unit IDs - consider saving to trigger automatic fix" % duplicates.size())
	
	add_debug_message("=====================================\n")

func _cmd_forfeit():
	"""Forfeit the current game and show the game over screen."""
	add_debug_message("⚑ Forfeit accepted. Returning to main menu...")
	close_console()
	var game = get_parent().get_parent()
	if is_instance_valid(game) and game.has_method("_trigger_game_over"):
		game._trigger_game_over()
	else:
		# Fallback: go straight to main menu
		get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")

func _cmd_spawn_wave():
	"""Force-spawn the next enemy wave immediately."""
	var game = get_parent().get_parent()
	if is_instance_valid(game) and is_instance_valid(game.wave_spawner):
		var ws = game.wave_spawner
		ws.wave_number += 1
		ws.next_wave_day = game.turn_manager.get_day() + ws.WAVE_INTERVAL
		ws._spawn_wave(ws.wave_number)
		add_debug_message("⚔ Wave %d spawned!" % ws.wave_number)
	else:
		add_debug_message("ERROR: wave_spawner not found on game node.")

func _cmd_list_events():
	"""List all pending turn events."""
	var game = get_parent().get_parent()
	if not is_instance_valid(game) or not is_instance_valid(game.turn_event_manager):
		add_debug_message("ERROR: turn_event_manager not found.")
		return
	var events = game.turn_event_manager.get_events()
	if events.is_empty():
		add_debug_message("No pending turn events.")
		return
	add_debug_message("\n=== PENDING TURN EVENTS (%d) ===" % events.size())
	for ev in events:
		add_debug_message("  %s %s — %s" % [ev.get("icon", "⚠"), ev.get("title", "?"), ev.get("body", "")])
	add_debug_message("================================\n")

func _cmd_fake_notification():
	"""Push a fake world event notification (click it to open the event modal)."""
	var game = get_parent().get_parent()
	if not is_instance_valid(game) or not is_instance_valid(game.notification_panel):
		add_debug_message("ERROR: notification_panel not found.")
		return
	if not is_instance_valid(game) or not game.has_method("_fire_random_world_event"):
		add_debug_message("ERROR: _fire_random_world_event not found.")
		return
	game._fire_random_world_event()
	add_debug_message("📜 Random world event notification pushed.")

func _cmd_fire_event(query: String):
	"""Manually fire a specific world event by id/title keyword match (e.g. 'event marauders').
	With no keyword, fires a normal random weighted event."""
	var game = get_parent().get_parent()
	if not is_instance_valid(game):
		add_debug_message("ERROR: game node not found.")
		return
	query = query.strip_edges().to_lower()
	if query.is_empty():
		if not game.has_method("_fire_random_world_event"):
			add_debug_message("ERROR: _fire_random_world_event not found.")
			return
		game._fire_random_world_event()
		add_debug_message("📜 Random world event fired.")
		return

	var HumanEvents = preload("res://data/events/events_human.gd")
	# Match on whole words with a naive plural/singular trim so "marauders" finds "Marauder Scouts Spotted"
	var query_words: Array = []
	for w in query.split(" ", false):
		query_words.append(w.trim_suffix("s"))
	var matched_event: Dictionary = {}
	for ev in HumanEvents.EVENTS:
		var haystack: String = ("%s %s" % [ev.get("id", ""), ev.get("title", "")]).to_lower()
		var all_words_found = true
		for w in query_words:
			if w != "" and not haystack.contains(w):
				all_words_found = false
				break
		if all_words_found:
			matched_event = ev.duplicate(true)
			break
	if matched_event.is_empty():
		add_debug_message("ERROR: No event found matching '%s'." % query)
		return
	if game.has_method("tag_event_instance"):
		game.tag_event_instance(matched_event)

	var tier: String = matched_event.get("tier", "C")
	var tier_label: String = HumanEvents.get_tier_label(tier)
	var card_color: Color
	match tier:
		"S+": card_color = Color(0.85, 0.20, 0.85)
		"S":  card_color = Color(0.90, 0.20, 0.20)
		"A":  card_color = Color(0.90, 0.55, 0.10)
		"B":  card_color = Color(0.85, 0.80, 0.10)
		"C":  card_color = Color(0.30, 0.60, 0.90)
		"D":  card_color = Color(0.40, 0.75, 0.40)
		_:    card_color = Color(0.55, 0.55, 0.55)
	if is_instance_valid(game.turn_event_manager):
		game.turn_event_manager.push_event(matched_event["title"], matched_event["body"], matched_event.get("icon", "📜"))
	if is_instance_valid(game.notification_panel):
		game.notification_panel.push(
			"%s — %s" % [tier_label, matched_event["title"]],
			"Click to respond.",
			matched_event.get("icon", "📜"),
			card_color,
			{"action": "open_event", "event_data": matched_event}
		)
	if is_instance_valid(game.game_footer):
		game.game_footer.set_end_day_blocked(true)
	add_debug_message("📜 Fired event: %s" % matched_event.get("title", "?"))

func _cmd_fire_secret_event():
	"""Fire the secret encoded legendary event by ID."""
	var game = get_parent().get_parent()
	if not is_instance_valid(game):
		add_debug_message("ERROR: game node not found.")
		return
	var HumanEvents = preload("res://data/events/events_human.gd")
	var event_data: Dictionary = HumanEvents.get_event_by_id("event_human_sp7")
	if event_data.is_empty():
		add_debug_message("ERROR: secret event not found.")
		return
	var tier_label: String = HumanEvents.get_tier_label(event_data.get("tier", "S+"))
	if is_instance_valid(game.notification_panel):
		game.notification_panel.push(
			"%s — %s" % [tier_label, event_data.get("title", "?")],
			"⊙",
			event_data.get("icon", "⊙"),
			Color(0.85, 0.20, 0.85),
			{"action": "open_event", "event_data": event_data}
		)
	if is_instance_valid(game.game_footer):
		game.game_footer.set_end_day_blocked(true)
	add_debug_message("⊙ " + event_data.get("title", "?"))

func _cmd_demo_achievement():
	"""Unlock the demo achievement for testing the achievement system."""
	var game = get_parent().get_parent()
	if not is_instance_valid(game):
		add_debug_message("ERROR: game node not found.")
		return
	# Reset it first so it always fires fresh for testing
	AchievementManager._unlocked.erase("demo_achievement")
	game._try_unlock_achievement("demo_achievement")
	add_debug_message("🏆 Demo achievement triggered.")

func _input(event: InputEvent):
	if is_open:
		if event is InputEventKey and event.pressed:
			# Handle tilde key to close console
			if event.keycode == KEY_QUOTELEFT or event.physical_keycode == 96:
				close_console()
				get_tree().root.set_input_as_handled()
				return
			# Handle history navigation
			if event.keycode == KEY_UP:
				if command_history.size() > 0:
					history_index = mini(history_index + 1, command_history.size() - 1)
					input_field.text = command_history[command_history.size() - 1 - history_index]
					input_field.caret_column = input_field.text.length()
				get_tree().root.set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				if history_index > 0:
					history_index -= 1
					input_field.text = command_history[command_history.size() - 1 - history_index]
					input_field.caret_column = input_field.text.length()
				elif history_index == 0:
					history_index = -1
					input_field.clear()
				get_tree().root.set_input_as_handled()

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
var output_text: Label
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
	
	output_text = Label.new()
	output_text.text = "Debug console initialized. Messages will appear here.\n"
	output_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	output_text.add_theme_color_override("font_color", Color.WHITE)
	output_text.add_theme_font_size_override("font_size", 12)
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
	
	var cmd = parts[0].to_lower()
	
	match cmd:
		"help":
			_show_help()
		"clear":
			debug_messages.clear()
			_update_output_display()
		"players":
			_show_players_info()
		"buildings":
			_show_buildings_info()
		"save":
			add_debug_message("Executing save command...")
			if get_parent().get_parent().has_method("_execute_save"):
				get_parent().get_parent()._execute_save()
				add_debug_message("Save executed!")
		"load":
			add_debug_message("Load command not yet implemented")
		_:
			add_debug_message("Unknown command: " + cmd + ". Type 'help' for commands.")

func _show_help():
	add_debug_message("\n=== Debug Console Commands ===")
	add_debug_message("help - Show this help message")
	add_debug_message("clear - Clear console output")
	add_debug_message("players - Show player information")
	add_debug_message("buildings - Show buildings information")
	add_debug_message("save - Execute save game")
	add_debug_message("load - Load saved game")
	add_debug_message("===============================\n")

func _show_players_info():
	var game = get_parent().get_parent()
	if game.has_method("debug_print_all_buildings"):
		add_debug_message("Players Data:")
		for player_id in game.players_data.keys():
			if player_id != "environment":
				var player = game.players_data[player_id]
				add_debug_message("  Player %d: %s" % [player_id, player.get("name", "Unknown")])
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

func _input(event: InputEvent):
	if is_open:
		if event is InputEventKey and event.pressed:
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

# scripts/ui/game_over_modal.gd
# Full-screen overlay shown when the player loses their last Town Centre.
extends Control

var _game_ref: Node

func _init(game_reference: Node):
	_game_ref = game_reference
	name = "GameOverModal"
	visible = false
	# Cover the entire viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block all input underneath

func _ready() -> void:
	_build_ui()

func _build_ui():
	# Dark semi-transparent full-screen backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.82)
	add_child(backdrop)

	# Centered card
	var card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(420, 260)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.97)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.75, 0.15, 0.10, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	# Inner padding via MarginContainer
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.add_child(vbox)
	card.add_child(margin)

	# "GAME OVER" heading
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.20, 0.15, 1.0))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Your last Town Centre has fallen."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.75, 0.65, 1.0))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Return to Main Menu button
	var btn = Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(220, 44)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_return_pressed)
	vbox.add_child(btn)

func show_game_over():
	visible = true
	move_to_front()

func _on_return_pressed():
	var error = _game_ref.get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")
	if error != OK:
		push_error("GameOverModal: Failed to return to main menu. Error: %d" % error)

# scripts/ui/game_over_modal.gd
# Full-screen overlay shown on any loss condition (Town Centre destroyed, population wiped out).
extends Control

var _game_ref: Node
var _subtitle_lbl: Label
var _score_container: VBoxContainer

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

	# CenterContainer re-centers its child every time the child's size changes, unlike a
	# one-shot anchor/offset calc (which only centers for the size at the moment it's set —
	# the card grows taller once the title/subtitle/score rows/buttons are added, so a static
	# offset ends up pinning the card's top-left corner at the viewport center instead).
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 380)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.97)
	style.set_border_width_all(3)
	style.border_color = Color(0.75, 0.15, 0.10, 1.0)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	# Inner padding via MarginContainer
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.add_child(vbox)
	card.add_child(margin)

	# "GAME OVER" heading
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.20, 0.15, 1.0))
	vbox.add_child(title)

	# Subtitle — set per-loss-condition in show_game_over()
	_subtitle_lbl = Label.new()
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 16)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.65, 1.0))
	_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_subtitle_lbl)

	vbox.add_child(HSeparator.new())

	# Final score breakdown — populated in show_game_over()
	_score_container = VBoxContainer.new()
	_score_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_score_container)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	# Button row — Return to Main Menu (the real exit) and Minimize (just hides this
	# modal; the notification badge + End Day lock stay in effect, see game.gd)
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var minimize_btn = Button.new()
	minimize_btn.text = "Minimize"
	minimize_btn.custom_minimum_size = Vector2(0, 44)
	minimize_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimize_btn.add_theme_font_size_override("font_size", 15)
	minimize_btn.pressed.connect(_on_minimize_pressed)
	btn_row.add_child(minimize_btn)

	var btn = Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_return_pressed)
	btn_row.add_child(btn)

func show_game_over(reason: String = "Your last Town Centre has fallen.", score: Dictionary = {}) -> void:
	if _subtitle_lbl:
		_subtitle_lbl.text = reason
	_populate_score(score)
	visible = true
	move_to_front()

func reopen() -> void:
	"""Re-show the modal with whatever reason/score it was last triggered with — used when
	the player clicks the undismissable Game Over notification badge after minimizing."""
	visible = true
	move_to_front()

func _on_minimize_pressed():
	visible = false

func _populate_score(score: Dictionary) -> void:
	for child in _score_container.get_children():
		child.queue_free()

	var score_title = Label.new()
	score_title.text = "Final Score"
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title.add_theme_font_size_override("font_size", 13)
	score_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_score_container.add_child(score_title)

	_add_score_row("Resources", score.get("resources", 0), Color(0.95, 0.8, 0.25))
	_add_score_row("Units", score.get("units", 0), Color(0.5, 0.85, 1.0))
	_add_score_row("Buildings", score.get("buildings", 0), Color(0.6, 0.85, 0.5))

	var total_lbl = Label.new()
	total_lbl.text = "Total Score: %d" % score.get("total", 0)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 18)
	total_lbl.add_theme_color_override("font_color", Color.GOLD)
	_score_container.add_child(total_lbl)

func _add_score_row(label_text: String, value: int, color: Color) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_score_container.add_child(row)
	var lbl = Label.new()
	lbl.text = "%s:" % label_text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)
	var val_lbl = Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_color_override("font_color", color)
	row.add_child(val_lbl)

func _on_return_pressed():
	var error = _game_ref.get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")
	if error != OK:
		push_error("GameOverModal: Failed to return to main menu. Error: %d" % error)


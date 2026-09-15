# scripts/ui/victory_modal.gd
# Victory screen shown once the player reaches Day 100 — replaces that day's random world event.
extends "res://scripts/ui/info_modal.gd"

var _game: Node
var _score: Dictionary = {}

func _init(game_reference: Node):
	_game = game_reference
	super("victory", "🏆 Victory!", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(380, 260)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_victory(score: Dictionary) -> void:
	_score = score
	if not is_open:
		toggle()
	else:
		refresh_content()

func refresh_content():
	clear_content()
	if close_button:
		close_button.visible = true

	var body_lbl = Label.new()
	body_lbl.text = "Your settlement has survived 100 days! Here's how you did:"
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	add_content_child(body_lbl)

	add_content_child(HSeparator.new())

	_add_score_row("Resources", _score.get("resources", 0), Color(0.95, 0.8, 0.25))
	_add_score_row("Units", _score.get("units", 0), Color(0.5, 0.85, 1.0))
	_add_score_row("Buildings", _score.get("buildings", 0), Color(0.6, 0.85, 0.5))

	add_content_child(HSeparator.new())

	var total_lbl = Label.new()
	total_lbl.text = "Total Score: %d" % _score.get("total", 0)
	total_lbl.add_theme_font_size_override("font_size", 20)
	total_lbl.add_theme_color_override("font_color", Color.GOLD)
	add_content_child(total_lbl)

	add_content_child(HSeparator.new())

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	add_content_child(btn_row)

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(0, 34)
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(continue_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Return to Main Menu"
	menu_btn.custom_minimum_size = Vector2(0, 34)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(_on_menu_pressed)
	btn_row.add_child(menu_btn)

	fit_to_content()

func _add_score_row(label_text: String, value: int, color: Color) -> void:
	var row = HBoxContainer.new()
	add_content_child(row)
	var lbl = Label.new()
	lbl.text = "%s:" % label_text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.custom_minimum_size = Vector2(90, 20)
	row.add_child(lbl)
	var val_lbl = Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_color_override("font_color", color)
	row.add_child(val_lbl)

func _on_continue_pressed():
	close_modal()
	if is_instance_valid(_game) and is_instance_valid(_game.game_footer):
		_game.game_footer.set_end_day_blocked(false)

func _on_menu_pressed():
	var error = get_tree().change_scene_to_file("res://scenes/main/main_menu_scene.tscn")
	if error != OK:
		push_error("VictoryModal: Failed to return to main menu. Error: %d" % error)

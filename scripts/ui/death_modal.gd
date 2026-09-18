# scripts/ui/death_modal.gd
# Modal that shows the full details of a fallen unit — opened from a death notification
# card, since the card banner itself is too small to fit more than a one-line summary.
extends "res://scripts/ui/info_modal.gd"

var _game: Node
var _death_data: Dictionary = {}

func _init(game_reference: Node):
	_game = game_reference
	super("death", "Unit Lost", Vector2.ZERO)

const MODAL_SIZE := Vector2(380, 200)  # Fixed — content never needs more room than this

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = MODAL_SIZE
		size = MODAL_SIZE
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_death(death_data: Dictionary):
	_death_data = death_data
	if title_label:
		title_label.text = "☠ %s" % death_data.get("name", "Unit Lost")
	if not is_open:
		toggle()
	else:
		refresh_content()

func refresh_content():
	clear_content()
	if _death_data.is_empty():
		return

	var cause: String = _death_data.get("cause", "unknown causes")
	var job_title: String = _death_data.get("job_title", "Villager")
	var uname: String = _death_data.get("name", "A unit")
	var race: String = _death_data.get("race", "human")
	var gender: String = _death_data.get("gender", "male")

	var main_row = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 12)
	add_content_child(main_row)

	var portrait = TextureRect.new()
	var portrait_path: String = ""
	if is_instance_valid(_game) and _game.has_method("_get_unit_portrait_path"):
		portrait_path = _game._get_unit_portrait_path(race, gender)
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = Color(1, 1, 1, 0.5)  # Faded — they're gone
	main_row.add_child(portrait)

	var info_col = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.add_child(info_col)

	var name_lbl = Label.new()
	name_lbl.text = uname
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	info_col.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = "%s %s" % [race.capitalize(), job_title]
	role_lbl.add_theme_font_size_override("font_size", 13)
	role_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	info_col.add_child(role_lbl)

	add_content_child(HSeparator.new())

	var body_lbl = Label.new()
	body_lbl.text = "%s, your %s, has been killed by %s." % [uname, job_title, cause]
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_content_child(body_lbl)

	# Size is fixed (see MODAL_SIZE) — no fit_to_content(), which blew up tall due to the
	# autowrap label's minimum-height being measured before layout settles on a real width
	custom_minimum_size = MODAL_SIZE
	size = MODAL_SIZE

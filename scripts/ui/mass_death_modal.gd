# scripts/ui/mass_death_modal.gd
# Modal listing every death from a mass-casualty batch (6+ units killed at once) — opened from
# the aggregated "Mass Death" notification card instead of flooding the panel with individual ones.
extends "res://scripts/ui/info_modal.gd"

var _deaths: Array = []

func _init():
	super("mass_death", "Mass Death", Vector2.ZERO)

const MODAL_SIZE := Vector2(420, 380)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = MODAL_SIZE
		size = MODAL_SIZE
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_mass_death(mass_death_data: Dictionary):
	_deaths = mass_death_data.get("deaths", [])
	if title_label:
		title_label.text = "☠ Mass Death: %d" % _deaths.size()
	if not is_open:
		toggle()
	else:
		refresh_content()

func refresh_content():
	clear_content()
	if _deaths.is_empty():
		return

	var summary_lbl = Label.new()
	summary_lbl.text = "%d villagers perished in this catastrophe:" % _deaths.size()
	summary_lbl.add_theme_font_size_override("font_size", 14)
	summary_lbl.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_content_child(summary_lbl)

	add_content_child(HSeparator.new())

	var list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 260)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_content_child(list_scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)

	for entry in _deaths:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var icon_lbl = Label.new()
		icon_lbl.text = "☠"
		icon_lbl.custom_minimum_size = Vector2(20, 0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(icon_lbl)

		var text_col = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var name_lbl = Label.new()
		name_lbl.text = "%s (%s)" % [entry.get("name", "A unit"), entry.get("job_title", "Villager")]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		text_col.add_child(name_lbl)

		var cause_lbl = Label.new()
		cause_lbl.text = "Killed by %s" % entry.get("cause", "unknown causes")
		cause_lbl.add_theme_font_size_override("font_size", 11)
		cause_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		text_col.add_child(cause_lbl)

	# Size is fixed (see MODAL_SIZE) — matches death_modal.gd's approach of skipping fit_to_content()
	custom_minimum_size = MODAL_SIZE
	size = MODAL_SIZE

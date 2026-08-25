# scripts/ui/army_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("army", "Army", start_position)

func refresh_content():
	clear_content()

	if not game_ref:
		return

	var header_label = Label.new()
	header_label.text = "⚔ Army Roster"
	header_label.add_theme_color_override("font_color", Color.CYAN)
	header_label.add_theme_font_size_override("font_size", 16)
	add_content_child(header_label)

	var all_units: Array = game_ref.players_data.get(1, {}).get("units", [])
	var combat_units: Array = []
	for u in all_units:
		if not u.get("is_pet", false):
			combat_units.append(u)

	var main_row = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	add_content_child(main_row)

	# ── Left: scrollable unit roster with per-villager toggles ──
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 260)
	main_row.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.custom_minimum_size = Vector2(220, 0)
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	if combat_units.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No units yet."
		empty_lbl.add_theme_color_override("font_color", Color.GRAY)
		list_vbox.add_child(empty_lbl)
	else:
		for unit in combat_units:
			list_vbox.add_child(_build_unit_row(unit))

	# ── Right: aggregate totals ──
	var stats_panel = VBoxContainer.new()
	stats_panel.custom_minimum_size = Vector2(150, 0)
	stats_panel.add_theme_constant_override("separation", 8)
	main_row.add_child(stats_panel)

	_build_stats_panel(stats_panel, combat_units)

	fit_to_content()

func _build_unit_row(unit: Dictionary) -> Control:
	var role = game_ref.get_unit_army_role(unit)
	var locked = game_ref.is_role_locked_in_army(role)
	var in_army = true if locked else unit.get("in_army", false)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_lbl = Label.new()
	name_lbl.text = unit.get("name", "Unit")
	name_lbl.custom_minimum_size = Vector2(95, 20)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = game_ref.ARMY_UNIT_STATS[role]["label"]
	role_lbl.custom_minimum_size = Vector2(95, 20)
	role_lbl.add_theme_font_size_override("font_size", 11)
	var role_color = Color.LIGHT_GRAY
	if role == "soldier":
		role_color = Color(0.4, 1.0, 0.4)
	elif role == "soldier_training":
		role_color = Color(1.0, 0.85, 0.3)
	role_lbl.add_theme_color_override("font_color", role_color)
	row.add_child(role_lbl)

	var toggle = CheckButton.new()
	toggle.button_pressed = in_army
	toggle.disabled = locked
	toggle.tooltip_text = "Always in the army" if locked else "Add/remove from the army"
	toggle.custom_minimum_size = Vector2(40, 20)
	if not locked:
		toggle.toggled.connect(_on_unit_toggle.bind(unit))
	row.add_child(toggle)

	return row

func _on_unit_toggle(pressed: bool, unit: Dictionary):
	unit["in_army"] = pressed
	refresh_content()

func _build_stats_panel(panel: VBoxContainer, units: Array):
	var title = Label.new()
	title.text = "Army Totals"
	title.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)
	panel.add_child(HSeparator.new())

	var totals = game_ref.calculate_army_totals(1)

	_add_stat_row(panel, "🪖", "Units", str(totals["count"]), Color.WHITE)
	_add_stat_row(panel, "❤", "HP Pool", str(totals["hp"]), Color(1.0, 0.4, 0.4))
	_add_stat_row(panel, "⚔", "Strength", str(totals["atk"]), Color(1.0, 0.75, 0.2))

func _add_stat_row(panel: VBoxContainer, icon: String, label_text: String, value_text: String, color: Color):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon_lbl = Label.new()
	icon_lbl.text = icon
	icon_lbl.custom_minimum_size = Vector2(22, 20)
	row.add_child(icon_lbl)

	var lbl = Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size = Vector2(70, 20)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	row.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", color)
	val.add_theme_font_size_override("font_size", 13)
	row.add_child(val)

	panel.add_child(row)

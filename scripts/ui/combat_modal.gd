extends "res://scripts/ui/info_modal.gd"

# ─── State ────────────────────────────────────────────────────────────────────
var _game: Node
var _player_id: int = 1
var _enemy_building: Node2D       # the enemy barracks node
var _enemy_owner: int = -1

var _p_hp: int = 0
var _p_max: int = 0
var _p_atk: int = 0
var _p_count: int = 0
var _e_hp: int = 0
var _e_max: int = 0
var _e_atk: int = 0
var _e_count: int = 0

var _combat_over: bool = false

# ─── UI refs ──────────────────────────────────────────────────────────────────
var _p_panel: PanelContainer
var _e_panel: PanelContainer
var _p_bar: ProgressBar
var _e_bar: ProgressBar
var _p_hp_label: Label
var _e_hp_label: Label
var _log: RichTextLabel
var _attack_btn: Button
var _raid_timer_lbl: Label

# ─── Panel style constants ─────────────────────────────────────────────────────
const _STYLE_NORMAL := {"bg": Color(0.1, 0.1, 0.15, 0.95), "border": Color(0.45, 0.45, 0.6)}
const _STYLE_HIT    := {"bg": Color(0.55, 0.08, 0.08, 0.95), "border": Color(0.9, 0.2, 0.2)}

# ─── Init ─────────────────────────────────────────────────────────────────────
func _init(game: Node) -> void:
	_game = game
	super._init("combat", "⚔ Combat", Vector2(160, 130))

# ─── Public entry point ───────────────────────────────────────────────────────
func start_combat(player_id: int, enemy_building: Node2D) -> void:
	"""Pit a player's whole army against an enemy camp's whole army (pooled hp/strength)."""
	_player_id = player_id
	_enemy_building = enemy_building
	_enemy_owner = enemy_building.get_meta("owner_player", -1) if is_instance_valid(enemy_building) else -1
	_combat_over = false

	var p_totals: Dictionary = _game.calculate_army_totals(_player_id)
	_p_count = p_totals["count"]
	_p_max = max(1, p_totals["hp"])
	_p_hp = _p_max
	_p_atk = p_totals["atk"]

	var e_totals: Dictionary = _game.calculate_army_totals(_enemy_owner)
	_e_count = e_totals["count"]
	_e_max = max(1, e_totals["hp"])
	_e_atk = e_totals["atk"]
	_e_hp = _get_or_init_enemy_hp()

	_build_ui()
	show()

func _get_or_init_enemy_hp() -> int:
	"""Read the camp's current army hp pool, persisted on the barracks node so
	partial damage survives closing the modal and saving/loading the game."""
	if not is_instance_valid(_enemy_building):
		return _e_max
	var hp: int = _enemy_building.get_meta("enemy_hp", -1)
	if hp < 0:
		hp = _e_max
		_enemy_building.set_meta("enemy_hp", hp)
	return min(hp, _e_max)

# ─── Build UI ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	clear_content()

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_p_panel = _make_fighter_panel("Your Army", _p_count, _p_atk, _p_max, false)
	_p_bar   = _p_panel.get_node("vbox/bar")
	_p_hp_label = _p_panel.get_node("vbox/hp_lbl")

	var vs = Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 22)
	vs.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_e_panel = _make_fighter_panel("Marauder Camp", _e_count, _e_atk, _e_max, true)
	_e_bar   = _e_panel.get_node("vbox/bar")
	_e_hp_label = _e_panel.get_node("vbox/hp_lbl")

	row.add_child(_p_panel)
	row.add_child(vs)
	row.add_child(_e_panel)

	_raid_timer_lbl = Label.new()
	_raid_timer_lbl.text = _get_raid_countdown_text()
	_raid_timer_lbl.add_theme_font_size_override("font_size", 12)
	_raid_timer_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25))
	_raid_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(360, 52)
	_log.text = "Your army (%d units, ⚔%d) clashes with the marauder camp (%d units, ⚔%d)!\nClick [b]Attack[/b] to strike." % [_p_count, _p_atk, _e_count, _e_atk]

	add_content_child(row)
	add_content_child(_raid_timer_lbl)
	add_content_child(_log)

	_attack_btn = Button.new()
	_attack_btn.text = "⚔  Attack"
	_attack_btn.custom_minimum_size = Vector2(120, 34)
	_attack_btn.pressed.connect(_on_attack_pressed)
	add_footer_child(_attack_btn)

	# Panels are built at full HP by default — sync them to any already-taken damage
	_refresh_bars()

	fit_to_content()

func refresh_raid_timer() -> void:
	"""Recompute the countdown label — called by game.gd whenever a day ends."""
	if is_instance_valid(_raid_timer_lbl):
		_raid_timer_lbl.text = _get_raid_countdown_text()

func _get_raid_countdown_text() -> String:
	"""Days remaining until this specific camp raids a player building."""
	if not is_instance_valid(_enemy_building) or not is_instance_valid(_game) or not is_instance_valid(_game.turn_manager):
		return ""
	if not is_instance_valid(_game.wave_spawner):
		return ""
	var next_attack_day: int = _game.wave_spawner.get_or_init_attack_day(_enemy_building)
	var days_left: int = next_attack_day - _game.turn_manager.get_day()
	if days_left <= 0:
		return "🔥 This camp is raiding a building this turn!"
	elif days_left == 1:
		return "🔥 This camp raids in 1 day!"
	else:
		return "🔥 This camp raids in %d days" % days_left

func _make_fighter_panel(title: String, count: int, atk: int, max_hp: int, is_enemy: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 200)
	_apply_panel_style(panel, false)

	var vbox = VBoxContainer.new()
	vbox.name = "vbox"
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_lbl = Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if not is_enemy else Color(1.0, 0.5, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Portrait area
	var portrait_box = CenterContainer.new()
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.color = Color(0.22, 0.18, 0.28) if is_enemy else Color(0.18, 0.22, 0.28)
	portrait_box.add_child(portrait)

	var count_lbl = Label.new()
	count_lbl.text = "%d units" % count
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var atk_lbl = Label.new()
	atk_lbl.text = "⚔ Strength: %d" % atk
	atk_lbl.add_theme_font_size_override("font_size", 11)
	atk_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar = ProgressBar.new()
	bar.name = "bar"
	bar.max_value = max_hp
	bar.value    = max_hp
	bar.custom_minimum_size = Vector2(130, 14)
	bar.show_percentage = false

	var hp_lbl = Label.new()
	hp_lbl.name = "hp_lbl"
	hp_lbl.text = "%d / %d HP" % [max_hp, max_hp]
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(name_lbl)
	vbox.add_child(portrait_box)
	vbox.add_child(count_lbl)
	vbox.add_child(atk_lbl)
	vbox.add_child(bar)
	vbox.add_child(hp_lbl)
	panel.add_child(vbox)
	return panel

# ─── Combat turn ──────────────────────────────────────────────────────────────
func _on_attack_pressed() -> void:
	if _combat_over:
		return
	_attack_btn.disabled = true

	# Your whole army strikes as one
	var p_dmg = int(round(_p_atk * randf_range(0.85, 1.15)))
	_e_hp = max(0, _e_hp - p_dmg)
	if is_instance_valid(_enemy_building):
		_enemy_building.set_meta("enemy_hp", _e_hp)
	_flash(_e_panel)
	_refresh_bars()
	_log.text = "Your army deals [color=#FF8866]%d damage[/color] to the marauder camp!" % p_dmg

	if _e_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(true)
		return

	# Enemy camp hits back after a short pause
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	var e_dmg = int(round(_e_atk * randf_range(0.85, 1.15)))
	_p_hp = max(0, _p_hp - e_dmg)
	_flash(_p_panel)
	_refresh_bars()
	_log.text += "\nThe marauder camp strikes back for [color=#FF8866]%d damage[/color]!" % e_dmg

	if _p_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(false)
		return

	_attack_btn.disabled = false

# ─── HP bar update ────────────────────────────────────────────────────────────
func _refresh_bars() -> void:
	_p_bar.value = _p_hp
	_p_hp_label.text = "%d / %d HP" % [_p_hp, _p_max]
	_e_bar.value = _e_hp
	_e_hp_label.text = "%d / %d HP" % [_e_hp, _e_max]

	_tint_bar(_p_bar, _p_hp, _p_max)
	_tint_bar(_e_bar, _e_hp, _e_max)

func _tint_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	var ratio := float(hp) / float(max_hp)
	if ratio <= 0.3:
		bar.modulate = Color(1.0, 0.25, 0.25)
	elif ratio <= 0.6:
		bar.modulate = Color(1.0, 0.85, 0.2)
	else:
		bar.modulate = Color.WHITE

# ─── Red flash ────────────────────────────────────────────────────────────────
func _flash(panel: PanelContainer) -> void:
	_apply_panel_style(panel, true)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(panel):
		_apply_panel_style(panel, false)

func _apply_panel_style(panel: PanelContainer, hit: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color     = _STYLE_HIT["bg"]    if hit else _STYLE_NORMAL["bg"]
	style.border_color = _STYLE_HIT["border"] if hit else _STYLE_NORMAL["border"]
	style.set_border_width_all(2 if hit else 1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

# ─── End combat ───────────────────────────────────────────────────────────────
func _finish(player_won: bool) -> void:
	_combat_over = true
	_attack_btn.text = "  Close  "
	_attack_btn.disabled = false
	_attack_btn.pressed.disconnect(_on_attack_pressed)
	_attack_btn.pressed.connect(close_modal)

	if player_won:
		_log.text = "[color=#66FF99]⚔ Victory![/color] The marauder camp has been wiped out!"
		if is_instance_valid(_enemy_building):
			_game.remove_enemy_barracks_node(_enemy_building)
	else:
		var killed: int = _game.wipe_army(_player_id)
		_log.text = "[color=#FF6666]☠ Defeated![/color] Your army (%d units) has fallen in battle.\nThe Marauders remain..." % killed


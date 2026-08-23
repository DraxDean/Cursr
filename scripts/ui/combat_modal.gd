extends "res://scripts/ui/info_modal.gd"

# ─── Combat stats by unit type ───────────────────────────────────────────────
const UNIT_STATS := {
	"soldier": {"label": "Soldier",  "hp": 40, "atk": 8},
	"scholar": {"label": "Scholar",  "hp": 20, "atk": 3},
	"peasant": {"label": "Peasant",  "hp": 20, "atk": 3},
}
const ENEMY_STATS := {"label": "Marauder", "hp": 30, "atk": 5}

# ─── State ────────────────────────────────────────────────────────────────────
var _game: Node
var _player_unit: Dictionary      # unit dict from players_data
var _enemy_building: Node2D       # the enemy barracks node

var _p_hp: int = 0
var _p_max: int = 0
var _p_atk: int = 0
var _e_hp: int = 0
var _e_max: int = 0
var _e_atk: int = 0

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

# ─── Panel style constants ─────────────────────────────────────────────────────
const _STYLE_NORMAL := {"bg": Color(0.1, 0.1, 0.15, 0.95), "border": Color(0.45, 0.45, 0.6)}
const _STYLE_HIT    := {"bg": Color(0.55, 0.08, 0.08, 0.95), "border": Color(0.9, 0.2, 0.2)}

# ─── Init ─────────────────────────────────────────────────────────────────────
func _init(game: Node) -> void:
	_game = game
	super._init("combat", "⚔ Combat", Vector2(160, 130))

# ─── Public entry point ───────────────────────────────────────────────────────
func start_combat(player_unit: Dictionary, enemy_building: Node2D) -> void:
	_player_unit   = player_unit
	_enemy_building = enemy_building
	_combat_over   = false

	var unit_type  = player_unit.get("type", "peasant")
	var pstats     = UNIT_STATS.get(unit_type, UNIT_STATS["peasant"])
	_p_hp  = pstats["hp"]
	_p_max = pstats["hp"]
	_p_atk = pstats["atk"]
	_e_hp  = ENEMY_STATS["hp"]
	_e_max = ENEMY_STATS["hp"]
	_e_atk = ENEMY_STATS["atk"]

	_build_ui(pstats["label"])
	show()

# ─── Build UI ─────────────────────────────────────────────────────────────────
func _build_ui(player_label: String) -> void:
	clear_content()

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_p_panel = _make_fighter_panel(player_label, _p_max, false)
	_p_bar   = _p_panel.get_node("vbox/bar")
	_p_hp_label = _p_panel.get_node("vbox/hp_lbl")

	var vs = Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 22)
	vs.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_e_panel = _make_fighter_panel(ENEMY_STATS["label"], _e_max, true)
	_e_bar   = _e_panel.get_node("vbox/bar")
	_e_hp_label = _e_panel.get_node("vbox/hp_lbl")

	row.add_child(_p_panel)
	row.add_child(vs)
	row.add_child(_e_panel)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(360, 52)
	_log.text = "Your [b]%s[/b] faces a [b]Marauder[/b]!\nClick [b]Attack[/b] to strike." % player_label

	add_content_child(row)
	add_content_child(_log)

	_attack_btn = Button.new()
	_attack_btn.text = "⚔  Attack"
	_attack_btn.custom_minimum_size = Vector2(120, 34)
	_attack_btn.pressed.connect(_on_attack_pressed)
	add_footer_child(_attack_btn)

	fit_to_content()

func _make_fighter_panel(unit_name: String, max_hp: int, is_enemy: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 180)
	_apply_panel_style(panel, false)

	var vbox = VBoxContainer.new()
	vbox.name = "vbox"
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_lbl = Label.new()
	name_lbl.text = unit_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if not is_enemy else Color(1.0, 0.5, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Portrait area
	var portrait_box = CenterContainer.new()
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.color = Color(0.22, 0.18, 0.28) if is_enemy else Color(0.18, 0.22, 0.28)
	portrait_box.add_child(portrait)

	var bar = ProgressBar.new()
	bar.name = "bar"
	bar.max_value = max_hp
	bar.value    = max_hp
	bar.custom_minimum_size = Vector2(120, 14)
	bar.show_percentage = false

	var hp_lbl = Label.new()
	hp_lbl.name = "hp_lbl"
	hp_lbl.text = "%d / %d HP" % [max_hp, max_hp]
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(name_lbl)
	vbox.add_child(portrait_box)
	vbox.add_child(bar)
	vbox.add_child(hp_lbl)
	panel.add_child(vbox)
	return panel

# ─── Combat turn ──────────────────────────────────────────────────────────────
func _on_attack_pressed() -> void:
	if _combat_over:
		return
	_attack_btn.disabled = true

	# Player hits enemy
	var p_dmg = _p_atk + randi() % 4
	_e_hp = max(0, _e_hp - p_dmg)
	_flash(_e_panel)
	_refresh_bars()
	_log.text = "You deal [color=#FF8866]%d damage[/color] to the Marauder!" % p_dmg

	if _e_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(true)
		return

	# Enemy hits back after a short pause
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return

	var e_dmg = _e_atk + randi() % 4
	_p_hp = max(0, _p_hp - e_dmg)
	_flash(_p_panel)
	_refresh_bars()
	_log.text += "\nMarauder hits back for [color=#FF8866]%d damage[/color]!" % e_dmg

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
		_log.text = "[color=#66FF99]⚔ Victory![/color] The Marauder has been slain.\nThe enemy barracks crumbles to dust."
		if is_instance_valid(_enemy_building):
			_game.remove_enemy_barracks_node(_enemy_building)
	else:
		_log.text = "[color=#FF6666]☠ Defeated![/color] Your unit has fallen in battle.\nThe Marauders remain..."
		_game.remove_unit_from_combat(_player_unit)

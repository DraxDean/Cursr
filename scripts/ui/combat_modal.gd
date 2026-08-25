extends "res://scripts/ui/info_modal.gd"

# ─── State ────────────────────────────────────────────────────────────────────
var _game: Node
var _player_id: int = 1
var _enemy_building: Node2D       # the enemy barracks node
var _enemy_owner: int = -1

# "Current hp" is battle damage sustained this fight (self-injury, standard hits).
# "Max/atk/count" are recomputed from the live unit roster after every roll, since
# cleave/dragon-strike/fumble events actually kill units — the army shrinks mid-battle.
var _p_current_hp: int = 0
var _p_max: int = 0
var _p_atk: int = 0
var _p_count: int = 0
var _e_current_hp: int = 0
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
var _p_count_label: Label
var _e_count_label: Label
var _p_atk_label: Label
var _e_atk_label: Label
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

	# Compute both sides' totals directly (not via _refresh_totals) so we know the enemy's
	# max hp BEFORE initializing/reading their current hp — otherwise _refresh_totals would
	# clamp against the still-default (0) current hp and persist that bogus 0 to the camp.
	var p_totals: Dictionary = _game.calculate_army_totals(_player_id)
	_p_count = p_totals["count"]
	_p_max = p_totals["hp"]
	_p_atk = p_totals["atk"]
	_p_current_hp = _p_max

	var e_totals: Dictionary = _game.calculate_army_totals(_enemy_owner)
	_e_count = e_totals["count"]
	_e_max = e_totals["hp"]
	_e_atk = e_totals["atk"]
	_e_current_hp = _get_or_init_enemy_hp()

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

func _refresh_totals() -> void:
	"""Recompute both armies' count/hp-pool/strength from their live unit rosters."""
	var p_totals: Dictionary = _game.calculate_army_totals(_player_id)
	_p_count = p_totals["count"]
	_p_max = p_totals["hp"]
	_p_atk = p_totals["atk"]
	_p_current_hp = min(_p_current_hp, _p_max)

	var e_totals: Dictionary = _game.calculate_army_totals(_enemy_owner)
	_e_count = e_totals["count"]
	_e_max = e_totals["hp"]
	_e_atk = e_totals["atk"]
	_e_current_hp = min(_e_current_hp, _e_max)
	if is_instance_valid(_enemy_building):
		_enemy_building.set_meta("enemy_hp", _e_current_hp)

# ─── Build UI ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	clear_content()

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_p_panel = _make_fighter_panel("Your Army", false)
	_p_bar   = _p_panel.get_node("vbox/bar")
	_p_hp_label = _p_panel.get_node("vbox/hp_lbl")
	_p_count_label = _p_panel.get_node("vbox/count_lbl")
	_p_atk_label = _p_panel.get_node("vbox/atk_lbl")

	var vs = Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 22)
	vs.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_e_panel = _make_fighter_panel("Marauder Camp", true)
	_e_bar   = _e_panel.get_node("vbox/bar")
	_e_hp_label = _e_panel.get_node("vbox/hp_lbl")
	_e_count_label = _e_panel.get_node("vbox/count_lbl")
	_e_atk_label = _e_panel.get_node("vbox/atk_lbl")

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
	_log.custom_minimum_size = Vector2(380, 68)
	_log.text = "Your army (%d units, ⚔%d) clashes with the marauder camp (%d units, ⚔%d)!\nClick [b]Attack[/b] to roll for battle." % [_p_count, _p_atk, _e_count, _e_atk]

	add_content_child(row)
	add_content_child(_raid_timer_lbl)
	add_content_child(_log)

	_attack_btn = Button.new()
	_attack_btn.text = "⚔  Attack"
	_attack_btn.custom_minimum_size = Vector2(120, 34)
	_attack_btn.pressed.connect(_on_attack_pressed)
	add_footer_child(_attack_btn)

	_refresh_display()

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

func _make_fighter_panel(title: String, is_enemy: bool) -> PanelContainer:
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
	count_lbl.name = "count_lbl"
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var atk_lbl = Label.new()
	atk_lbl.name = "atk_lbl"
	atk_lbl.add_theme_font_size_override("font_size", 11)
	atk_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar = ProgressBar.new()
	bar.name = "bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(130, 14)

	var hp_lbl = Label.new()
	hp_lbl.name = "hp_lbl"
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

	# Your army rolls first
	_log.text = _resolve_roll(_player_id, _enemy_owner, "Your army", "the marauder camp", _p_panel, _e_panel)
	_refresh_totals()
	_refresh_display()

	if _e_count <= 0 or _e_current_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(true)
		return
	if _p_count <= 0 or _p_current_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(false)
		return

	# Then the marauder camp rolls back
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	_log.text += "\n" + _resolve_roll(_enemy_owner, _player_id, "The marauder camp", "your army", _e_panel, _p_panel)
	_refresh_totals()
	_refresh_display()

	if _p_count <= 0 or _p_current_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(false)
		return
	if _e_count <= 0 or _e_current_hp <= 0:
		await get_tree().create_timer(0.35).timeout
		_finish(true)
		return

	_attack_btn.disabled = false

# ─── d20 roll resolution ───────────────────────────────────────────────────────
func _resolve_roll(attacker_id: int, defender_id: int, attacker_name: String, defender_name: String,
		attacker_panel: PanelContainer, defender_panel: PanelContainer) -> String:
	"""Roll a d20 for the attacker's turn and resolve the resulting combat event."""
	var roll: int = randi_range(1, 20)
	var attacker_atk: int = _p_atk if attacker_id == _player_id else _e_atk

	if roll == 1:
		# Critical fumble — one of the attacker's own units falls on their sword
		_flash(attacker_panel)
		var victim: Dictionary = _pick_fumble_target(_game.get_army_units(attacker_id))
		if victim.is_empty():
			return "🎲 [1] %s fumbles badly, but recovers without harm." % attacker_name
		var vname: String = victim.get("name", "A unit")
		_game.remove_unit_from_combat(victim)
		return "🎲 [1] 💀 [color=#FF6666]%s[/color] tripped and fell on their own sword, piercing them through the heart. How unfortunate." % vname

	elif roll <= 9:
		# Miss or minor self-injury — no deaths
		if randi() % 2 == 0:
			return "🎲 [%d] %s's attack goes wide — no effect." % [roll, attacker_name]
		_flash(attacker_panel)
		var self_dmg: int = max(1, int(attacker_atk * 0.15))
		if attacker_id == _player_id:
			_p_current_hp = max(0, _p_current_hp - self_dmg)
		else:
			_e_current_hp = max(0, _e_current_hp - self_dmg)
		return "🎲 [%d] %s stumble and take [color=#FFAA66]%d[/color] self-inflicted damage." % [roll, attacker_name, self_dmg]

	elif roll <= 14:
		# Standard hit
		_flash(defender_panel)
		var dmg: int = int(round(attacker_atk * randf_range(0.85, 1.15)))
		if defender_id == _player_id:
			_p_current_hp = max(0, _p_current_hp - dmg)
		else:
			_e_current_hp = max(0, _e_current_hp - dmg)
		return "🎲 [%d] %s strikes %s for [color=#FF8866]%d damage[/color]!" % [roll, attacker_name, defender_name, dmg]

	elif roll <= 18:
		# Cleave — kill 2 defender units
		_flash(defender_panel)
		var victims: Array = _pick_random_units(_game.get_army_units(defender_id), 2)
		for v in victims:
			_game.remove_unit_from_combat(v)
		if victims.is_empty():
			return "🎲 [%d] %s swings wide but finds no one left to strike!" % [roll, attacker_name]
		var names: Array = []
		for v in victims:
			names.append(str(v.get("name", "a unit")))
		return "🎲 [%d] ⚔ [color=#66FF99]Cleave![/color] %s swept their weapon and cut down %s!" % [roll, attacker_name, ", ".join(names)]

	else:
		# Dragon Strike — kill 3 defender units
		_flash(defender_panel)
		var victims: Array = _pick_random_units(_game.get_army_units(defender_id), 3)
		for v in victims:
			_game.remove_unit_from_combat(v)
		if victims.is_empty():
			return "🎲 [%d] %s strikes true but finds no one left standing!" % [roll, attacker_name]
		var names: Array = []
		for v in victims:
			names.append(str(v.get("name", "a unit")))
		return "🎲 [%d] 🐉 [color=#FFD700]Dragon Strike![/color] %s struck with overwhelming force, leaving %s dead!" % [roll, attacker_name, ", ".join(names)]

func _pick_random_units(units: Array, count: int) -> Array:
	"""Randomly pick up to `count` units from the given list without repeats."""
	var pool: Array = units.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

func _pick_fumble_target(units: Array) -> Dictionary:
	"""Second d20 roll: who suffers the fumble? Soldiers and villagers sit at opposite
	ends of the roll — soldiers are rarely picked (only on a 1), villagers most often."""
	if units.is_empty():
		return {}
	var soldiers: Array = []
	var trainees: Array = []
	var peasants: Array = []
	for u in units:
		match _game.get_unit_army_role(u):
			"soldier":
				soldiers.append(u)
			"soldier_training":
				trainees.append(u)
			_:
				peasants.append(u)

	var roll: int = randi_range(1, 20)
	var tiers: Array
	if roll == 1:
		tiers = [soldiers, trainees, peasants]
	elif roll <= 10:
		tiers = [trainees, peasants, soldiers]
	else:
		tiers = [peasants, trainees, soldiers]

	for tier in tiers:
		if not tier.is_empty():
			return tier[randi() % tier.size()]
	return {}

# ─── Display refresh ──────────────────────────────────────────────────────────
func _refresh_display() -> void:
	_p_bar.max_value = max(1, _p_max)
	_p_bar.value = _p_current_hp
	_p_hp_label.text = "%d / %d HP" % [_p_current_hp, _p_max]
	_p_count_label.text = "%d units" % _p_count
	_p_atk_label.text = "⚔ Strength: %d" % _p_atk

	_e_bar.max_value = max(1, _e_max)
	_e_bar.value = _e_current_hp
	_e_hp_label.text = "%d / %d HP" % [_e_current_hp, _e_max]
	_e_count_label.text = "%d units" % _e_count
	_e_atk_label.text = "⚔ Strength: %d" % _e_atk

	_tint_bar(_p_bar, _p_current_hp, _p_max)
	_tint_bar(_e_bar, _e_current_hp, _e_max)

func _tint_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		bar.modulate = Color(1.0, 0.25, 0.25)
		return
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
		_log.text += "\n[color=#66FF99]⚔ Victory![/color] The marauder camp has been wiped out!"
		if is_instance_valid(_enemy_building):
			_game.remove_enemy_barracks_node(_enemy_building)
	else:
		var killed: int = _game.wipe_army(_player_id)
		var extra: String = " %d remaining unit(s) fall with it." % killed if killed > 0 else ""
		_log.text += "\n[color=#FF6666]☠ Defeated![/color] Your army has fallen in battle.%s\nThe Marauders remain..." % extra



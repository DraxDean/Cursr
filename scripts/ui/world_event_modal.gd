# scripts/ui/world_event_modal.gd
# Modal that presents a random world event with choices that apply effects.
extends "res://scripts/ui/info_modal.gd"

var _game: Node
var _event_data: Dictionary = {}
var _choice_made: bool = false
var _resolved_event_ids: Dictionary = {}

func _init(game_reference: Node):
	_game = game_reference
	super("world_event", "World Event", Vector2.ZERO)

func clear_resolved_events() -> void:
	"""Forget which event instances were resolved — called at the start of each new day
	to keep this dict from growing forever (instance ids already make each firing unique)."""
	_resolved_event_ids.clear()

func _get_event_key(event_data: Dictionary) -> String:
	"""Per-firing resolution key. Falls back to the static id for events fired before
	instance ids existed (e.g. old saves' logged event_data)."""
	return event_data.get("instance_id", event_data.get("id", ""))

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(420, 280)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_event(event_data: Dictionary, reopen: bool = false):
	var event_key: String = _get_event_key(event_data)
	_event_data = event_data
	if reopen and event_key != "" and _resolved_event_ids.has(event_key):
		# Re-opening the same notification card from this turn — preserve resolved state
		_choice_made = true
	else:
		# New firing of this event (even if same type) — always start fresh
		_choice_made = false
		if event_key != "":
			_resolved_event_ids.erase(event_key)
	if title_label:
		var HumanEvents = preload("res://data/events/events_human.gd")
		var tier: String = event_data.get("tier", "C")
		title_label.text = "%s — %s" % [HumanEvents.get_tier_label(tier), event_data.get("title", "World Event")]
	if not is_open:
		toggle()
	else:
		refresh_content()

func refresh_content():
	clear_content()
	if _event_data.is_empty():
		return

	# Icon + flavour text
	var icon_row = HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 12)
	add_content_child(icon_row)

	var icon_lbl = Label.new()
	icon_lbl.text = _event_data.get("icon", "⚠")
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.custom_minimum_size = Vector2(48, 48)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_row.add_child(icon_lbl)

	var body_lbl = Label.new()
	body_lbl.text = _event_data.get("body", "")
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_row.add_child(body_lbl)

	add_content_child(HSeparator.new())

	# Effect summary — built dynamically so pct-based effects show real numbers
	var base_effects = _event_data.get("effects", {})
	var base_res = base_effects.get("resources", {})
	var base_kill: int  = base_effects.get("pop_kill", 0)
	var base_gain: int  = base_effects.get("pop_gain", 0)
	var gain_pct: float = base_effects.get("pop_gain_pct", 0.0)
	var kill_pct: float = base_effects.get("pop_kill_pct", 0.0)
	var effect_parts: Array = []
	for key in ["gold", "food", "wood", "stone", "science"]:
		var val: int = base_res.get(key, 0)
		if val != 0:
			effect_parts.append("%s%d %s" % ["+" if val > 0 else "", val, key.capitalize()])
	if gain_pct > 0.0:
		var cur_pop: int = _game.players_data.get(1, {}).get("population", {}).get("total", 10) if is_instance_valid(_game) else 10
		var est: int = max(1, int(ceil(cur_pop * gain_pct / 100.0)))
		effect_parts.append("+~%d Villagers (~%.0f%%)" % [est, gain_pct])
	elif base_gain > 0:
		effect_parts.append("+%d Villagers" % base_gain)
	if kill_pct > 0.0:
		var cur_pop: int = _game.players_data.get(1, {}).get("population", {}).get("total", 10) if is_instance_valid(_game) else 10
		var est: int = max(1, int(ceil(cur_pop * kill_pct / 100.0)))
		effect_parts.append("-~%d Villagers (~%.0f%%)" % [est, kill_pct])
	elif base_kill > 0:
		effect_parts.append("-%d Villagers" % base_kill)

	if not effect_parts.is_empty():
		var eff_lbl = Label.new()
		eff_lbl.text = "Effects: " + ", ".join(effect_parts)
		eff_lbl.add_theme_font_size_override("font_size", 11)
		eff_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.65))
		add_content_child(eff_lbl)

	add_content_child(HSeparator.new())

	if _choice_made:
		# Show resolved state — no buttons, just a confirmation line
		var done_lbl = Label.new()
		done_lbl.text = "✔ Decision made. Close this window when ready."
		done_lbl.add_theme_font_size_override("font_size", 12)
		done_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_content_child(done_lbl)
	else:
		# Choice buttons — only shown before a decision
		var choices: Array = _event_data.get("choices", [])
		if choices.is_empty():
			choices = [{"label": "Acknowledge", "effects": null}]
		for choice in choices:
			var btn = Button.new()
			btn.text = choice.get("label", "OK")
			btn.custom_minimum_size = Vector2(0, 34)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_choice_pressed.bind(choice))
			add_content_child(btn)

func _on_choice_pressed(choice: Dictionary):
	if _choice_made:
		return  # Guard against double-fire

	_choice_made = true
	# Persist resolution so re-opening the same notification card never resets state
	var event_key: String = _get_event_key(_event_data)
	if event_key != "":
		_resolved_event_ids[event_key] = true

	# Apply the chosen effects (exclusive: choice effects OR base effects)
	var extra = choice.get("effects")
	if extra != null and extra is Dictionary:
		_apply_effects(extra)
	else:
		_apply_effects(_event_data.get("effects", {}))

	# Log the decision
	if is_instance_valid(_game) and is_instance_valid(_game.game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		var day: int = _game.turn_manager.get_day() if is_instance_valid(_game.turn_manager) else 0
		_game.game_log.add(day, GL.Category.EVENT,
			"%s %s — %s" % [
				_event_data.get("icon", "📜"),
				_event_data.get("title", "?"),
				choice.get("label", "?")
			],
			{"event_data": _event_data}
		)

	# Refresh open modals
	if is_instance_valid(_game):
		if is_instance_valid(_game.resources_modal) and _game.resources_modal.is_open:
			_game.resources_modal.refresh_content()
		if is_instance_valid(_game.population_modal) and _game.population_modal.is_open:
			_game.population_modal.refresh_content()
		if is_instance_valid(_game.game_footer):
			_game.game_footer.set_end_day_blocked(false)
		# Unlock the notification card's dismiss button
		if event_key != "" and is_instance_valid(_game.notification_panel):
			_game.notification_panel.mark_event_resolved(event_key)

	# Replace choice buttons with resolved message
	refresh_content()

func _apply_effects(effects: Dictionary):
	if effects.is_empty():
		return
	if not is_instance_valid(_game):
		return

	var player_id = 1
	if not _game.players_data.has(player_id):
		return

	var player = _game.players_data[player_id]

	var res_delta = effects.get("resources", {})
	var resources = player.get("resources", {})
	for key in res_delta.keys():
		resources[key] = max(0, resources.get(key, 0) + res_delta[key])
	player["resources"] = resources

	# pop_max intentionally ignored — population cap is determined by housing buildings only

	_game.players_data[player_id] = player

	var pop_kill: int = effects.get("pop_kill", 0)
	if pop_kill > 0:
		_game.remove_event_units(player_id, pop_kill)

	var pop_gain: int = effects.get("pop_gain", 0)
	# pop_gain_pct: gain this % of current population (rounded up, minimum 1)
	var pop_gain_pct: float = effects.get("pop_gain_pct", 0.0)
	if pop_gain_pct > 0.0:
		var current_pop: int = _game.players_data[player_id].get("population", {}).get("total", 1)
		pop_gain += max(1, int(ceil(current_pop * pop_gain_pct / 100.0)))
	if pop_gain > 0:
		_game.add_event_units(player_id, pop_gain)

	var pop_kill_pct: float = effects.get("pop_kill_pct", 0.0)
	if pop_kill_pct > 0.0:
		var current_pop: int = _game.players_data[player_id].get("population", {}).get("total", 1)
		var extra_kill: int = max(1, int(ceil(current_pop * pop_kill_pct / 100.0)))
		_game.remove_event_units(player_id, extra_kill)

	if effects.get("spawn_wave", false):
		_game.trigger_wave_from_event()

	var add_pet: String = effects.get("add_pet", "")
	if add_pet != "" and _game.has_method("add_pet_companion"):
		_game.add_pet_companion(player_id, add_pet)

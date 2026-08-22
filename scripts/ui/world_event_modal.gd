# scripts/ui/world_event_modal.gd
# Modal that presents a random world event with choices that apply effects.
extends "res://scripts/ui/info_modal.gd"

var _game: Node
var _event_data: Dictionary = {}
var _choice_made: bool = false

func _init(game_reference: Node):
	_game = game_reference
	super("world_event", "World Event", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(420, 280)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_event(event_data: Dictionary):
	_event_data = event_data
	_choice_made = false
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

	# Effect summary
	var base_effects = _event_data.get("effects", {})
	var base_res = base_effects.get("resources", {})
	var base_pop = base_effects.get("pop_max", 0)
	var base_kill: int = base_effects.get("pop_kill", 0)
	var base_gain: int = base_effects.get("pop_gain", 0)
	var effect_parts: Array = []
	for key in ["gold", "food", "wood", "stone", "science"]:
		var val: int = base_res.get(key, 0)
		if val != 0:
			effect_parts.append("%s%d %s" % ["+" if val > 0 else "", val, key.capitalize()])
	if base_pop != 0:
		effect_parts.append("%s%d Pop Cap" % ["+" if base_pop > 0 else "", base_pop])
	if base_kill != 0:
		effect_parts.append("-%d Villagers" % base_kill)
	if base_gain != 0:
		effect_parts.append("+%d Villagers" % base_gain)

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

	# Apply the chosen effects (exclusive: choice effects OR base effects)
	var extra = choice.get("effects")
	if extra != null and extra is Dictionary:
		_apply_effects(extra)
	else:
		_apply_effects(_event_data.get("effects", {}))

	# Refresh open modals
	if is_instance_valid(_game):
		if is_instance_valid(_game.resources_modal) and _game.resources_modal.is_open:
			_game.resources_modal.refresh_content()
		if is_instance_valid(_game.population_modal) and _game.population_modal.is_open:
			_game.population_modal.refresh_content()
		if is_instance_valid(_game.game_footer):
			_game.game_footer.set_end_day_blocked(false)

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

	var pop_delta: int = effects.get("pop_max", 0)
	if pop_delta != 0:
		var pop = player.get("population", {})
		pop["total"] = max(1, pop.get("total", 10) + pop_delta)
		player["population"] = pop

	_game.players_data[player_id] = player

	var pop_kill: int = effects.get("pop_kill", 0)
	if pop_kill > 0:
		_game.remove_event_units(player_id, pop_kill)

	var pop_gain: int = effects.get("pop_gain", 0)
	if pop_gain > 0:
		_game.add_event_units(player_id, pop_gain)


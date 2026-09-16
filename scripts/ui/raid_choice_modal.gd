# scripts/ui/raid_choice_modal.gd
# Unskippable choice shown once a marauder camp's raid timer is up: fight back with your
# army, or let them raze the nearest 1-3 buildings. Blocks End Day until fully resolved —
# including, if the player fights, until the resulting combat modal is closed.
extends "res://scripts/ui/info_modal.gd"

signal resolved

var _game: Node
var _barracks_node: Node2D
var _building_count: int = 1
var _choice_made: bool = false

func _init(game_reference: Node):
	_game = game_reference
	super("raid_choice", "🔥 Marauders at the Gates!", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(420, 220)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_choice(barracks_node: Node2D, building_count: int) -> void:
	_barracks_node = barracks_node
	_building_count = building_count
	_choice_made = false
	if not is_open:
		toggle()
	else:
		refresh_content()

func refresh_content():
	clear_content()
	if close_button:
		close_button.visible = false  # Fully unskippable — no X until a choice is made

	var plural := "buildings" if _building_count != 1 else "building"

	var body_lbl = Label.new()
	body_lbl.text = "A marauder camp is raiding your settlement! Rally your army to fight them off, or let them raze %d %s and hope your army survives to fight another day." % [_building_count, plural]
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.80))
	add_content_child(body_lbl)

	add_content_child(HSeparator.new())

	var fight_btn = Button.new()
	fight_btn.text = "⚔  Fight — send your army to defend"
	fight_btn.custom_minimum_size = Vector2(0, 34)
	fight_btn.pressed.connect(_on_fight_pressed)
	add_content_child(fight_btn)

	var raid_btn = Button.new()
	raid_btn.text = "🔥  Let them raid — sacrifice %d %s" % [_building_count, plural]
	raid_btn.custom_minimum_size = Vector2(0, 34)
	raid_btn.pressed.connect(_on_let_raid_pressed)
	add_content_child(raid_btn)

	fit_to_content()

func _on_fight_pressed():
	if _choice_made:
		return
	_choice_made = true
	close_modal()
	if is_instance_valid(_game):
		await _game.begin_raid_combat(_barracks_node, _building_count)
	resolved.emit()

func _on_let_raid_pressed():
	if _choice_made:
		return
	_choice_made = true
	close_modal()
	if is_instance_valid(_game) and is_instance_valid(_game.wave_spawner):
		_game.wave_spawner.resolve_raid_by_destruction(_barracks_node, _building_count)
	resolved.emit()

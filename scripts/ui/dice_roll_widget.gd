# scripts/ui/dice_roll_widget.gd
# A permanent d20 display above the End Day button. Numbers cycle rapidly then
# decelerate to a final value, coloured by the tier that roll maps to (see
# HumanEvents.get_tier_for_roll). Purely cosmetic for now — will drive the
# day's actual event odds later.
extends Control

signal roll_settled(value: int)   # Emitted once the roll animation lands on its final value

const HumanEvents = preload("res://data/events/events_human.gd")

const FOOTER_H: float = 50.0   # Fallback footer height, used only before setup() has a real button rect
const BOX_SIZE: float = 64.0
const V_GAP: float = 10.0   # Vertical gap between this box and whatever sits below/above it
const IDLE_VALUE: int = 20   # Shown on a fresh new game, before any roll has happened

var _footer: Control = null   # game_footer.gd — gives us the End Day button's real rect
var _box: PanelContainer
var _style: StyleBoxFlat
var _number_lbl: Label
var _roll_token: int = 0   # Invalidates in-flight animations when a new roll starts mid-animation

func _init():
	name = "DiceRollWidget"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	_reanchor()

	_box = PanelContainer.new()
	_box.custom_minimum_size = Vector2(BOX_SIZE, BOX_SIZE)
	_box.size = Vector2(BOX_SIZE, BOX_SIZE)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.10, 0.10, 0.14, 0.95)
	_style.set_border_width_all(2)
	_style.border_color = Color(0.5, 0.5, 0.5)
	_style.set_corner_radius_all(8)
	_box.add_theme_stylebox_override("panel", _style)
	add_child(_box)

	_number_lbl = Label.new()
	_number_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number_lbl.add_theme_font_size_override("font_size", 28)
	_number_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_number_lbl)

	show_static(IDLE_VALUE, false)

func setup(footer: Control) -> void:
	"""Link to game_footer so this widget can anchor off the real End Day button rect."""
	_footer = footer
	_reanchor()
	# Container layout may not have settled yet on the same frame — reanchor once more after
	await get_tree().process_frame
	_reanchor()

func get_gap() -> float:
	"""The vertical gap this widget keeps from its neighbours — reused by the notification panel."""
	return V_GAP

func _reanchor() -> void:
	if not get_viewport():
		return
	size = Vector2(BOX_SIZE, BOX_SIZE)

	if is_instance_valid(_footer) and is_instance_valid(_footer.end_day_button) and _footer.end_day_button.is_inside_tree():
		var btn: Control = _footer.end_day_button
		var btn_global: Vector2 = btn.global_position
		# Centered horizontally on the End Day button; sits V_GAP above the footer's top edge
		position = Vector2(
			btn_global.x + (btn.size.x - BOX_SIZE) / 2.0,
			_footer.global_position.y - BOX_SIZE - V_GAP
		)
		return

	# Fallback before the footer exists yet (first frame only)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2(vp.x - BOX_SIZE - 60.0, vp.y - FOOTER_H - BOX_SIZE - V_GAP)


func show_static(value: int, colored: bool = true) -> void:
	"""Immediately show a value with no animation — used for the idle "20" on a
	fresh game and for restoring the last rolled value on load."""
	_roll_token += 1   # Invalidate any in-flight animation
	_number_lbl.text = str(value)
	if colored:
		var tier: String = HumanEvents.get_tier_for_roll(value)
		var tier_color: Color = HumanEvents.get_tier_color(tier)
		_number_lbl.add_theme_color_override("font_color", tier_color)
		_style.border_color = tier_color
	else:
		_number_lbl.add_theme_color_override("font_color", Color.WHITE)
		_style.border_color = Color(0.5, 0.5, 0.5)

func roll() -> int:
	"""Play the roll animation, settling on a random d20 value tinted by its tier.
	Returns the final value immediately so the caller can persist it right away."""
	_reanchor()
	_roll_token += 1
	var token: int = _roll_token

	var final_roll: int = randi_range(1, 20)
	_play_roll_animation(token, final_roll)
	return final_roll

func _play_roll_animation(token: int, final_roll: int) -> void:
	_number_lbl.add_theme_color_override("font_color", Color.WHITE)
	_style.border_color = Color(0.5, 0.5, 0.5)

	# Rapid cycling that gradually slows down, like a slot reel settling
	const TICKS: int = 16
	for i in range(TICKS):
		if token != _roll_token or not is_instance_valid(self):
			return
		_number_lbl.text = str(randi_range(1, 20))
		var t: float = float(i) / float(TICKS - 1)
		var delay: float = lerp(0.03, 0.20, t * t)
		await get_tree().create_timer(delay).timeout

	if token != _roll_token or not is_instance_valid(self):
		return

	# Settle on the final value + tier colour, with a little emphasis pop
	var final_tier: String = HumanEvents.get_tier_for_roll(final_roll)
	var tier_color: Color = HumanEvents.get_tier_color(final_tier)
	_number_lbl.text = str(final_roll)
	_number_lbl.add_theme_color_override("font_color", tier_color)
	_style.border_color = tier_color
	roll_settled.emit(final_roll)

	var pop_tween = create_tween()
	_box.pivot_offset = _box.size / 2.0
	_box.scale = Vector2(1.35, 1.35)
	pop_tween.tween_property(_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

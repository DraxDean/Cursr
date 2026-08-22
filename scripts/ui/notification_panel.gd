# scripts/ui/notification_panel.gd
# Vertical stack of notification cards on the right side of the screen,
# just above the footer. New cards appear at the bottom and push older ones up.
extends Control

const CARD_W    := 272
const CARD_H    := 52
const CARD_GAP  := 5
const FOOTER_H  := 50   # Must match game_footer height

var _cards: Array = []   # [{panel, data}]

signal notification_clicked(event_data: Dictionary)

func _init():
	name = "NotificationPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	_reanchor()

func _reanchor():
	if not get_viewport():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Panel origin sits at the top-right corner of the footer area.
	# Cards are placed with negative Y offsets so they grow upward.
	position = Vector2(vp.x - CARD_W - 12, vp.y - FOOTER_H)
	size = Vector2(CARD_W, 1)   # Height doesn't matter — cards sit above origin

# ---------------------------------------------------------- public API ------

func push(title: String, body: String, icon: String = "⚠", color: Color = Color(0.85, 0.55, 0.1)):
	var data = {"title": title, "body": body, "icon": icon, "color": color}
	var card = _build_card(data)
	add_child(card)
	_cards.append({"panel": card, "data": data})
	_restack()

func clear_all():
	for entry in _cards:
		if is_instance_valid(entry["panel"]):
			entry["panel"].queue_free()
	_cards.clear()

# ---------------------------------------------------------- internals -------

func _build_card(data: Dictionary) -> Control:
	var card = Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background panel
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.10, 0.14, 0.96)
	style.border_color = data["color"]
	style.border_width_left   = 4
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	bg.add_theme_stylebox_override("panel", style)
	card.add_child(bg)

	# Content row
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_theme_constant_override("margin_left", 10)
	hbox.add_theme_constant_override("margin_right", 6)
	hbox.add_theme_constant_override("margin_top", 4)
	hbox.add_theme_constant_override("margin_bottom", 4)
	card.add_child(hbox)

	# Icon
	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_lbl.custom_minimum_size = Vector2(24, 0)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	# Text column
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = data["title"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.clip_text = true
	vbox.add_child(title_lbl)

	var body_lbl = Label.new()
	body_lbl.text = data["body"]
	body_lbl.add_theme_font_size_override("font_size", 10)
	body_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	body_lbl.clip_text = true
	vbox.add_child(body_lbl)

	# Dismiss ✕ button
	var dismiss = Button.new()
	dismiss.text = "✕"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(22, 22)
	dismiss.add_theme_font_size_override("font_size", 11)
	dismiss.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dismiss.pressed.connect(_dismiss_card.bind(card))
	hbox.add_child(dismiss)

	# Invisible click area over body (excluding dismiss button)
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.size = Vector2(CARD_W - 32, CARD_H)
	click_btn.position = Vector2(0, 0)
	click_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	click_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_btn.pressed.connect(func(): notification_clicked.emit(data))
	card.add_child(click_btn)

	return card

func _restack():
	# Cards grow upward from y=0 (which is footer top)
	var y: float = -CARD_H
	for i in range(_cards.size() - 1, -1, -1):
		var entry = _cards[i]
		if is_instance_valid(entry["panel"]):
			entry["panel"].position = Vector2(0, y)
			y -= (CARD_H + CARD_GAP)

func _dismiss_card(card: Control):
	for i in range(_cards.size()):
		if _cards[i]["panel"] == card:
			_cards.remove_at(i)
			break
	card.queue_free()
	_restack()

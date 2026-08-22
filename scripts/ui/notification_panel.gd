# scripts/ui/notification_panel.gd
# Vertical stack of notification cards on the right side of the screen,
# just above the footer. New cards appear at the bottom and push older ones up.
# Cards persist until the player clicks ✕.
# Clicking the card body fires notification_clicked with the full data dict,
# which can carry an "action" key for the game to route (pan_to, open_event, etc.).
extends Control

const CARD_W   := 272
const CARD_H   := 56
const CARD_GAP := 5
const FOOTER_H := 50   # Must match game_footer height

var _cards: Array = []   # [{panel, data}]

# Emitted when the card BODY (not ✕) is clicked.
# data may contain "action": "pan_to" | "open_event" and related keys.
signal notification_clicked(data: Dictionary)

func _init():
	name = "NotificationPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	_reanchor()

func _reanchor():
	if not get_viewport():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2(vp.x - CARD_W - 12, vp.y - FOOTER_H)
	size = Vector2(CARD_W, 1)

# ---------------------------------------------------------------- public ----

func push(title: String, body: String, icon: String = "⚠",
		color: Color = Color(0.85, 0.55, 0.1), extra_data: Dictionary = {}):
	var data := {"title": title, "body": body, "icon": icon, "color": color}
	data.merge(extra_data)
	var card = _build_card(data)
	add_child(card)
	_cards.append({"panel": card, "data": data})
	_restack()

func clear_all():
	for entry in _cards:
		if is_instance_valid(entry["panel"]):
			entry["panel"].queue_free()
	_cards.clear()

# --------------------------------------------------------------- internals --

func _build_card(data: Dictionary) -> Control:
	var card = Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color           = Color(0.10, 0.10, 0.14, 0.96)
	style.border_color       = data["color"]
	style.border_width_left  = 4
	style.border_width_right = 1
	style.border_width_top   = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	bg.add_theme_stylebox_override("panel", style)
	card.add_child(bg)

	# Clickable body button (whole card minus dismiss zone)
	var body_btn = Button.new()
	body_btn.flat = true
	body_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_btn.offset_right = -28   # leave room for ✕
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		body_btn.add_theme_stylebox_override(s, empty)
	body_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	body_btn.pressed.connect(func(): notification_clicked.emit(data))
	card.add_child(body_btn)

	# Content row (non-interactive, rendered above button)
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_theme_constant_override("margin_left", 10)
	hbox.add_theme_constant_override("margin_right", 6)
	hbox.add_theme_constant_override("margin_top", 4)
	hbox.add_theme_constant_override("margin_bottom", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.custom_minimum_size = Vector2(26, 0)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_lbl)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = data["title"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.clip_text = true
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var body_lbl = Label.new()
	body_lbl.text = data["body"]
	body_lbl.add_theme_font_size_override("font_size", 10)
	body_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	body_lbl.clip_text = true
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body_lbl)

	# Dismiss ✕ — anchored to right edge
	var dismiss = Button.new()
	dismiss.text = "✕"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(26, CARD_H)
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dismiss.add_theme_font_size_override("font_size", 11)
	dismiss.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	dismiss.pressed.connect(_dismiss_card.bind(card))
	hbox.add_child(dismiss)

	return card

func _restack():
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


# scripts/ui/turn_events_modal.gd
# Small modal listing all queued turn-end events.
# Opened by clicking the notification badge above the End Day button.
extends "res://scripts/ui/info_modal.gd"

var _event_manager: Node   # TurnEventManager reference

func _init(event_manager: Node):
	_event_manager = event_manager
	super("turn_events", "Turn Events", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(360, 220)
		size = custom_minimum_size
		# Centre horizontally, appear just above the footer
		position = Vector2((vp.x - size.x) / 2.0, vp.y - size.y - 60)

func refresh_content():
	clear_content()
	if not is_instance_valid(_event_manager):
		return

	var events = _event_manager.get_events()
	if events.is_empty():
		var lbl = Label.new()
		lbl.text = "No events this turn."
		lbl.add_theme_color_override("font_color", Color.GRAY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_content_child(lbl)
		return

	for ev in events:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_content_child(row)

		# Icon / emoji
		var icon_lbl = Label.new()
		icon_lbl.text = ev.get("icon", "⚠")
		icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.custom_minimum_size = Vector2(28, 0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(icon_lbl)

		# Text column
		var text_col = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var title_lbl = Label.new()
		title_lbl.text = ev.get("title", "Event")
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
		text_col.add_child(title_lbl)

		var body_lbl = Label.new()
		body_lbl.text = ev.get("body", "")
		body_lbl.add_theme_font_size_override("font_size", 11)
		body_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(body_lbl)

		add_content_child(HSeparator.new())

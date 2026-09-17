# scripts/ui/announcements_modal.gd
# Popup shown when a player clicks an entry in the main menu's Announcements list.
extends "res://scripts/ui/info_modal.gd"

var announcement: Dictionary = {}

func _init(data: Dictionary, start_position: Vector2 = Vector2.ZERO):
	announcement = data
	super("announcement", data.get("title", "Announcement"), start_position)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(vp.x * 0.32, vp.y * 0.28)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func refresh_content():
	clear_content()

	var date_label = Label.new()
	date_label.text = announcement.get("date", "")
	date_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	date_label.add_theme_font_size_override("font_size", 12)
	add_content_child(date_label)

	add_content_child(HSeparator.new())

	var content_label = Label.new()
	content_label.text = announcement.get("content", "")
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.add_theme_color_override("font_color", Color.WHITE)
	content_label.add_theme_font_size_override("font_size", 14)
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(content_label)

	fit_to_content()

# scripts/ui/roadmap_modal.gd
# Popup shown when a player clicks a milestone in the main menu's Roadmap list.
extends "res://scripts/ui/info_modal.gd"

var milestone: Dictionary = {}

func _init(data: Dictionary, start_position: Vector2 = Vector2.ZERO):
	milestone = data
	var header = "%s — %s" % [data.get("version", ""), data.get("title", "Milestone")]
	super("roadmap", header, start_position)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(vp.x * 0.36, vp.y * 0.5)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func refresh_content():
	clear_content()

	var status: String = milestone.get("status", "")
	var status_label = Label.new()
	status_label.text = "✅ Completed" if status == "completed" else "🔭 Planned"
	status_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6, 1) if status == "completed" else Color(0.85, 0.75, 0.4, 1))
	status_label.add_theme_font_size_override("font_size", 12)
	add_content_child(status_label)

	var summary_label = Label.new()
	summary_label.text = milestone.get("summary", "")
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	summary_label.add_theme_font_size_override("font_size", 13)
	add_content_child(summary_label)

	add_content_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_content_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for highlight in milestone.get("highlights", []):
		var lbl = Label.new()
		lbl.text = "• " + highlight
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 13)
		list.add_child(lbl)

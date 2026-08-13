# scripts/ui/load_game_modal.gd
# Full-screen save browser shown from the main menu.
extends Control

const GAME_SCENE_PATH = "res://scenes/main/game_scene.tscn"

signal back_pressed

func _ready():
	_build_ui()

func _build_ui():
	# Dim background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered panel — manually anchor and offset to true center
	var panel = PanelContainer.new()
	var pw = 620.0
	var ph = 520.0
	panel.custom_minimum_size = Vector2(pw, ph)
	# All four anchors at screen center (0.5, 0.5)
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	# Offsets pull the panel back by half its size in each direction
	panel.offset_left   = -pw / 2.0
	panel.offset_top    = -ph / 2.0
	panel.offset_right  =  pw / 2.0
	panel.offset_bottom =  ph / 2.0
	add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.4, 0.4, 0.5, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var back_btn = Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var title = Label.new()
	title.text = "Load Game"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	# Spacer to balance back button
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(back_btn.custom_minimum_size.x + 16, 0)
	header.add_child(spacer)

	vbox.add_child(HSeparator.new())

	# Scroll area for save list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var saves = SaveLoadManager.get_all_saves_info()

	if saves.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No saved games found."
		empty_lbl.add_theme_color_override("font_color", Color.GRAY)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty_lbl)
	else:
		for save_info in saves:
			list.add_child(_build_save_row(save_info))

	vbox.add_child(HSeparator.new())

	# Footer hint
	var hint = Label.new()
	hint.text = "Click Load to resume a save, or Delete to remove it."
	hint.add_theme_color_override("font_color", Color.DARK_GRAY)
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func _build_save_row(info: Dictionary) -> Control:
	var row_panel = PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.14, 0.14, 0.18, 0.9)
	row_style.border_color = Color(0.3, 0.3, 0.4, 0.6)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	# Save info block
	var info_block = VBoxContainer.new()
	info_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_block.add_theme_constant_override("separation", 2)
	row.add_child(info_block)

	# Save name
	var name_lbl = Label.new()
	name_lbl.text = info["save_name"].capitalize()
	name_lbl.add_theme_color_override("font_color", Color.CYAN)
	name_lbl.add_theme_font_size_override("font_size", 14)
	info_block.add_child(name_lbl)

	# Day and population
	var stats_lbl = Label.new()
	stats_lbl.text = "Day %d  •  Population: %d" % [info["current_day"], info["population"]]
	stats_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stats_lbl.add_theme_font_size_override("font_size", 12)
	info_block.add_child(stats_lbl)

	# Timestamp
	var ts = Time.get_datetime_dict_from_unix_time(info["modified_time"])
	var ts_str = "%04d-%02d-%02d  %02d:%02d" % [ts["year"], ts["month"], ts["day"], ts["hour"], ts["minute"]]
	var time_lbl = Label.new()
	time_lbl.text = ts_str
	time_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
	time_lbl.add_theme_font_size_override("font_size", 11)
	info_block.add_child(time_lbl)

	# Buttons
	var btn_box = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	btn_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn_box)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(80, 30)
	load_btn.add_theme_color_override("font_color", Color.GREEN)
	load_btn.pressed.connect(_on_load_save.bind(info["path"]))
	btn_box.add_child(load_btn)

	var del_btn = Button.new()
	del_btn.text = "Delete"
	del_btn.custom_minimum_size = Vector2(80, 30)
	del_btn.add_theme_color_override("font_color", Color.ORANGE_RED)
	del_btn.pressed.connect(_on_delete_save.bind(info["path"], row_panel))
	btn_box.add_child(del_btn)

	return row_panel

func _on_load_save(path: String):
	GameManager.start_mode = "load"
	GameManager.load_file_path = path
	var err = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if err != OK:
		push_error("LoadGameModal: Failed to change scene. Error: %d" % err)

func _on_delete_save(path: String, row: Control):
	if SaveLoadManager.delete_save(path):
		row.queue_free()
	else:
		push_warning("LoadGameModal: Failed to delete save: " + path)

func _on_back_pressed():
	emit_signal("back_pressed")

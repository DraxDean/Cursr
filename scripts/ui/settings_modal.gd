# scripts/ui/settings_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _active_tab: int = 0

const TABS = ["Gameplay", "UI", "Video", "Audio"]

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("settings", "Settings", start_position)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(vp.x * 0.40, vp.y * 0.60)
		size = custom_minimum_size

func refresh_content():
	clear_content()
	_tab_buttons.clear()
	_tab_panels.clear()

	# Tab bar
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	add_content_child(tab_bar)

	for i in range(TABS.size()):
		var btn = Button.new()
		btn.text = TABS[i]
		btn.toggle_mode = false
		btn.custom_minimum_size = Vector2(90, 30)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	add_content_child(HSeparator.new())

	# Content panels (only one visible at a time)
	var panel_host = Control.new()
	panel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_host.custom_minimum_size = Vector2(0, 300)
	add_content_child(panel_host)

	for i in range(TABS.size()):
		var panel = VBoxContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_constant_override("separation", 10)
		panel.visible = (i == _active_tab)
		panel_host.add_child(panel)
		_tab_panels.append(panel)
		_populate_tab(i, panel)

	_update_tab_styles()

func _populate_tab(index: int, panel: VBoxContainer):
	match index:
		0: _populate_gameplay(panel)
		1: _populate_ui(panel)
		2: _populate_video(panel)
		3: _populate_audio(panel)

func _populate_gameplay(panel: VBoxContainer):
	_section_label(panel, "Gameplay settings coming soon.")

func _populate_ui(panel: VBoxContainer):
	_section_label(panel, "Interface")
	_checkbox_row(panel, "Show Tile Grid", "Highlights hex tile borders on the map.", false)
	_checkbox_row(panel, "Show Unit Paths", "Always display unit movement paths.", false)
	_checkbox_row(panel, "Show Building Labels", "Show building names above structures.", true)
	_checkbox_row(panel, "Compact Population Modal", "Use a condensed population overview.", false)
	_section_label(panel, "HUD")
	_checkbox_row(panel, "Show Resource Rates", "Display per-day rates next to resource totals.", true)
	_checkbox_row(panel, "Show Day Counter", "Show current day in the footer bar.", true)

func _populate_video(panel: VBoxContainer):
	_section_label(panel, "Video settings coming soon.")

func _populate_audio(panel: VBoxContainer):
	_section_label(panel, "Audio settings coming soon.")

# --- Helpers ---

func _section_label(panel: VBoxContainer, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	lbl.add_theme_font_size_override("font_size", 12)
	panel.add_child(lbl)

func _checkbox_row(panel: VBoxContainer, label: String, tooltip: String, default_value: bool):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var cb = CheckBox.new()
	cb.button_pressed = default_value
	cb.tooltip_text = tooltip
	# Not hooked up — mock UI only
	row.add_child(cb)

	var lbl = Label.new()
	lbl.text = label
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.tooltip_text = tooltip
	row.add_child(lbl)

	var desc = Label.new()
	desc.text = tooltip
	desc.add_theme_color_override("font_color", Color.DIM_GRAY)
	desc.add_theme_font_size_override("font_size", 11)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(desc)

func _on_tab_pressed(index: int):
	_active_tab = index
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == index)
	_update_tab_styles()

func _update_tab_styles():
	for i in range(_tab_buttons.size()):
		if i == _active_tab:
			_tab_buttons[i].add_theme_color_override("font_color", Color.CYAN)
		else:
			_tab_buttons[i].remove_theme_color_override("font_color")

# scripts/ui/log_modal.gd
# Game log modal — shows timestamped entries grouped by category tabs.
extends "res://scripts/ui/info_modal.gd"

const GameLogScript = preload("res://scripts/managers/game_log.gd")

var _game_log: Node
var _game: Node  # for re-opening the world event modal on click

func _init(game_log_node: Node, game_reference: Node):
	_game_log = game_log_node
	_game = game_reference
	super("log", "📋 Game Log", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(560, 480)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)
	# Auto-refresh whenever a new entry is added, but only if the modal is open
	if is_instance_valid(_game_log):
		_game_log.entry_added.connect(_on_entry_added)

func _on_entry_added(_entry: Dictionary) -> void:
	if is_open:
		refresh_content()

func refresh_content():
	clear_content()

	var GL = GameLogScript  # for enum/const access

	# Build tab list: "All" + one per category
	var tab_bar = TabBar.new()
	tab_bar.add_tab("All")
	for cat in [GL.Category.EVENT, GL.Category.INCOME, GL.Category.BUILDING, GL.Category.TRAINING,
				GL.Category.RESEARCH, GL.Category.COMBAT, GL.Category.SYSTEM]:
		tab_bar.add_tab(GL.CATEGORY_NAMES[cat])
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(tab_bar)
	add_content_child(HSeparator.new())

	# One scroll page per tab
	var categories = [-1, GL.Category.EVENT, GL.Category.INCOME, GL.Category.BUILDING,
					  GL.Category.TRAINING, GL.Category.RESEARCH, GL.Category.COMBAT, GL.Category.SYSTEM]
	var pages: Array = []
	for cat in categories:
		var scroll = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size   = Vector2(0, 340)
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		scroll.add_child(vbox)
		add_content_child(scroll)
		pages.append({"scroll": scroll, "vbox": vbox, "cat": cat})

	# Fill each page (newest first)
	var all_entries: Array = []
	if is_instance_valid(_game_log):
		all_entries = _game_log.get_all().duplicate()
	all_entries.reverse()

	for page in pages:
		var filtered: Array = all_entries if page["cat"] == -1 \
			else all_entries.filter(func(e): return e["category"] == page["cat"])

		if filtered.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "Nothing recorded yet."
			empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
			empty_lbl.add_theme_font_size_override("font_size", 12)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			page["vbox"].add_child(empty_lbl)
		else:
			for entry in filtered:
				_build_entry_row(page["vbox"], entry)

	# Tab switching
	var _show = func(idx: int):
		for i in pages.size():
			pages[i]["scroll"].visible = (i == idx)
	_show.call(0)
	tab_bar.tab_changed.connect(_show)

func _build_entry_row(vbox: VBoxContainer, entry: Dictionary):
	var GL = GameLogScript
	var cat: int = entry.get("category", GL.Category.SYSTEM)
	var color: Color = GL.CATEGORY_COLORS.get(cat, Color.WHITE)
	var icon: String  = GL.CATEGORY_ICONS.get(cat, "•")
	var event_data: Dictionary = entry.get("event_data", {})
	var has_event: bool = not event_data.is_empty()

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if has_event:
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Click to review this event"
		var normal_bg := StyleBoxEmpty.new()
		var hover_bg := StyleBoxFlat.new()
		hover_bg.bg_color = Color(1, 1, 1, 0.07)
		hover_bg.corner_radius_top_left = 3
		hover_bg.corner_radius_top_right = 3
		hover_bg.corner_radius_bottom_left = 3
		hover_bg.corner_radius_bottom_right = 3
		row.mouse_entered.connect(func(): row.add_theme_stylebox_override("panel", hover_bg))
		row.mouse_exited.connect(func(): row.add_theme_stylebox_override("panel", normal_bg))
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if is_instance_valid(_game) and is_instance_valid(_game.world_event_modal):
					_game.world_event_modal.show_event(event_data)
		)

	vbox.add_child(row)

	# Day badge
	var day_lbl = Label.new()
	day_lbl.text = "Day %d" % entry.get("day", 0)
	day_lbl.custom_minimum_size = Vector2(52, 0)
	day_lbl.add_theme_font_size_override("font_size", 10)
	day_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(day_lbl)

	# Category icon
	var ico = Label.new()
	ico.text = icon
	ico.add_theme_font_size_override("font_size", 14)
	ico.custom_minimum_size = Vector2(20, 0)
	ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ico)

	# Message — use RichTextLabel for bbcode entries, plain Label otherwise
	var msg_text: String = entry.get("message", "")
	if entry.get("bbcode", false):
		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.text = "[color=#%s]%s[/color]" % [color.to_html(false), msg_text]
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.add_theme_font_size_override("normal_font_size", 12)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rtl)
	else:
		var msg = Label.new()
		msg.text = msg_text
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg.add_theme_font_size_override("font_size", 12)
		msg.add_theme_color_override("font_color", color)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(msg)

	vbox.add_child(HSeparator.new())

# scripts/ui/graphs_modal.gd
# Graphs modal — line charts for Resources, Military, and Science over time.
extends "res://scripts/ui/info_modal.gd"

const GameLogScript = preload("res://scripts/managers/game_log.gd")

var _game_log: Node
var _active_tab: int = 0

const RES_KEYS   := ["food", "wood", "stone", "gold", "science"]
const RES_COLORS := {
	"food":    Color(1.0,  0.85, 0.2),
	"wood":    Color(0.3,  0.85, 0.3),
	"stone":   Color(0.65, 0.65, 0.65),
	"gold":    Color(0.85, 0.72, 0.1),
	"science": Color(0.3,  0.9,  1.0),
}
const RES_ICONS := {
	"food":    "🍞",
	"wood":    "🌲",
	"stone":   "■",
	"gold":    "●",
	"science": "🔬",
}

const MIL_KEYS   := ["hp", "atk"]
const MIL_COLORS := {
	"hp":  Color(0.35, 0.90, 0.40),
	"atk": Color(0.95, 0.35, 0.30),
}
const MIL_ICONS := {
	"hp":  "❤",
	"atk": "⚔",
}

# ── Inner line-chart Control ─────────────────────────────────────────────────
class LineChart extends Control:
	var snapshots: Array = []
	var res_colors: Dictionary = {}
	var keys: Array = []

	const PAD_L := 52
	const PAD_R := 16
	const PAD_T := 14
	const PAD_B := 34

	func setup(snaps: Array, colors: Dictionary, res_keys: Array) -> void:
		snapshots = snaps
		res_colors = colors
		keys = res_keys
		queue_redraw()

	func _draw() -> void:
		if snapshots.is_empty():
			return
		var w := size.x
		var h := size.y
		var cw := w - PAD_L - PAD_R
		var ch := h - PAD_T - PAD_B

		# Chart background
		draw_rect(Rect2(PAD_L, PAD_T, cw, ch), Color(0.08, 0.08, 0.08, 1.0))

		# Axis colours / fonts
		var grid_col  := Color(0.22, 0.22, 0.22, 1.0)
		var axis_col  := Color(0.50, 0.50, 0.50, 1.0)
		var label_col := Color(0.55, 0.55, 0.55, 1.0)
		var font      := ThemeDB.fallback_font

		# Y range
		var max_val: int = 1
		for snap in snapshots:
			for key in keys:
				var v: int = int(snap["data"].get(key, 0))
				if v > max_val:
					max_val = v

		# Horizontal grid + Y labels (5 divisions)
		for i in range(6):
			var yf := float(i) / 5.0
			var py := PAD_T + ch * (1.0 - yf)
			draw_line(Vector2(PAD_L, py), Vector2(PAD_L + cw, py), grid_col, 1.0)
			var val_str := str(int(max_val * yf))
			draw_string(font, Vector2(2, py + 4), val_str,
				HORIZONTAL_ALIGNMENT_LEFT, PAD_L - 4, 9, label_col)

		# Axes
		draw_line(Vector2(PAD_L, PAD_T), Vector2(PAD_L, PAD_T + ch), axis_col, 1.5)
		draw_line(Vector2(PAD_L, PAD_T + ch), Vector2(PAD_L + cw, PAD_T + ch), axis_col, 1.5)

		# X axis – day labels
		var min_day: int = snapshots[0]["day"]
		var max_day: int = snapshots[-1]["day"]
		var day_range: int = max(max_day - min_day, 1)
		var label_step: int = max(1, int(ceil(float(day_range) / 10.0)))

		for snap in snapshots:
			var d: int = snap["day"]
			if (d - min_day) % label_step == 0 or d == max_day:
				var xf := float(d - min_day) / float(day_range)
				var px := PAD_L + cw * xf
				draw_line(Vector2(px, PAD_T + ch), Vector2(px, PAD_T + ch + 4), axis_col, 1.0)
				draw_string(font, Vector2(px - 8, h - 4),
					"D%d" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, label_col)

		# Lines + dots per resource
		for key in keys:
			var col: Color = res_colors.get(key, Color.WHITE)
			var prev := Vector2.ZERO
			var first := true
			for snap in snapshots:
				var xf := float(snap["day"] - min_day) / float(day_range)
				var yf := float(int(snap["data"].get(key, 0))) / float(max_val)
				var pt := Vector2(PAD_L + cw * xf, PAD_T + ch * (1.0 - yf))
				if not first:
					draw_line(prev, pt, col, 2.0)
				draw_circle(pt, 3.0, col)
				prev  = pt
				first = false

# ── Modal body ────────────────────────────────────────────────────────────────
func _init(game_log_node: Node) -> void:
	_game_log = game_log_node
	super("graphs", "📊 Graphs", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp := get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(680, 540)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func refresh_content() -> void:
	clear_content()

	var tab_bar := TabBar.new()
	tab_bar.add_tab("📈 Resources")
	tab_bar.add_tab("⚔ Military")
	tab_bar.add_tab("🔬 Science")
	tab_bar.current_tab = _active_tab
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(tab_bar)
	add_content_child(HSeparator.new())

	var resource_page := _build_resource_page()
	var military_page := _build_military_page()
	var science_page  := _build_placeholder("Science tracking coming soon.")

	add_content_child(resource_page)
	add_content_child(military_page)
	add_content_child(science_page)

	var pages := [resource_page, military_page, science_page]
	var _show := func(idx: int) -> void:
		_active_tab = idx
		for i in pages.size():
			pages[i].visible = (i == idx)
	_show.call(_active_tab)
	tab_bar.tab_changed.connect(_show)

func _build_placeholder(msg: String) -> Control:
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size   = Vector2(0, 340)
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	c.add_child(lbl)
	return c

func _build_resource_page() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)

	# Collect snapshots from INCOME log entries
	var snapshots: Array = []
	if is_instance_valid(_game_log):
		var GL := GameLogScript
		for e in _game_log.get_by_category(GL.Category.INCOME):
			var snap: Dictionary = e.get("resource_snapshot", {})
			if not snap.is_empty():
				snapshots.append({"day": e.get("day", 0), "data": snap})

	if snapshots.is_empty():
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, 340)
		var lbl := Label.new()
		lbl.text = "No data yet — end your first day to see the graph."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		c.add_child(lbl)
		container.add_child(c)
		return container

	snapshots.sort_custom(func(a, b): return a["day"] < b["day"])

	# Chart
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(0, 340)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	chart.setup(snapshots, RES_COLORS, RES_KEYS)
	container.add_child(chart)

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	container.add_child(legend)

	for key in RES_KEYS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)

		var swatch := ColorRect.new()
		swatch.color = RES_COLORS[key]
		swatch.custom_minimum_size = Vector2(12, 12)

		var lbl := Label.new()
		lbl.text = RES_ICONS[key] + " " + key.capitalize()
		lbl.add_theme_color_override("font_color", RES_COLORS[key])
		lbl.add_theme_font_size_override("font_size", 11)

		chip.add_child(swatch)
		chip.add_child(lbl)
		legend.add_child(chip)

	return container

func _build_military_page() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)

	# Collect snapshots from INCOME log entries (army strength is snapshotted alongside resources each day)
	var snapshots: Array = []
	if is_instance_valid(_game_log):
		var GL := GameLogScript
		for e in _game_log.get_by_category(GL.Category.INCOME):
			var snap: Dictionary = e.get("army_snapshot", {})
			if not snap.is_empty():
				snapshots.append({"day": e.get("day", 0), "data": snap})

	if snapshots.is_empty():
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, 340)
		var lbl := Label.new()
		lbl.text = "No data yet — end your first day to see the graph."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		c.add_child(lbl)
		container.add_child(c)
		return container

	snapshots.sort_custom(func(a, b): return a["day"] < b["day"])

	# Chart
	var chart := LineChart.new()
	chart.custom_minimum_size = Vector2(0, 340)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	chart.setup(snapshots, MIL_COLORS, MIL_KEYS)
	container.add_child(chart)

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	container.add_child(legend)

	var mil_labels := {"hp": "HP Pool", "atk": "Combat Strength"}
	for key in MIL_KEYS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)

		var swatch := ColorRect.new()
		swatch.color = MIL_COLORS[key]
		swatch.custom_minimum_size = Vector2(12, 12)

		var lbl := Label.new()
		lbl.text = MIL_ICONS[key] + " " + mil_labels.get(key, key.capitalize())
		lbl.add_theme_color_override("font_color", MIL_COLORS[key])
		lbl.add_theme_font_size_override("font_size", 11)

		chip.add_child(swatch)
		chip.add_child(lbl)
		legend.add_child(chip)

	return container

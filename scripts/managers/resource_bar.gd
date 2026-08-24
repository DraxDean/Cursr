# scripts/managers/resource_bar.gd
# Thin persistent bar sitting directly under the game header.
# Shows current amount + per-turn rate for every resource.
extends Control

const HEADER_HEIGHT := 60  # must match game_header.gd size.y
const V_PAD := 6           # vertical padding top and bottom
const FONT_SIZE := 13
const HEIGHT := FONT_SIZE + V_PAD * 2 + 4  # ~30px

var game_ref: Node
var _entries: Dictionary = {}
var _bg: Panel  # StyleBoxFlat panel — resized on refresh

const RESOURCES := [
	{"key": "food",    "icon": "🍞",  "color": Color(1.0,  0.85, 0.2)},
	{"key": "wood",    "icon": "🌲",  "color": Color(0.3,  0.85, 0.3)},
	{"key": "stone",   "icon": "■",   "color": Color(0.65, 0.65, 0.65)},
	{"key": "gold",    "icon": "●",   "color": Color(0.85, 0.72, 0.1)},
	{"key": "science", "icon": "🔬",  "color": Color(0.3,  0.9,  1.0)},
]

func _ready():
	name = "ResourceBar"
	anchor_left   = 0.0
	anchor_top    = 0.0
	anchor_right  = 0.0
	anchor_bottom = 0.0
	position = Vector2(0, HEADER_HEIGHT)
	size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5

	# Styled background — same colour as header, rounded bottom-right corner only
	_bg = Panel.new()
	_bg.name = "BG"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left     = 0
	style.corner_radius_top_right    = 0
	style.corner_radius_bottom_left  = 0
	_bg.add_theme_stylebox_override("panel", style)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# HBox with vertical padding via MarginContainer
	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_top",    V_PAD)
	margin.add_theme_constant_override("margin_bottom", V_PAD)
	margin.add_theme_constant_override("margin_left",   0)
	margin.add_theme_constant_override("margin_right",  0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.name = "ResourceHBox"
	hbox.add_theme_constant_override("separation", 20)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var pad_left = Control.new()
	pad_left.custom_minimum_size = Vector2(12, 0)
	pad_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(pad_left)

	for res in RESOURCES:
		var chip = _make_chip(res)
		hbox.add_child(chip["container"])
		_entries[res["key"]] = chip

	var pad_right = Control.new()
	pad_right.custom_minimum_size = Vector2(12, 0)
	pad_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(pad_right)

	await get_tree().process_frame
	var content_w = margin.get_combined_minimum_size().x
	size = Vector2(content_w, HEIGHT)
	_bg.size = size
	margin.size = size

	# Populate with real values if game_ref is already set
	if game_ref:
		_update_labels()

func _update_labels():
	"""Synchronously update all label text from game_ref data."""
	if not game_ref:
		return
	if game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(1)
	var resources = game_ref.players_data.get(1, {}).get("resources", {})
	var rates = game_ref.get_resource_rates(1) if game_ref.has_method("get_resource_rates") else {}

	for res in RESOURCES:
		var key: String = res["key"]
		if not _entries.has(key):
			continue
		var entry = _entries[key]
		entry["amount"].text = str(int(resources.get(key, 0)))

		var rate: int = int(rates.get(key, 0))
		if rate == 0:
			entry["rate"].text = ""
		else:
			var sign := "+" if rate > 0 else ""
			entry["rate"].text = "(%s%d)" % [sign, rate]
			var col := Color(0.4, 1.0, 0.4) if rate > 0 else Color(1.0, 0.45, 0.45)
			entry["rate"].add_theme_color_override("font_color", col)

func _make_chip(res: Dictionary) -> Dictionary:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_lbl = Label.new()
	icon_lbl.text = res["icon"]
	icon_lbl.add_theme_color_override("font_color", res["color"])
	icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon_lbl)

	var amount_lbl = Label.new()
	amount_lbl.text = "0"
	amount_lbl.add_theme_color_override("font_color", Color.WHITE)
	amount_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	amount_lbl.custom_minimum_size = Vector2(36, 0)
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(amount_lbl)

	var rate_lbl = Label.new()
	rate_lbl.text = ""
	rate_lbl.add_theme_font_size_override("font_size", 11)
	rate_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(rate_lbl)

	return {"container": container, "amount": amount_lbl, "rate": rate_lbl}

func refresh():
	# Update labels synchronously — caller sees values immediately
	_update_labels()

	# Async resize: wait one frame for the layout engine to recalculate min sizes
	var margin = get_node_or_null("Margin")
	if margin:
		await get_tree().process_frame
		var new_w = margin.get_combined_minimum_size().x
		size = Vector2(new_w, HEIGHT)
		if is_instance_valid(_bg):
			_bg.size = size
		margin.size = size


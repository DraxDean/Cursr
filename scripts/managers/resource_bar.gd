# scripts/managers/resource_bar.gd
# Thin persistent bar sitting directly under the game header.
# Shows housing, employment, then current amount + per-turn rate for every resource.
extends Control

const HEADER_HEIGHT := 60  # must match game_header.gd size.y
const V_PAD := 6           # vertical padding top and bottom
const FONT_SIZE := 13
const HEIGHT := FONT_SIZE + V_PAD * 2 + 4  # ~30px

var game_ref: Node
var _entries: Dictionary = {}
var _stat_labels: Dictionary = {}  # "housing", "employment" → Label
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

	# Housing chip — 🏠 10/20
	var housing_chip = _make_stat_chip("🏠", Color(0.85, 0.65, 0.35), "housing")
	hbox.add_child(housing_chip)

	# Separator
	hbox.add_child(_make_separator())

	# Employment chip — 👷 10/10
	var employ_chip = _make_stat_chip("👷", Color(0.55, 0.85, 0.55), "employment")
	hbox.add_child(employ_chip)

	# Separator before resources
	hbox.add_child(_make_separator())

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

func _make_separator() -> Control:
	var sep = Label.new()
	sep.text = "|"
	sep.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	sep.add_theme_font_size_override("font_size", FONT_SIZE)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep

func _make_stat_chip(icon: String, color: Color, key: String) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_lbl = Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon_lbl)

	var val_lbl = Label.new()
	val_lbl.text = "0/0"
	val_lbl.add_theme_color_override("font_color", color)
	val_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(val_lbl)

	_stat_labels[key] = val_lbl
	return container

func _update_labels():
	"""Synchronously update all label text from game_ref data."""
	if not game_ref:
		return
	if game_ref.has_method("update_player_population"):
		game_ref.update_player_population(1)
	if game_ref.has_method("calculate_resource_rates"):
		game_ref.calculate_resource_rates(1)
	var resources = game_ref.players_data.get(1, {}).get("resources", {})
	var rates = game_ref.get_resource_rates(1) if game_ref.has_method("get_resource_rates") else {}
	var pop = game_ref.players_data.get(1, {}).get("population", {})

	# Housing: housed / total
	if _stat_labels.has("housing"):
		var housed: int = pop.get("housed", 0)
		var total: int  = pop.get("total", 0)
		_stat_labels["housing"].text = "%d/%d" % [housed, total]
		# Red if unhoused, green if fully housed
		var col := Color(0.4, 1.0, 0.4) if housed >= total else Color(1.0, 0.45, 0.45)
		_stat_labels["housing"].add_theme_color_override("font_color", col)

	# Employment: working / total
	if _stat_labels.has("employment"):
		var working: int = pop.get("working", 0)
		var total: int   = pop.get("total", 0)
		_stat_labels["employment"].text = "%d/%d" % [working, total]
		var col := Color(0.4, 1.0, 0.4) if working >= total else Color(1.0, 0.85, 0.2)
		_stat_labels["employment"].add_theme_color_override("font_color", col)

	# Resources
	for res in RESOURCES:
		var key: String = res["key"]
		if not _entries.has(key):
			continue
		var entry = _entries[key]
		var amount: int = int(resources.get(key, 0))
		var rate: int   = int(rates.get(key, 0))

		entry["amount"].text = str(amount)

		var sign := "+" if rate > 0 else ""
		entry["rate"].text = "(%s%d)" % [sign, rate]
		var col: Color
		if rate > 0:
			col = Color(0.4, 1.0, 0.4)
		elif rate < 0:
			col = Color(1.0, 0.45, 0.45)
		else:
			col = Color(0.55, 0.55, 0.55)
		entry["rate"].add_theme_color_override("font_color", col)

func _make_chip(res: Dictionary) -> Dictionary:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_lbl = Label.new()
	icon_lbl.text = res["icon"]
	icon_lbl.add_theme_color_override("font_color", res["color"])
	icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon_lbl)

	# Amount + rate sit in a nested HBox with tight separation so they look like one string
	var value_box = HBoxContainer.new()
	value_box.add_theme_constant_override("separation", 2)
	value_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(value_box)

	var amount_lbl = Label.new()
	amount_lbl.text = "0"
	amount_lbl.add_theme_color_override("font_color", Color.WHITE)
	amount_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_box.add_child(amount_lbl)

	var rate_lbl = Label.new()
	rate_lbl.text = "(+0)"
	rate_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	rate_lbl.add_theme_font_size_override("font_size", 11)
	rate_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_box.add_child(rate_lbl)

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


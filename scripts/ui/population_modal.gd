# scripts/ui/population_modal.gd
extends "res://scripts/ui/info_modal.gd"

const TYPE_COLORS := {
	"peasant": Color.LIGHT_GRAY,
	"soldier": Color.CRIMSON,
	"scholar": Color.CORNFLOWER_BLUE
}
const FALLBACK_PALETTE := [Color.ORANGE, Color.MEDIUM_PURPLE, Color.GOLD, Color.SEA_GREEN, Color.SALMON]

const RESOURCE_COLORS := {
	"wood": Color(0.55, 0.35, 0.15),
	"stone": Color(0.6, 0.6, 0.65),
	"food": Color(0.35, 0.75, 0.35),
	"science": Color(0.4, 0.6, 1.0),
	"gold": Color(0.95, 0.8, 0.25)
}
const RESOURCE_LABELS := {
	"wood": "Wood",
	"stone": "Stone",
	"food": "Food",
	"science": "Science",
	"gold": "Gold"
}
# building_type -> resource category (fish + farm work both count as Food)
const JOB_BUILDING_RESOURCE := {
	"lumberjack": "wood",
	"lumber_mill": "wood",
	"stoneworker": "stone",
	"fishing_hut": "food",
	"farmhouse": "food",
	"research": "science",
	"merchant": "gold"
}
const TRAINABLE_TYPES := ["soldier", "scholar", "merchant"]

# One consistent font size/color scheme for every label in this modal
const FONT_SIZE := 14
const COLOR_NUMBER := Color.CYAN              # headline population number
const COLOR_GROWTH := Color(0.15, 0.8, 0.25)  # darker, more vibrant green
const COLOR_HEADER := Color.WHITE

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("population", "Population", start_position)

func refresh_content():
	clear_content()

	var pop_data: Dictionary = {}
	if game_ref and game_ref.has_method("get_player_population_data"):
		pop_data = game_ref.get_player_population_data(1)

	var population: int = pop_data.get("total", 0)
	var working: int = pop_data.get("working", 0)
	var unemployed: int = pop_data.get("unemployed", 0)
	var growth_accumulator: float = pop_data.get("growth_accumulator", 0.0)
	var birth_rate_modifier: float = pop_data.get("birth_rate_modifier", 0.0)
	var growth_rate: float = max(0.0, 0.034 + birth_rate_modifier)
	var daily_growth: float = population * growth_rate

	var turns_for_one: int = 0
	if daily_growth > 0.0:
		turns_for_one = int(ceil((1.0 - growth_accumulator) / daily_growth))

	# ── Headline numbers: total population + growth rate ──
	var total_lbl = Label.new()
	var pop_text = "Population: %d" % population
	if turns_for_one > 0:
		pop_text += "  (+1 in %d turn%s)" % [turns_for_one, "s" if turns_for_one != 1 else ""]
	total_lbl.text = pop_text
	total_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	total_lbl.add_theme_color_override("font_color", COLOR_NUMBER)
	add_content_child(total_lbl)

	var growth_lbl = Label.new()
	growth_lbl.text = "Growth Rate: %.1f%% / day  (%+.2f villagers/day)" % [growth_rate * 100.0, daily_growth]
	growth_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	growth_lbl.add_theme_color_override("font_color", COLOR_GROWTH)
	add_content_child(growth_lbl)

	add_content_child(HSeparator.new())

	# ── Working vs Unemployed pie chart ──
	var employment_slices = [
		{"label": "Working", "value": working, "color": Color(0.3, 0.55, 1.0)},
		{"label": "Unemployed", "value": unemployed, "color": Color(0.55, 0.55, 0.55)}
	]

	# ── Unit roster + resource-employment + training tallies (one pass over the unit list) ──
	var type_counts: Dictionary = {}
	var resource_counts: Dictionary = {}
	var training_in_progress := 0
	var trained_count := 0
	if game_ref and game_ref.get("players_data") != null:
		for unit in game_ref.players_data.get(1, {}).get("units", []):
			var utype = unit.get("type", "peasant")
			type_counts[utype] = type_counts.get(utype, 0) + 1
			if unit.get("training") != null:
				training_in_progress += 1
			elif utype in TRAINABLE_TYPES:
				trained_count += 1
			var resource: String = _get_unit_resource_category(unit)
			if resource != "":
				resource_counts[resource] = resource_counts.get(resource, 0) + 1

	var roster_slices: Array = []
	var palette_i := 0
	for utype in type_counts:
		var color: Color = TYPE_COLORS.get(utype, FALLBACK_PALETTE[palette_i % FALLBACK_PALETTE.size()])
		if not TYPE_COLORS.has(utype):
			palette_i += 1
		roster_slices.append({"label": str(utype).capitalize(), "value": type_counts[utype], "color": color})

	var resource_slices: Array = []
	for resource in RESOURCE_LABELS:
		if resource_counts.has(resource):
			resource_slices.append({
				"label": RESOURCE_LABELS[resource],
				"value": resource_counts[resource],
				"color": RESOURCE_COLORS[resource]
			})

	var training_slices = [
		{"label": "In Training", "value": training_in_progress, "color": Color(1.0, 0.8, 0.2)},
		{"label": "Trained", "value": trained_count, "color": Color(0.4, 0.75, 1.0)}
	]

	# ── Containerized pie charts, laid out side by side ──
	var pies_panel = PanelContainer.new()
	var pies_style = StyleBoxFlat.new()
	pies_style.bg_color = Color(0.12, 0.12, 0.16, 0.85)
	pies_style.set_border_width_all(1)
	pies_style.border_color = Color(0.35, 0.35, 0.4)
	pies_style.set_corner_radius_all(6)
	pies_style.set_content_margin_all(8)
	pies_panel.add_theme_stylebox_override("panel", pies_style)
	add_content_child(pies_panel)

	var pies_row = HBoxContainer.new()
	pies_row.add_theme_constant_override("separation", 14)
	pies_panel.add_child(pies_row)

	pies_row.add_child(_build_pie_section("Employment", employment_slices))
	pies_row.add_child(VSeparator.new())
	pies_row.add_child(_build_pie_section("Unit Roster", roster_slices))
	pies_row.add_child(VSeparator.new())
	pies_row.add_child(_build_pie_section("Resource Employment", resource_slices))
	pies_row.add_child(VSeparator.new())
	pies_row.add_child(_build_pie_section("Training Status", training_slices))

	fit_to_content()

func _get_unit_resource_category(unit: Dictionary) -> String:
	"""Resolve a working unit's job to the resource it produces (wood/stone/food/science/gold),
	or "" if unemployed/stationed somewhere that doesn't produce a resource (e.g. barracks)."""
	var job_name = unit.get("job", null)
	if job_name == null or not is_instance_valid(game_ref):
		return ""
	if not is_instance_valid(game_ref.map_objects_holder):
		return ""
	# unit["job"] is set from a Node's .name, which is a StringName — cast before string ops
	var job_str: String = str(job_name)
	var has_suffix: bool = job_str.ends_with("_station") or job_str.ends_with("_training")
	var building_name: String = job_str.substr(0, job_str.rfind("_")) if has_suffix else job_str
	var building_node = game_ref.map_objects_holder.get_node_or_null(NodePath(building_name))
	if not is_instance_valid(building_node):
		return ""
	var building_type: String = building_node.get_meta("building_type", "")
	return JOB_BUILDING_RESOURCE.get(building_type, "")

func _build_pie_section(title: String, slices: Array) -> Control:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", COLOR_HEADER)
	header.add_theme_font_size_override("font_size", FONT_SIZE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)

	var total: int = 0
	for s in slices:
		total += int(s.get("value", 0))

	if total <= 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No data"
		empty_lbl.add_theme_color_override("font_color", Color.GRAY)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty_lbl)
		return col

	var chart = PieChart.new()
	chart.custom_minimum_size = Vector2(80, 80)
	chart.set_slices(slices)
	var chart_center = CenterContainer.new()
	chart_center.add_child(chart)
	col.add_child(chart_center)

	# Color-coded key underneath the chart with counts and percentages
	for s in slices:
		var value: int = int(s.get("value", 0))
		if value <= 0:
			continue
		var pct: float = (float(value) / float(total)) * 100.0
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(row)
		var dot = Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", s.get("color", Color.WHITE))
		dot.custom_minimum_size = Vector2(16, 18)
		row.add_child(dot)
		var lbl = Label.new()
		lbl.text = "%s: %d (%.0f%%)" % [s.get("label", "?"), value, pct]
		lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(lbl)

	return col
# scripts/ui/science_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
const TechTree = preload("res://scripts/managers/tech_tree.gd")

var selected_tech: String = ""
var details_panel: VBoxContainer
var tree_container: VBoxContainer

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("science", "Science & Research", start_position)

func _ready():
	super._ready()
	# Science modal needs room for the side-by-side details + tree layout
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(max(custom_minimum_size.x, vp.x * 0.55), vp.y * 0.7)
		size = custom_minimum_size

func refresh_content():
	clear_content()

	var player_id = 1
	var player_data = game_ref.players_data.get(player_id, {}) if game_ref else {}
	var resources = player_data.get("resources", {})
	var science_total = resources.get("science", 0)

	var resource_rates = {}
	if game_ref and game_ref.has_method("get_resource_rates"):
		resource_rates = game_ref.get_resource_rates(player_id)
	var science_rate = resource_rates.get("science", 0)

	# ── Science summary row ──────────────────────────────────────
	var summary_row = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	add_content_child(summary_row)

	var sci_label = Label.new()
	sci_label.text = "🔬 Science:"
	sci_label.add_theme_color_override("font_color", Color.CYAN)
	sci_label.custom_minimum_size = Vector2(110, 0)
	summary_row.add_child(sci_label)

	var sci_value = Label.new()
	sci_value.text = str(science_total) + "  (+" + str(science_rate) + "/day)"
	sci_value.add_theme_color_override("font_color", Color.WHITE)
	summary_row.add_child(sci_value)

	add_content_child(HSeparator.new())

	# ── Two-panel layout: research details (left) + tech tree (right) ───
	var main_row = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 16)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_content_child(main_row)

	# LEFT: research details panel
	details_panel = VBoxContainer.new()
	details_panel.custom_minimum_size = Vector2(220, 300)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_constant_override("separation", 8)
	main_row.add_child(details_panel)

	main_row.add_child(VSeparator.new())

	# RIGHT: scrollable vertical tech tree, grouped into labelled category sections
	var tree_scroll = ScrollContainer.new()
	tree_scroll.custom_minimum_size = Vector2(260, 300)
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(tree_scroll)

	tree_container = VBoxContainer.new()
	tree_container.add_theme_constant_override("separation", 6)
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.add_child(tree_container)

	if selected_tech == "":
		selected_tech = TechTree.TECHS[0]["id"]

	for cat_index in range(TechTree.CATEGORIES.size()):
		var category = TechTree.CATEGORIES[cat_index]
		if cat_index > 0:
			tree_container.add_child(HSeparator.new())

		var cat_header = Label.new()
		cat_header.text = category["name"]
		cat_header.add_theme_font_size_override("font_size", 13)
		cat_header.add_theme_color_override("font_color", Color.YELLOW)
		tree_container.add_child(cat_header)

		var roots = TechTree.TECHS.filter(func(t): return t["category"] == category["id"] and (t["prereq"] == "" or t["prereq"] == TechTree.ALL_PREREQ))
		for i in range(roots.size()):
			_render_tech_node(player_id, roots[i], 0, true)

	_render_details(player_id, selected_tech)

	# Resize background to fit all content
	fit_to_content()

func _render_tech_node(player_id: int, tech: Dictionary, depth: int, is_last: bool):
	"""Render one ASCII-tree row (icon node + connector) and recurse into its children"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	tree_container.add_child(row)

	if depth > 0:
		var indent = Label.new()
		indent.text = "     ".repeat(depth - 1)
		row.add_child(indent)

		var connector = Label.new()
		connector.text = "└──▶ " if is_last else "├──▶ "
		connector.add_theme_color_override("font_color", Color.GRAY)
		connector.add_theme_font_size_override("font_size", 13)
		row.add_child(connector)

	row.add_child(_make_tech_node_widget(player_id, tech))

	var children = TechTree.TECHS.filter(func(t): return t["prereq"] == tech["id"])
	for i in range(children.size()):
		_render_tech_node(player_id, children[i], depth + 1, i == children.size() - 1)

func _make_tech_node_widget(player_id: int, tech: Dictionary) -> Control:
	"""A rounded-square icon button + caption labels representing one tech node"""
	var tech_id = tech["id"]
	var max_level = tech.get("max_level", 10)
	var technologies = game_ref.players_data.get(player_id, {}).get("technologies", {}) if game_ref else {}
	var current_level = technologies.get(tech_id, 0)
	var prereq_met = TechTree.prereq_met(technologies, tech_id)

	var maxed = current_level >= max_level
	var is_selected = tech_id == selected_tech

	var wrapper = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	wrapper.custom_minimum_size = Vector2(74, 0)

	var node_button = Button.new()
	node_button.text = tech["icon"]
	node_button.add_theme_font_size_override("font_size", 24)
	node_button.custom_minimum_size = Vector2(56, 56)
	node_button.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(3 if is_selected else 2)
	if maxed:
		style.bg_color = Color(0.28, 0.22, 0.05, 1.0)
		style.border_color = Color.GOLD
	elif not prereq_met:
		style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	else:
		style.bg_color = Color(0.1, 0.2, 0.25, 1.0)
		style.border_color = Color.CYAN
	if is_selected:
		style.border_color = Color.WHITE

	for state in ["normal", "hover", "pressed", "focus"]:
		node_button.add_theme_stylebox_override(state, style)

	node_button.pressed.connect(_on_tech_node_pressed.bind(tech_id))
	wrapper.add_child(node_button)

	var caption = Label.new()
	caption.text = tech["name"]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color.WHITE if prereq_met else Color(0.5, 0.5, 0.5))
	wrapper.add_child(caption)

	var level_caption = Label.new()
	level_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_caption.add_theme_font_size_override("font_size", 9)
	if maxed:
		level_caption.text = "MAX" if max_level > 1 else "DONE"
		level_caption.add_theme_color_override("font_color", Color.GOLD)
	else:
		level_caption.text = "Lv %d/%d" % [current_level, max_level]
		level_caption.add_theme_color_override("font_color", Color.CYAN if prereq_met else Color(0.5, 0.5, 0.5))
	wrapper.add_child(level_caption)

	return wrapper

func _render_details(player_id: int, tech_id: String):
	"""Populate the left-hand details panel for the currently selected tech node"""
	for child in details_panel.get_children():
		child.queue_free()

	var tech = TechTree.get_tech(tech_id)
	if tech.is_empty():
		var placeholder = Label.new()
		placeholder.text = "Select a technology\nfrom the tree to view details."
		placeholder.add_theme_color_override("font_color", Color.GRAY)
		details_panel.add_child(placeholder)
		return

	var max_level = tech.get("max_level", 10)
	var technologies = game_ref.players_data.get(player_id, {}).get("technologies", {}) if game_ref else {}
	var current_level = technologies.get(tech_id, 0)
	var prereq_met = TechTree.prereq_met(technologies, tech_id)

	var next_cost := 0
	if game_ref and game_ref.has_method("get_tech_cost"):
		next_cost = game_ref.get_tech_cost(current_level)

	# Header: icon + name
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	details_panel.add_child(header_row)

	var icon_label = Label.new()
	icon_label.text = tech["icon"]
	icon_label.add_theme_font_size_override("font_size", 28)
	header_row.add_child(icon_label)

	var name_label = Label.new()
	name_label.text = tech["name"]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE if prereq_met else Color(0.5, 0.5, 0.5))
	header_row.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = tech["desc"]
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_panel.add_child(desc_label)

	var prereq = tech.get("prereq", "")
	if prereq != "":
		var prereq_label = Label.new()
		if prereq == TechTree.ALL_PREREQ:
			prereq_label.text = "Requires: every other technology researched"
		else:
			var prereq_tech = TechTree.get_tech(prereq)
			prereq_label.text = "Requires: %s (Lvl 1+)" % prereq_tech.get("name", prereq)
		prereq_label.add_theme_font_size_override("font_size", 10)
		prereq_label.add_theme_color_override("font_color", Color.GRAY if prereq_met else Color.ORANGE)
		details_panel.add_child(prereq_label)

	details_panel.add_child(HSeparator.new())

	# Level row + progress bar
	var level_label = Label.new()
	if current_level >= max_level:
		level_label.text = "MAX LEVEL" if max_level > 1 else "RESEARCHED"
		level_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		level_label.text = "Level %d / %d" % [current_level, max_level]
		level_label.add_theme_color_override("font_color", Color.CYAN)
	details_panel.add_child(level_label)

	var progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = max_level
	progress.value = current_level
	progress.custom_minimum_size = Vector2(0, 14)
	progress.show_percentage = false
	details_panel.add_child(progress)

	# Research button
	var research_btn = Button.new()
	if current_level >= max_level:
		research_btn.text = "Fully Researched"
		research_btn.disabled = true
	elif not prereq_met:
		if prereq == TechTree.ALL_PREREQ:
			research_btn.text = "Locked (requires ALL other tech)"
		else:
			var prereq_tech = TechTree.get_tech(prereq)
			research_btn.text = "Locked (requires %s)" % prereq_tech.get("name", "prerequisite")
		research_btn.disabled = true
	else:
		research_btn.text = "Research  (cost: %d 🔬)" % next_cost
		research_btn.disabled = false
		research_btn.pressed.connect(_on_research_pressed.bind(player_id, tech_id))
	research_btn.custom_minimum_size = Vector2(0, 32)
	details_panel.add_child(research_btn)

func _on_tech_node_pressed(tech_id: String):
	selected_tech = tech_id
	refresh_content()

func _on_research_pressed(player_id: int, tech_id: String):
	if game_ref and game_ref.has_method("research_tech"):
		game_ref.research_tech(player_id, tech_id)
	refresh_content()

func _on_spend_science_pressed():
	if not game_ref:
		return
	var player_id = 1
	var player_data = game_ref.players_data.get(player_id, {})
	var resources = player_data.get("resources", {})
	var current = resources.get("science", 0)
	if current < 5:
		DebugConfig.dprint("ui", ["ScienceModal: Not enough science to spend (have %d)" % current])
		return
	resources["science"] = current - 5
	player_data["resources"] = resources
	game_ref.players_data[player_id] = player_data
	DebugConfig.dprint("ui", ["ScienceModal: Spent 5 science. Remaining: %d" % resources["science"]])
	refresh_content()


# scripts/ui/science_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node
const MAX_LEVEL := 10

# Tech tree definition: id, display name, description, prerequisite id (or "")
const TECHS := [
	{
		"id": "work_ethic",
		"name": "Work Ethic",
		"desc": "+5% to ALL resource production per level",
		"prereq": "",
		"tier": 0  # horizontal position hint
	},
	{
		"id": "fishing_bonus",
		"name": "Fishing Mastery",
		"desc": "+5% food from fishing per level",
		"prereq": "work_ethic",
		"tier": 0
	},
	{
		"id": "woodcutting_bonus",
		"name": "Woodcutting Mastery",
		"desc": "+5% wood production per level",
		"prereq": "work_ethic",
		"tier": 1
	},
	{
		"id": "stoneworking_bonus",
		"name": "Stoneworking Mastery",
		"desc": "+5% stone production per level",
		"prereq": "work_ethic",
		"tier": 2
	}
]

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("science", "Science & Research", start_position)

func _ready():
	super._ready()
	# Science modal is taller than the default 33% — expand to fit the tech tree
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(max(custom_minimum_size.x, vp.x * 0.30), vp.y * 0.75)
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

	# ── Separator ────────────────────────────────────────────────
	var sep = HSeparator.new()
	add_content_child(sep)

	# ── Tree title ───────────────────────────────────────────────
	var tree_title = Label.new()
	tree_title.text = "Technology Tree"
	tree_title.add_theme_font_size_override("font_size", 14)
	tree_title.add_theme_color_override("font_color", Color.YELLOW)
	add_content_child(tree_title)

	# ── Row 1: Work Ethic (root) ─────────────────────────────────
	_add_tech_card(player_id, TECHS[0])

	# ── Connector hint ───────────────────────────────────────────
	var connector = Label.new()
	connector.text = "  └─ Unlocks after Work Ethic lvl 1:"
	connector.add_theme_color_override("font_color", Color.GRAY)
	connector.add_theme_font_size_override("font_size", 11)
	add_content_child(connector)

	# ── Row 2: the three children (indented) ────────────────────
	for i in range(1, TECHS.size()):
		_add_tech_card(player_id, TECHS[i], true)

	# Resize background to fit all content
	fit_to_content()

func _add_tech_card(player_id: int, tech: Dictionary, indented: bool = false):
	"""Build a card row for one technology"""
	var wrapper = VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)
	if indented:
		var hpad = HBoxContainer.new()
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		hpad.add_child(spacer)
		hpad.add_child(wrapper)
		hpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_content_child(hpad)
	else:
		add_content_child(wrapper)

	var tech_id = tech["id"]
	var current_level = 0
	var prereq_met = true

	if game_ref:
		if game_ref.has_method("get_tech_level"):
			current_level = game_ref.get_tech_level(player_id, tech_id)
		var prereq = tech.get("prereq", "")
		if prereq != "" and game_ref.has_method("get_tech_level"):
			prereq_met = game_ref.get_tech_level(player_id, prereq) >= 1

	var next_cost := 0
	if game_ref and game_ref.has_method("get_tech_cost"):
		next_cost = game_ref.get_tech_cost(current_level)

	# Header row: name + level badge
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(header_row)

	var name_label = Label.new()
	name_label.text = tech["name"]
	name_label.add_theme_font_size_override("font_size", 13)
	var name_color = Color.WHITE if prereq_met else Color(0.5, 0.5, 0.5)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var level_label = Label.new()
	if current_level >= MAX_LEVEL:
		level_label.text = "MAX"
		level_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		level_label.text = "Lvl %d/%d" % [current_level, MAX_LEVEL]
		level_label.add_theme_color_override("font_color", Color.CYAN)
	header_row.add_child(level_label)

	# Description row
	var desc_label = Label.new()
	desc_label.text = tech["desc"]
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	wrapper.add_child(desc_label)

	# Progress bar
	var progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = MAX_LEVEL
	progress.value = current_level
	progress.custom_minimum_size = Vector2(0, 14)
	progress.show_percentage = false
	wrapper.add_child(progress)

	# Buy button row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	wrapper.add_child(btn_row)

	var research_btn = Button.new()
	if current_level >= MAX_LEVEL:
		research_btn.text = "Fully Researched"
		research_btn.disabled = true
	elif not prereq_met:
		research_btn.text = "Locked (requires %s)" % TECHS[0]["name"]
		research_btn.disabled = true
	else:
		research_btn.text = "Research  (cost: %d 🔬)" % next_cost
		research_btn.disabled = false
		research_btn.pressed.connect(_on_research_pressed.bind(player_id, tech_id))

	research_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_btn.custom_minimum_size = Vector2(0, 30)
	btn_row.add_child(research_btn)

	# Tiny separator after each card — always inside wrapper so layout is consistent
	var card_sep = HSeparator.new()
	card_sep.custom_minimum_size = Vector2(0, 6)
	wrapper.add_child(card_sep)

func _on_research_pressed(player_id: int, tech_id: String):
	if game_ref and game_ref.has_method("research_tech"):
		game_ref.research_tech(player_id, tech_id, MAX_LEVEL)
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


# scripts/ui/science_modal.gd
extends "res://scripts/ui/info_modal.gd"

var game_ref: Node

func _init(game_reference: Node, start_position: Vector2 = Vector2.ZERO):
	game_ref = game_reference
	super("science", "Science & Research", start_position)

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

	# Science total row
	var total_row = HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)
	add_content_child(total_row)

	var total_icon = Label.new()
	total_icon.text = "🔬"
	total_row.add_child(total_icon)

	var total_label = Label.new()
	total_label.text = "Science:"
	total_label.add_theme_color_override("font_color", Color.CYAN)
	total_label.custom_minimum_size = Vector2(100, 0)
	total_row.add_child(total_label)

	var total_value = Label.new()
	total_value.text = str(science_total)
	total_value.add_theme_color_override("font_color", Color.WHITE)
	total_row.add_child(total_value)

	# Science rate row
	var rate_row = HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 10)
	add_content_child(rate_row)

	var rate_spacer = Label.new()
	rate_spacer.text = "  "
	rate_spacer.custom_minimum_size = Vector2(22, 0)
	rate_row.add_child(rate_spacer)

	var rate_label = Label.new()
	rate_label.text = "Per day:"
	rate_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	rate_label.custom_minimum_size = Vector2(100, 0)
	rate_row.add_child(rate_label)

	var rate_value = Label.new()
	rate_value.text = ("+" if science_rate >= 0 else "") + str(science_rate)
	rate_value.add_theme_color_override("font_color", Color.CYAN if science_rate > 0 else Color.GRAY)
	rate_row.add_child(rate_value)

	# Separator
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 10)
	add_content_child(sep)

	# Placeholder tech tree notice
	var notice = Label.new()
	notice.text = "Tech tree coming soon.\nFor now, use the button below to spend science."
	notice.add_theme_color_override("font_color", Color.GRAY)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	notice.custom_minimum_size = Vector2(280, 0)
	add_content_child(notice)

	# Spend Science test button
	var spend_btn = Button.new()
	spend_btn.text = "Spend Science (-5)"
	spend_btn.custom_minimum_size = Vector2(200, 36)
	spend_btn.pressed.connect(_on_spend_science_pressed)
	add_content_child(spend_btn)

func _on_spend_science_pressed():
	if not game_ref:
		return
	var player_id = 1
	var player_data = game_ref.players_data.get(player_id, {})
	var resources = player_data.get("resources", {})
	var current = resources.get("science", 0)
	if current < 5:
		print("ScienceModal: Not enough science to spend (have %d)" % current)
		return
	resources["science"] = current - 5
	player_data["resources"] = resources
	game_ref.players_data[player_id] = player_data
	print("ScienceModal: Spent 5 science. Remaining: %d" % resources["science"])
	# Refresh modal to show updated value
	refresh_content()

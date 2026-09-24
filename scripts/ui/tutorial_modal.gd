# scripts/ui/tutorial_modal.gd
# Paginated popup for a single tutorial's pages, with prev/next navigation.
extends "res://scripts/ui/info_modal.gd"

var _tutorial: Dictionary = {}
var _page_index: int = 0

func _init():
	super("tutorial", "📘 Tutorial", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(690, 570)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func show_tutorial(tutorial_id: String) -> void:
	var tutorial: Dictionary = TutorialManager.get_tutorial(tutorial_id)
	if tutorial.is_empty():
		return
	_tutorial = tutorial
	_page_index = 0
	if title_label:
		title_label.text = "%s %s" % [tutorial.get("icon", "📘"), tutorial.get("title", "Tutorial")]
	if not is_open:
		toggle()
	else:
		move_to_front()
		refresh_content()

func _build_image_box(image_path: String) -> PanelContainer:
	"""One image slot — falls back to a placeholder icon if the path is empty/missing."""
	var image_box = PanelContainer.new()
	image_box.custom_minimum_size = Vector2(0, 220)
	image_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.45)
	style.set_corner_radius_all(4)
	image_box.add_theme_stylebox_override("panel", style)
	if image_path != "" and ResourceLoader.exists(image_path):
		var tex_rect = TextureRect.new()
		tex_rect.texture = load(image_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_box.add_child(tex_rect)
	else:
		var image_lbl = Label.new()
		image_lbl.text = "🖼"
		image_lbl.add_theme_font_size_override("font_size", 32)
		image_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		image_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image_box.add_child(image_lbl)
	return image_box


func refresh_content():
	clear_content()
	if _tutorial.is_empty():
		return

	var pages: Array = _tutorial.get("pages", [])
	if pages.is_empty():
		return
	_page_index = clampi(_page_index, 0, pages.size() - 1)
	var page: Dictionary = pages[_page_index]

	# Extra breathing room around the page content, beyond the modal's base padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_content_child(margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(body_vbox)

	var heading_lbl = Label.new()
	heading_lbl.text = page.get("heading", "")
	heading_lbl.add_theme_color_override("font_color", Color.CYAN)
	heading_lbl.add_theme_font_size_override("font_size", 16)
	body_vbox.add_child(heading_lbl)

	body_vbox.add_child(HSeparator.new())

	# Step image(s) — a page can define a single "image" or an "images" array shown side by
	# side (e.g. a before/after pair); falls back to a placeholder icon if none are set.
	var image_paths: Array = page.get("images", [])
	if image_paths.is_empty() and page.get("image", "") != "":
		image_paths = [page["image"]]

	if image_paths.size() > 1:
		var images_row = HBoxContainer.new()
		images_row.add_theme_constant_override("separation", 10)
		for path in image_paths:
			images_row.add_child(_build_image_box(str(path)))
		body_vbox.add_child(images_row)
	else:
		body_vbox.add_child(_build_image_box(image_paths[0] if not image_paths.is_empty() else ""))

	var body_lbl = Label.new()
	body_lbl.text = page.get("body", "")
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_child(body_lbl)

	body_vbox.add_child(HSeparator.new())

	# Navigation row — prev / page counter / next
	var nav_row = HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 14)
	body_vbox.add_child(nav_row)

	var prev_btn = Button.new()
	prev_btn.text = "◀ Previous"
	prev_btn.disabled = _page_index <= 0
	prev_btn.custom_minimum_size = Vector2(100, 30)
	prev_btn.pressed.connect(_on_prev_pressed)
	nav_row.add_child(prev_btn)

	var counter_lbl = Label.new()
	counter_lbl.text = "Page %d / %d" % [_page_index + 1, pages.size()]
	counter_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	counter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav_row.add_child(counter_lbl)

	var next_btn = Button.new()
	next_btn.text = "Next ▶"
	next_btn.disabled = _page_index >= pages.size() - 1
	next_btn.custom_minimum_size = Vector2(100, 30)
	next_btn.pressed.connect(_on_next_pressed)
	nav_row.add_child(next_btn)

func _on_prev_pressed() -> void:
	if _page_index > 0:
		_page_index -= 1
		refresh_content()

func _on_next_pressed() -> void:
	var pages: Array = _tutorial.get("pages", [])
	if _page_index < pages.size() - 1:
		_page_index += 1
		refresh_content()

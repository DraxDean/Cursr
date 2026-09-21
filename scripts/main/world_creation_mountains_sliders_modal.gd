# scripts/main/world_creation_mountains_sliders_modal.gd
# Side panel shown during the combined "Let there be Mountains" step — controls chain count,
# range size, peak sharpness (circular vs. elongated "eye" shape) and object density, then
# redraws both the mountain terrain and the mountain objects on demand.
extends Control

const PANEL_WIDTH := 260

var _world_creation: Node  # world_creation_modal.gd instance
var _panel: PanelContainer
var _num_ranges_slider: HSlider
var _range_size_slider: HSlider
var _peak_sharpness_slider: HSlider
var _density_slider: HSlider
var _num_ranges_value_lbl: Label
var _range_size_value_lbl: Label
var _peak_sharpness_value_lbl: Label
var _density_value_lbl: Label

func setup_integrated(world_creation_ref: Node, ui_layer: Node) -> void:
	_world_creation = world_creation_ref
	name = "MountainsSlidersModal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(self)
	_build_ui()
	# Let the container finish one layout pass so _panel.size reflects real content before
	# we position it (anchor math computed before content exists ends up mis-centered).
	await get_tree().process_frame
	_reposition_panel()

func _build_ui():
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.5, 0.55, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Mountain Settings"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_num_ranges_slider = HSlider.new()
	_num_ranges_value_lbl = Label.new()
	_build_slider_row(vbox, "Number of Ranges", _world_creation.mountain_num_ranges, _num_ranges_slider, _num_ranges_value_lbl, 0.0, 6.0, 1.0, "%d")

	_range_size_slider = HSlider.new()
	_range_size_value_lbl = Label.new()
	_build_slider_row(vbox, "Range Size", _world_creation.mountain_range_size, _range_size_slider, _range_size_value_lbl, 0.0, 1.0, 0.01, "pct")

	_peak_sharpness_slider = HSlider.new()
	_peak_sharpness_value_lbl = Label.new()
	_build_slider_row(vbox, "Peak Sharpness", _world_creation.mountain_peak_sharpness, _peak_sharpness_slider, _peak_sharpness_value_lbl, 0.0, 1.0, 0.01, "pct")

	var sharpness_hint = Label.new()
	sharpness_hint.text = "Circular  ⟷  Eye-shaped"
	sharpness_hint.add_theme_font_size_override("font_size", 10)
	sharpness_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sharpness_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sharpness_hint)

	_density_slider = HSlider.new()
	_density_value_lbl = Label.new()
	_build_slider_row(vbox, "Density", _world_creation.mountain_density, _density_slider, _density_value_lbl, 0.0, 1.0, 0.01, "pct")

	vbox.add_child(HSeparator.new())

	var regen_btn = Button.new()
	regen_btn.text = "Regenerate"
	regen_btn.custom_minimum_size = Vector2(0, 34)
	regen_btn.pressed.connect(_on_regenerate_pressed)
	vbox.add_child(regen_btn)

func _build_slider_row(parent: VBoxContainer, label_text: String, initial_value: float, slider: HSlider, value_lbl: Label, min_v: float, max_v: float, step_v: float, format: String):
	var header_row = HBoxContainer.new()
	parent.add_child(header_row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl)

	value_lbl.text = _format_value(initial_value, format)
	value_lbl.custom_minimum_size = Vector2(40, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(value_lbl)

	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(0, 20)
	slider.value_changed.connect(_on_slider_value_changed.bind(value_lbl, format))
	parent.add_child(slider)

func _format_value(value: float, format: String) -> String:
	if format == "pct":
		return "%d%%" % int(round(value * 100))
	return "%d" % int(round(value))

func _on_slider_value_changed(value: float, value_lbl: Label, format: String):
	value_lbl.text = _format_value(value, format)

func _on_regenerate_pressed():
	if is_instance_valid(_world_creation):
		_world_creation.regenerate_mountains_from_sliders(
			int(round(_num_ranges_slider.value)),
			_range_size_slider.value,
			_peak_sharpness_slider.value,
			_density_slider.value
		)

func _reposition_panel():
	if not is_instance_valid(_panel) or not get_viewport():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x - _panel.size.x - 20, 150)

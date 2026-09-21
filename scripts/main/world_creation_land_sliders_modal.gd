# scripts/main/world_creation_land_sliders_modal.gd
# Small side panel shown only during the "Let there be Land" step — lets the player tune
# landmass size and coastline noise with sliders, then redraw the map on demand.
extends Control

const PANEL_WIDTH := 260

var _world_creation: Node  # world_creation_modal.gd instance
var _panel: PanelContainer
var _landmass_slider: HSlider
var _coast_slider: HSlider
var _landmass_value_lbl: Label
var _coast_value_lbl: Label

func setup_integrated(world_creation_ref: Node, ui_layer: Node) -> void:
	_world_creation = world_creation_ref
	name = "LandSlidersModal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(self)
	_build_ui()
	# Let the panel's container finish one layout pass so _panel.size reflects real content
	# before we position it — avoids the "anchor math computed before content exists" bug.
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
	title.text = "Terrain Settings"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_landmass_slider = HSlider.new()
	_landmass_value_lbl = Label.new()
	_build_slider_row(vbox, "Landmass", _world_creation.land_landmass_value, _landmass_slider, _landmass_value_lbl)

	_coast_slider = HSlider.new()
	_coast_value_lbl = Label.new()
	_build_slider_row(vbox, "Coast Noise", _world_creation.land_coast_noise_value, _coast_slider, _coast_value_lbl)

	vbox.add_child(HSeparator.new())

	var regen_btn = Button.new()
	regen_btn.text = "Regenerate"
	regen_btn.custom_minimum_size = Vector2(0, 34)
	regen_btn.pressed.connect(_on_regenerate_pressed)
	vbox.add_child(regen_btn)

func _build_slider_row(parent: VBoxContainer, label_text: String, initial_value: float, slider: HSlider, value_lbl: Label):
	var header_row = HBoxContainer.new()
	parent.add_child(header_row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl)

	value_lbl.text = "%d%%" % int(round(initial_value * 100))
	value_lbl.custom_minimum_size = Vector2(40, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(value_lbl)

	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(0, 20)
	slider.value_changed.connect(_on_slider_value_changed.bind(value_lbl))
	parent.add_child(slider)

func _on_slider_value_changed(value: float, value_lbl: Label):
	value_lbl.text = "%d%%" % int(round(value * 100))

func _on_regenerate_pressed():
	if is_instance_valid(_world_creation):
		_world_creation.regenerate_land_from_sliders(_landmass_slider.value, _coast_slider.value)

func _reposition_panel():
	if not is_instance_valid(_panel) or not get_viewport():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x - _panel.size.x - 20, 150)

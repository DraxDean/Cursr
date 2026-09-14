# scripts/ui/formation_grid.gd
# Shared helper for rendering an army's unit sprites as a formation grid (army modal + combat modal).
class_name FormationGrid

static func role_color(role: String) -> Color:
	if role == "soldier":
		return Color(0.4, 1.0, 0.4)
	elif role == "soldier_training":
		return Color(1.0, 0.85, 0.3)
	elif role == "marauder":
		return Color(1.0, 0.5, 0.4)
	return Color.LIGHT_GRAY

static func build(units: Array, game_ref: Node, columns: int = 5, icon_size: int = 28) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for unit in units:
		grid.add_child(build_icon(unit, game_ref, icon_size))
	return grid

static func build_icon(unit: Dictionary, game_ref: Node, icon_size: int = 28) -> Control:
	"""Bordered thumbnail of a unit's sprite, tinted by army role."""
	var role: String = game_ref.get_unit_army_role(unit)

	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(icon_size + 4, icon_size + 4)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	style.set_border_width_all(1)
	style.border_color = role_color(role)
	style.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", style)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path: String = game_ref._get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"))
	if ResourceLoader.exists(texture_path):
		icon.texture = load(texture_path)
	if game_ref._unit_sprite_is_reversed(unit):
		icon.flip_h = true
	icon.tooltip_text = "%s — %s" % [unit.get("name", "Unit"), game_ref.ARMY_UNIT_STATS[role]["label"]]
	frame.add_child(icon)

	return frame

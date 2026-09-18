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
	var texture_path: String = game_ref._get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"), unit)
	if ResourceLoader.exists(texture_path):
		icon.texture = load(texture_path)
	if game_ref._unit_sprite_is_reversed(unit):
		icon.flip_h = true
	icon.tooltip_text = "%s — %s" % [unit.get("name", "Unit"), game_ref.ARMY_UNIT_STATS[role]["label"]]
	frame.add_child(icon)

	return frame

static func build_plain_icon(unit: Dictionary, game_ref: Node, icon_size: int = 26) -> Control:
	"""Bare sprite, no border/background square — used by the staggered army formation."""
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path: String = game_ref._get_unit_sprite_path(unit.get("race", "human"), unit.get("gender", "male"), unit.get("type", "peasant"), unit)
	if ResourceLoader.exists(texture_path):
		icon.texture = load(texture_path)
	if game_ref._unit_sprite_is_reversed(unit):
		icon.flip_h = true
	var role: String = game_ref.get_unit_army_role(unit)
	icon.tooltip_text = "%s — %s" % [unit.get("name", "Unit"), game_ref.ARMY_UNIT_STATS[role]["label"]]
	return icon

static func _distribute_row_sizes(count: int, row_width_cap: int) -> Array:
	"""Split `count` units into rows, widening (more rows) rather than exceeding the row
	width cap. Leftover units are handed out to every OTHER row outward from the center
	(center, center+2, center-2, ...) before falling back to the skipped rows, so the extra
	units alternate thick/thin down the ranks instead of clustering into one solid band."""
	if count <= 0:
		return []
	var rows: int = max(1, int(round(sqrt(count))))
	while float(count) / float(rows) > row_width_cap:
		rows += 1
	var sizes: Array = []
	sizes.resize(rows)
	sizes.fill(count / rows)
	var remainder: int = count % rows
	var center: int = rows / 2

	var order: Array = []
	for parity_pass in range(2):
		var step: int = parity_pass
		while step < rows:
			var forward: int = center + step
			var backward: int = center - step
			if forward < rows and not order.has(forward):
				order.append(forward)
			if step != 0 and backward >= 0 and not order.has(backward):
				order.append(backward)
			step += 2

	for i in range(remainder):
		sizes[order[i]] += 1
	return sizes

static func build_staggered(units: Array, game_ref: Node, icon_size: int = 18, row_width_cap: int = 16) -> Control:
	"""Render an army as centered, overlapping ranks (thin front/back, fuller middle) instead
	of a uniform grid — plain sprites only, no colored squares."""
	var formation = VBoxContainer.new()
	formation.add_theme_constant_override("separation", -int(icon_size * 0.35))
	if units.is_empty():
		return formation
	var row_sizes: Array = _distribute_row_sizes(units.size(), row_width_cap)
	var idx: int = 0
	for row_size in row_sizes:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", -int(icon_size * 0.25))
		for i in range(row_size):
			row.add_child(build_plain_icon(units[idx], game_ref, icon_size))
			idx += 1
		var center = CenterContainer.new()
		center.add_child(row)
		formation.add_child(center)
	return formation

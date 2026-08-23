# scripts/ui/encyclopedia_modal.gd
# In-game encyclopedia covering game mechanics, buildings, jobs, and world objects.
extends "res://scripts/ui/info_modal.gd"

func _init():
	super("encyclopedia", "? Encyclopedia", Vector2.ZERO)

func _ready() -> void:
	super._ready()
	if get_viewport():
		var vp = get_viewport().get_visible_rect().size
		custom_minimum_size = Vector2(620, 520)
		size = custom_minimum_size
		position = Vector2((vp.x - size.x) / 2.0, (vp.y - size.y) / 2.0)

func refresh_content():
	clear_content()

	# Tab bar
	var tab_bar = TabBar.new()
	tab_bar.add_tab("Basics")
	tab_bar.add_tab("Jobs")
	tab_bar.add_tab("Buildings")
	tab_bar.add_tab("World Objects")
	tab_bar.add_tab("Events")
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_content_child(tab_bar)

	add_content_child(HSeparator.new())

	# Content pages — one ScrollContainer per tab, only one visible at a time
	var pages: Array = []
	for _i in 5:
		var scroll = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 360)
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)
		add_content_child(scroll)
		pages.append({"scroll": scroll, "vbox": vbox})

	_populate_basics(pages[0]["vbox"])
	_populate_jobs(pages[1]["vbox"])
	_populate_buildings(pages[2]["vbox"])
	_populate_world_objects(pages[3]["vbox"])
	_populate_events(pages[4]["vbox"])

	# Show only the active tab's page
	var _show_page = func(idx: int):
		for i in pages.size():
			pages[i]["scroll"].visible = (i == idx)

	_show_page.call(0)
	tab_bar.tab_changed.connect(_show_page)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _section(vbox: VBoxContainer, title: String):
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())

func _entry(vbox: VBoxContainer, icon: String, name: String, desc: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var ico = Label.new()
	ico.text = icon
	ico.add_theme_font_size_override("font_size", 22)
	ico.custom_minimum_size = Vector2(32, 32)
	ico.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(ico)

	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var title_lbl = Label.new()
	title_lbl.text = name
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	col.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(desc_lbl)

	vbox.add_child(HSeparator.new())

# ── Tab content ──────────────────────────────────────────────────────────────

func _populate_basics(v: VBoxContainer):
	_section(v, "Welcome")
	_entry(v, "🏰", "Goal",
		"Build and grow your settlement. Gather resources, house your population, and defend against enemy waves. Your game ends if your last Town Centre is destroyed.")

	_section(v, "Resources")
	_entry(v, "💰", "Gold",
		"The primary currency. Used to construct buildings and pay for events. Earned passively and through trade events.")
	_entry(v, "🌾", "Food",
		"Feeds your population each turn. If food runs out, growth stalls and events may kill villagers. Produced by Farmhouses and Fishing Huts.")
	_entry(v, "🪵", "Wood",
		"Core building material. Required for most constructions. Produced by Lumberjack camps and Lumber Mills.")
	_entry(v, "🪨", "Stone",
		"Heavy-duty material for advanced buildings. Produced by Stoneworker camps near mountains.")
	_entry(v, "🔬", "Science",
		"Powers the tech tree. Produced by Research buildings and scholars. Unlocks new buildings and upgrades.")

	_section(v, "Turns & Days")
	_entry(v, "📅", "End Day",
		"Each turn represents one day. Press End Day to advance. Resources are produced, units move, and world events may fire. You must resolve any pending event before ending the day.")

	_section(v, "Population")
	_entry(v, "👥", "Population Cap",
		"The maximum number of villagers your settlement can support. Raised by building houses and farmhouses. Your Town Centre provides 12 starting slots.")
	_entry(v, "🏠", "Housing",
		"Units without living quarters wander aimlessly near the Town Centre and cannot be assigned jobs. Build Houses (7 slots) or Farmhouses (2 slots) to expand capacity.")


func _populate_jobs(v: VBoxContainer):
	_section(v, "Assigning Units")
	_entry(v, "🧑", "Peasants",
		"All newly spawned citizens start as unassigned peasants. Open the Units panel to assign them a living quarter and a job. Once assigned both, they will begin their work cycle.")

	_section(v, "Resource Jobs")
	_entry(v, "🌲", "Lumberjack",
		"Assigned to a Lumberjack camp. Walks between the camp and a nearby forest, producing wood each cycle.")
	_entry(v, "⛏", "Stoneworker",
		"Assigned to a Stoneworker camp near mountains. Produces stone every work cycle.")
	_entry(v, "🐟", "Fisher",
		"Assigned to a Fishing Hut near water tiles. Produces food every work cycle.")
	_entry(v, "🌾", "Farmer",
		"Assigned to a Farmhouse. Produces food and also provides 2 living slots in the same building.")

	_section(v, "Specialist Jobs")
	_entry(v, "🔬", "Researcher",
		"Assigned to a Research building. Produces science each turn. Researchers can be further trained for bonus output.")
	_entry(v, "⚔", "Soldier",
		"Assigned to a Barracks station. Trained soldiers defend the settlement and can be ordered to attack enemy camps.")

	_section(v, "Training")
	_entry(v, "📜", "Specialties",
		"Units can gain specialties through training at a Barracks. Each specialty improves a stat. Training takes several days but the bonus is permanent.")


func _populate_buildings(v: VBoxContainer):
	_section(v, "Core")
	_entry(v, "🏰", "Town Centre",
		"Your starting building and seat of power. Provides 12 housing slots and 2 science worker slots. If your last Town Centre is destroyed the game is over.")
	_entry(v, "🏠", "House",
		"Provides 7 living slots. No resource production — purely residential. Essential once your Town Centre fills up.")

	_section(v, "Food")
	_entry(v, "🌾", "Farmhouse",
		"Provides 2 living slots AND 6 worker slots. Workers produce food every cycle. A combined home and workplace.")
	_entry(v, "🐟", "Fishing Hut",
		"Must be placed near water. Employs up to 5 fishers who produce food each cycle.")

	_section(v, "Industry")
	_entry(v, "🪵", "Lumberjack Camp",
		"Employs up to 10 workers. Must be placed near trees. Workers walk to the forest and return with wood.")
	_entry(v, "🏭", "Lumber Mill",
		"Employs up to 10 workers. Processes raw timber into refined wood more efficiently than the basic camp.")
	_entry(v, "⛏", "Stoneworker Camp",
		"Employs up to 10 workers. Must be placed near mountains. Workers mine stone each cycle.")

	_section(v, "Knowledge")
	_entry(v, "🔬", "Research Lab",
		"Employs up to 8 researchers. Produces science each turn. Unlocking the tech tree requires sustained research output.")

	_section(v, "Military")
	_entry(v, "⚔", "Barracks",
		"Trains soldiers and stations a garrison. Station slots hold soldiers on patrol; training slots are for units actively training a specialty.")


func _populate_world_objects(v: VBoxContainer):
	_section(v, "Natural Resources")
	_entry(v, "🌲", "Forest / Trees",
		"Found scattered across the map. Required by Lumberjack camps and Lumber Mills. Workers travel to the forest tile and return with wood. Forests do not deplete.")
	_entry(v, "⛰", "Mountains",
		"Rocky terrain found in clusters. Required by Stoneworker camps. Workers mine the mountain face for stone. Mountains do not deplete.")
	_entry(v, "🌊", "Water / Coast",
		"River tiles and coastal edges. Required by Fishing Huts. Cannot be built upon. Fish tiles do not deplete.")

	_section(v, "Terrain")
	_entry(v, "🟩", "Grassland",
		"Flat buildable land. Most buildings can only be placed on grassland tiles.")
	_entry(v, "🟫", "Sand / Beach",
		"Coastal transition tiles. Generally unbuildable but mark the edge of water.")
	_entry(v, "⬜", "Snow",
		"Found at high elevations or polar regions. Buildable but may affect aesthetics in future updates.")

	_section(v, "Enemy Camps")
	_entry(v, "⚔", "Enemy Barracks",
		"Spawned by wave events after a season (28 days). An enemy faction has made camp as far from your Town Centre as possible. Destroy it before the wave attacks.")


func _tier_color(tier: String) -> Color:
	match tier:
		"S+": return Color(0.85, 0.20, 0.85)
		"S":  return Color(0.90, 0.20, 0.20)
		"A":  return Color(0.90, 0.55, 0.10)
		"B":  return Color(0.85, 0.80, 0.10)
		"C":  return Color(0.30, 0.70, 0.95)
		"D":  return Color(0.40, 0.80, 0.40)
		_:    return Color(0.55, 0.55, 0.55)

func _category_color(cat: String) -> Color:
	match cat:
		"divine_light": return Color(1.00, 0.95, 0.40)
		"divine_dark":  return Color(0.70, 0.30, 0.90)
		"migration":    return Color(0.40, 0.80, 0.75)
		"military":     return Color(0.95, 0.35, 0.35)
		"natural":      return Color(0.40, 0.85, 0.40)
		"economy":      return Color(0.85, 0.75, 0.30)
		_:              return Color(0.60, 0.60, 0.60)  # mundane


func _populate_events(v: VBoxContainer):
	var HumanEvents = preload("res://data/events/events_human.gd")

	# Group events by tier in display order
	var tier_order: Array = ["S+", "S", "A", "B", "C", "D", "F"]
	var grouped: Dictionary = {}
	for t in tier_order:
		grouped[t] = []
	for ev in HumanEvents.EVENTS:
		var t: String = ev.get("tier", "C")
		if grouped.has(t):
			grouped[t].append(ev)

	for tier in tier_order:
		var evs: Array = grouped[tier]
		if evs.is_empty():
			continue

		# Tier header
		var tier_lbl = Label.new()
		tier_lbl.text = HumanEvents.get_tier_label(tier)
		tier_lbl.add_theme_font_size_override("font_size", 14)
		tier_lbl.add_theme_color_override("font_color", _tier_color(tier))
		v.add_child(tier_lbl)
		v.add_child(HSeparator.new())

		for ev in evs:
			var card = PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
			style.border_color = _tier_color(tier)
			style.border_width_left = 3
			style.corner_radius_top_left = 3
			style.corner_radius_bottom_left = 3
			card.add_theme_stylebox_override("panel", style)
			v.add_child(card)

			var col = VBoxContainer.new()
			col.add_theme_constant_override("separation", 4)
			card.add_child(col)

			# Header row: icon + title
			var hrow = HBoxContainer.new()
			hrow.add_theme_constant_override("separation", 8)
			col.add_child(hrow)

			var ico = Label.new()
			ico.text = ev.get("icon", "📜")
			ico.add_theme_font_size_override("font_size", 20)
			ico.custom_minimum_size = Vector2(28, 0)
			ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hrow.add_child(ico)

			var title_lbl = Label.new()
			title_lbl.text = ev.get("title", "")
			title_lbl.add_theme_font_size_override("font_size", 13)
			title_lbl.add_theme_color_override("font_color", Color.WHITE)
			title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hrow.add_child(title_lbl)

			var cat_lbl = Label.new()
			cat_lbl.text = ev.get("category", "").replace("_", " ").capitalize()
			cat_lbl.add_theme_font_size_override("font_size", 9)
			cat_lbl.add_theme_color_override("font_color", _category_color(ev.get("category", "")))
			cat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hrow.add_child(cat_lbl)

			# Body text
			var body_lbl = Label.new()
			body_lbl.text = ev.get("body", "")
			body_lbl.add_theme_font_size_override("font_size", 11)
			body_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
			body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(body_lbl)

			# Effects summary
			var base_fx: Dictionary = ev.get("effects", {})
			var parts: Array = []
			for key in ["gold", "food", "wood", "stone", "science"]:
				var val: int = base_fx.get("resources", {}).get(key, 0)
				if val != 0:
					parts.append("%s%d %s" % ["+" if val > 0 else "", val, key.capitalize()])
			var pop_max: int = base_fx.get("pop_max", 0)
			if pop_max != 0:
				parts.append("%s%d Pop Cap" % ["+" if pop_max > 0 else "", pop_max])
			var pop_kill: int = base_fx.get("pop_kill", 0)
			if pop_kill != 0:
				parts.append("-%d Villagers" % pop_kill)
			var pop_kill_pct: float = base_fx.get("pop_kill_pct", 0.0)
			if pop_kill_pct > 0.0:
				parts.append("-%.0f%% Pop" % pop_kill_pct)
			var pop_gain: int = base_fx.get("pop_gain", 0)
			if pop_gain != 0:
				parts.append("+%d Villagers" % pop_gain)
			var pop_gain_pct: float = base_fx.get("pop_gain_pct", 0.0)
			if pop_gain_pct > 0.0:
				parts.append("+%.0f%% Pop" % pop_gain_pct)
			if not parts.is_empty():
				var fx_lbl = Label.new()
				fx_lbl.text = "Base effects: " + ", ".join(parts)
				fx_lbl.add_theme_font_size_override("font_size", 10)
				fx_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
				col.add_child(fx_lbl)

			# Choices
			var choices: Array = ev.get("choices", [])
			for ch in choices:
				var ch_parts: Array = []
				var ch_fx = ch.get("effects")
				if ch_fx != null and ch_fx is Dictionary:
					for key in ["gold", "food", "wood", "stone", "science"]:
						var val: int = ch_fx.get("resources", {}).get(key, 0)
						if val != 0:
							ch_parts.append("%s%d %s" % ["+" if val > 0 else "", val, key.capitalize()])
					var cpm: int = ch_fx.get("pop_max", 0)
					if cpm != 0:
						ch_parts.append("%s%d Pop Cap" % ["+" if cpm > 0 else "", cpm])
				var ch_lbl = Label.new()
				var fx_text = (" → " + ", ".join(ch_parts)) if not ch_parts.is_empty() else " (base effects)"
				ch_lbl.text = "  • " + ch.get("label", "?") + fx_text
				ch_lbl.add_theme_font_size_override("font_size", 10)
				ch_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95))
				ch_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				col.add_child(ch_lbl)

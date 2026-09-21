# scripts/main/world_creation_race_select_modal.gd
extends Control

# References
var game_node: Node
var world_creation_modal: Node

# Race data
var races = {
	"human": {
		"name": "Human",
		"description": "Versatile and adaptable, humans are skilled traders and diplomats. They build balanced settlements with strong economies and diverse capabilities.",
		"buildings": ["town_center", "house", "barracks", "farmhouse", "farm", "fishing_hut", "lumberjack", "stoneworker", "research", "merchant", "wonder"]
	},
	"elf": {
		"name": "Elf",
		"description": "Masters of nature and magic, elves live in harmony with the forest. Their settlements blend seamlessly with the natural world.",
		"buildings": ["tree_hall", "enchanted_grove", "ranger_post", "moon_well", "mystic_tower"]
	},
	"dwarf": {
		"name": "Dwarf", 
		"description": "Expert miners and craftsmen, dwarves create mighty mountain fortresses. They excel at metalwork and underground construction.",
		"buildings": ["clan_hall", "mine", "forge", "brewery", "stone_keep"]
	},
	"goblin": {
		"name": "Goblin",
		"description": "Cunning and resourceful, goblins thrive in chaotic environments. They build ramshackle but efficient settlements focused on raids and scavenging.",
		"buildings": ["goblin_chief_hut", "scrap_yard", "wolf_pen", "trap_workshop", "watchtower"]
	},
	"undead": {
		"name": "Undead",
		"description": "The restless dead, commanded by dark necromancy. Their settlements are places of eternal darkness and forbidden knowledge.",
		"buildings": ["necropolis", "bone_yard", "dark_altar", "crypt", "soul_forge"]
	},
	"demon": {
		"name": "Demon",
		"description": "Beings of fire and shadow from the infernal realms. Their settlements burn with hellfire and serve as gateways to darker dimensions.",
		"buildings": ["infernal_citadel", "lava_forge", "demon_gate", "sacrifice_pit", "hellfire_tower"]
	}
}

# Authoritative building type -> sprite path lookup (matches build_selection_modal.gd's data)
# so the race-select grid and the detail panel both show the real building art.
const BUILDING_SPRITE_PATHS: Dictionary = {
	"house": "res://assets/buildings/human_house.png",
	"barracks": "res://assets/buildings/human_barracks.png",
	"fishing_hut": "res://assets/buildings/human_finshinghut.png",
	"lumberjack": "res://assets/buildings/human_lumberjack.png",
	"stoneworker": "res://assets/buildings/human_stoneworker.png",
	"research": "res://assets/buildings/human_research.png",
	"merchant": "res://assets/buildings/human_merchant1.png",
	"town_center": "res://assets/buildings/human_towncentre-export.png",
	"farmhouse": "res://assets/buildings/human_farmhouse.png",
	"farm": "res://assets/buildings/human_farm_tilled.png",
	"wonder": "res://assets/buildings/human_wonder.png",
}

# Human citizen look options for the sample-unit picker (occupations use their working sprite).
const HUMAN_UNIT_SPRITES: Array = [
	{"key": "male_peasant", "label": "Peasant (M)", "path": "res://assets/units/human_male_peasant_side.png"},
	{"key": "female_peasant", "label": "Peasant (F)", "path": "res://assets/units/human_female_peasant_side.png"},
	{"key": "male_peasant_2", "label": "Peasant (M) II", "path": "res://assets/units/human_peasant_male_2.png"},
	{"key": "female_peasant_2", "label": "Peasant (F) II", "path": "res://assets/units/human_peasant_female_2.png"},
	{"key": "farmer", "label": "Farmer", "path": "res://assets/units/human_farmer.png"},
	{"key": "merchant", "label": "Merchant", "path": "res://assets/units/human_merchant.png"},
	{"key": "scholar", "label": "Scholar", "path": "res://assets/units/human_scholar.png"},
	{"key": "soldier", "label": "Soldier", "path": "res://assets/units/human_soldier.png"},
]

# UI Components
var selected_race: String = "human"
var selected_building: String = "town_center"  # Auto-select town center
var race_buttons: Array[Button] = []
var race_info_container: VBoxContainer
var building_selected_container: VBoxContainer
var buildings_grid: GridContainer
var pet_name_field: LineEdit
var pet_type_button: Button
var pet_selection_popup: Control
var selected_pet_type: String = "cat"
var human_preview_image: TextureRect
var selected_unit_sprite: String = "male_peasant"
var unit_sprites_grid: GridContainer

func setup_integrated(game_ref: Node, world_creation_ref: Node, ui_layer: CanvasLayer):
	game_node = game_ref
	world_creation_modal = world_creation_ref
	
	# Set up as integrated UI (positioned between header and footer)
	name = "RaceSelectUI"
	
	# Add to UI layer first so we have a proper viewport reference
	ui_layer.add_child(self)
	
	# Now we can safely get screen size
	var screen_size = get_viewport().get_visible_rect().size
	position = Vector2(50, 160)  # Below header with some margin
	size = Vector2(screen_size.x - 100, screen_size.y - 260)  # Leave space for header/footer
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_create_integrated_ui()
	_update_race_info()
	_update_buildings_grid()

func _create_integrated_ui():
	# Create background container matching header/footer style exactly
	var bg_container = Control.new()
	# Position to align with header: header is at (200,20) with size (800,120), ends at y=140
	# RaceSelectUI is at (50,160), so relative position is (200-50, 140-160) = (150, -20)
	bg_container.position = Vector2(150, -20)
	# Height: from bottom of header (140) to top of footer (screen_size.y - 80) = screen_size.y - 220
	bg_container.size = Vector2(800, get_viewport().get_visible_rect().size.y - 220)
	bg_container.clip_contents = true
	add_child(bg_container)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.25)  # 25% opacity black like header/footer
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_container.add_child(bg)
	
	# Content container with minimal padding
	var content_holder = Control.new()
	content_holder.position = Vector2(5, 5)
	content_holder.size = Vector2(790, bg_container.size.y - 10)
	bg_container.add_child(content_holder)
	
	# Main vertical layout
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	content_holder.add_child(main_container)
	
	_create_race_ui_content(main_container)

func _create_race_ui_content(parent_container: VBoxContainer):
	# Race buttons at the top
	var race_buttons_container = HBoxContainer.new()
	race_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	race_buttons_container.add_theme_constant_override("separation", 10)
	parent_container.add_child(race_buttons_container)
	
	for race_key in races.keys():
		var button = Button.new()
		button.text = races[race_key]["name"]
		button.custom_minimum_size = Vector2(100, 35)
		button.pressed.connect(_on_race_selected.bind(race_key))
		race_buttons_container.add_child(button)
		race_buttons.append(button)
	
	# Middle section with race info and building selection
	var middle_container = HBoxContainer.new()
	middle_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_container.add_theme_constant_override("separation", 20)
	parent_container.add_child(middle_container)
	
	# Left side - Race info
	race_info_container = VBoxContainer.new()
	race_info_container.custom_minimum_size = Vector2(400, 0)
	race_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_container.add_child(race_info_container)
	
	# Right side - Building selection
	var building_section = VBoxContainer.new()
	building_section.custom_minimum_size = Vector2(420, 0)
	building_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_container.add_child(building_section)
	
	# Building selected container — bigger image + description now that it's the focal point
	building_selected_container = VBoxContainer.new()
	building_selected_container.custom_minimum_size = Vector2(0, 260)
	building_section.add_child(building_selected_container)
	
	# Buildings grid — sprite buttons, one per building this race can build
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(0, 180)
	building_section.add_child(grid_scroll)
	
	buildings_grid = GridContainer.new()
	buildings_grid.columns = 3
	buildings_grid.add_theme_constant_override("h_separation", 10)
	buildings_grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(buildings_grid)
	
	# ── Pet section ──────────────────────────────────────────────────────────
	var pet_sep = HSeparator.new()
	pet_sep.add_theme_constant_override("separation", 8)
	parent_container.add_child(pet_sep)
	
	var pet_row = HBoxContainer.new()
	pet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pet_row.add_theme_constant_override("separation", 12)
	parent_container.add_child(pet_row)
	
	var pet_icon = Label.new()
	pet_icon.text = "🐾"
	pet_icon.add_theme_font_size_override("font_size", 22)
	pet_row.add_child(pet_icon)
	
	var pet_label = Label.new()
	pet_label.text = "Your companion's name:"
	pet_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	pet_label.add_theme_font_size_override("font_size", 14)
	pet_row.add_child(pet_label)
	
	pet_name_field = LineEdit.new()
	pet_name_field.text = "Wilson"
	pet_name_field.placeholder_text = "Wilson"
	pet_name_field.custom_minimum_size = Vector2(140, 32)
	pet_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_name_field.add_theme_font_size_override("font_size", 14)
	pet_row.add_child(pet_name_field)
	
	pet_type_button = Button.new()
	pet_type_button.custom_minimum_size = Vector2(90, 32)
	pet_type_button.text = _pet_type_label(selected_pet_type)
	pet_type_button.expand_icon = true
	var pet_tex_path = _pet_sprite_path(selected_pet_type)
	if ResourceLoader.exists(pet_tex_path):
		pet_type_button.icon = load(pet_tex_path)
	pet_type_button.pressed.connect(_open_pet_selection_popup)
	pet_row.add_child(pet_type_button)
	
	var pet_hint = Label.new()
	pet_hint.text = "(will join your settlement)"
	pet_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pet_hint.add_theme_font_size_override("font_size", 11)
	pet_row.add_child(pet_hint)

func _update_race_info():
	# Clear existing info
	for child in race_info_container.get_children():
		child.queue_free()
	human_preview_image = null
	
	# Update race button states
	for i in range(race_buttons.size()):
		var button = race_buttons[i]
		var race_key = races.keys()[i]
		if race_key == selected_race:
			button.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
		else:
			button.modulate = Color.WHITE
	
	var race_data = races[selected_race]
	
	# Sample-unit preview — smaller than before, since the unit picker list sits underneath it
	if selected_race == "human":
		var sprite_path = _get_selected_unit_sprite_path()
		var peasant_texture = load(sprite_path) if ResourceLoader.exists(sprite_path) else null
		if peasant_texture:
			human_preview_image = TextureRect.new()
			human_preview_image.texture = peasant_texture
			human_preview_image.custom_minimum_size = Vector2(140, 100)
			human_preview_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			human_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			human_preview_image.texture_filter = TEXTURE_FILTER_NEAREST  # Keep pixels sharp
			human_preview_image.modulate = Color(1.5, 1.5, 1.5)  # Brighten the sprite
			race_info_container.add_child(human_preview_image)
		else:
			_add_race_image_placeholder(race_data["name"])
	else:
		_add_race_image_placeholder(race_data["name"])
	
	# Race name
	var name_label = Label.new()
	name_label.text = race_data["name"]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_info_container.add_child(name_label)
	
	# Race description
	var desc_label = Label.new()
	desc_label.text = race_data["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color.WHITE)  # White text for readability
	race_info_container.add_child(desc_label)
	
	# Unit look picker — only human has sprite variants to choose between right now.
	if selected_race == "human":
		race_info_container.add_child(HSeparator.new())
		
		var picker_label = Label.new()
		picker_label.text = "Choose Your People's Look:"
		picker_label.add_theme_font_size_override("font_size", 14)
		picker_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		picker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		race_info_container.add_child(picker_label)
		
		var unit_scroll = ScrollContainer.new()
		unit_scroll.custom_minimum_size = Vector2(0, 160)
		unit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		race_info_container.add_child(unit_scroll)
		
		unit_sprites_grid = GridContainer.new()
		unit_sprites_grid.columns = 4
		unit_sprites_grid.add_theme_constant_override("h_separation", 8)
		unit_sprites_grid.add_theme_constant_override("v_separation", 8)
		unit_scroll.add_child(unit_sprites_grid)
		
		_update_unit_sprites_grid()

func _add_race_image_placeholder(race_name: String):
	var image_bg = ColorRect.new()
	image_bg.color = Color(0.3, 0.3, 0.3)
	image_bg.custom_minimum_size = Vector2(140, 100)
	race_info_container.add_child(image_bg)
	
	var image_label = Label.new()
	image_label.text = race_name + " Image"
	image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_bg.add_child(image_label)

func _get_selected_unit_sprite_path() -> String:
	for entry in HUMAN_UNIT_SPRITES:
		if entry["key"] == selected_unit_sprite:
			return entry["path"]
	return HUMAN_UNIT_SPRITES[0]["path"]

func _update_unit_sprites_grid():
	for child in unit_sprites_grid.get_children():
		child.queue_free()
	for entry in HUMAN_UNIT_SPRITES:
		var option = _build_sprite_choice_button(entry["path"], entry["label"], Vector2(56, 56),
			_on_unit_sprite_selected.bind(entry["key"]), "sprite_key", entry["key"])
		_highlight_sprite_choice(option, entry["key"] == selected_unit_sprite)
		unit_sprites_grid.add_child(option)

func _on_unit_sprite_selected(key: String):
	selected_unit_sprite = key
	if is_instance_valid(human_preview_image):
		var sprite_path = _get_selected_unit_sprite_path()
		if ResourceLoader.exists(sprite_path):
			human_preview_image.texture = load(sprite_path)
	for child in unit_sprites_grid.get_children():
		_highlight_sprite_choice(child, child.get_meta("sprite_key", "") == key)

func _build_sprite_choice_button(texture_path: String, label_text: String, icon_size: Vector2,
		callback: Callable, meta_key: String, meta_value: String) -> Control:
	"""Reusable icon+label picker button — used for both the building grid and the unit look
	picker, so both selection lists behave and look the same way."""
	var option = VBoxContainer.new()
	option.alignment = BoxContainer.ALIGNMENT_CENTER
	option.set_meta(meta_key, meta_value)
	
	var button = TextureButton.new()
	button.custom_minimum_size = icon_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(texture_path):
		button.texture_normal = load(texture_path)
	button.pressed.connect(callback)
	option.add_child(button)
	option.set_meta("icon_button", button)
	
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	option.add_child(label)
	
	return option

func _highlight_sprite_choice(option: Control, selected: bool):
	var button = option.get_meta("icon_button", null)
	if is_instance_valid(button):
		button.modulate = Color(1.2, 1.2, 0.8) if selected else Color.WHITE

func _update_buildings_grid():
	# Clear existing buildings
	for child in buildings_grid.get_children():
		child.queue_free()
	
	var race_data = races[selected_race]
	for building in race_data["buildings"]:
		var texture_path: String = BUILDING_SPRITE_PATHS.get(building, "res://assets/buildings/human_" + building.replace("_", "") + ".png")
		var label_text: String = building.replace("_", " ").capitalize()
		var option = _build_sprite_choice_button(texture_path, label_text, Vector2(84, 84),
			_on_building_selected.bind(building), "building_key", building)
		_highlight_sprite_choice(option, building == selected_building)
		buildings_grid.add_child(option)
	
	_update_selected_building_info()

func _update_selected_building_info():
	# Clear existing info
	for child in building_selected_container.get_children():
		child.queue_free()
	
	if selected_building.is_empty():
		var placeholder = Label.new()
		placeholder.text = "Select a building to see details"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		building_selected_container.add_child(placeholder)
		return
	
	var image_path: String = BUILDING_SPRITE_PATHS.get(selected_building, "res://assets/buildings/human_" + selected_building.replace("_", "") + ".png")
	DebugConfig.dprint("world_gen", ["Trying to load building image: ", image_path])
	var building_texture = load(image_path) if ResourceLoader.exists(image_path) else null
	
	if building_texture:
		# Create texture rect for the actual image — bigger now that this panel is the focal point
		var image_rect = TextureRect.new()
		image_rect.texture = building_texture
		image_rect.custom_minimum_size = Vector2(260, 180)
		image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.texture_filter = TEXTURE_FILTER_NEAREST  # Keep pixels sharp
		building_selected_container.add_child(image_rect)
	else:
		# Fallback to colored background with text
		var image_bg = ColorRect.new()
		image_bg.color = Color(0.2, 0.4, 0.2)
		image_bg.custom_minimum_size = Vector2(260, 180)
		building_selected_container.add_child(image_bg)
		
		var fallback_label = Label.new()
		fallback_label.text = "human-" + selected_building + "-img"
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_bg.add_child(fallback_label)
	
	# Building title
	var title_label = Label.new()
	title_label.text = selected_building.replace("_", " ").capitalize()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	building_selected_container.add_child(title_label)
	
	# Building description
	var desc_label = Label.new()
	desc_label.text = "A essential building for " + races[selected_race]["name"] + " settlements."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	building_selected_container.add_child(desc_label)

func _on_race_selected(race_key: String):
	selected_race = race_key
	selected_building = "town_center"  # Auto-select town center for any race
	_update_race_info()
	_update_buildings_grid()

func _on_building_selected(building: String):
	selected_building = building
	for child in buildings_grid.get_children():
		_highlight_sprite_choice(child, child.get_meta("building_key", "") == building)
	_update_selected_building_info()

func _finish_race_selection():
	# This method is now called indirectly through world_creation_modal
	# Just finish the race selection modal, don't advance steps
	_finish_race_selection_internal()

func _finish_race_selection_internal():
	# Store race and building selection in world data
	var pet_name = "Wilson"
	if is_instance_valid(pet_name_field) and pet_name_field.text.strip_edges() != "":
		pet_name = pet_name_field.text.strip_edges()
	
	if world_creation_modal.world_data.has("player_data"):
		world_creation_modal.world_data["player_data"].merge({
			"race": selected_race,
			"starting_building": selected_building,
			"pet_name": pet_name,
			"pet_type": selected_pet_type
		})
	else:
		world_creation_modal.world_data["player_data"] = {
			"race": selected_race,
			"starting_building": selected_building,
			"pet_name": pet_name,
			"pet_type": selected_pet_type
		}
	
	# Clean up and let the normal step progression handle the next steps
	queue_free()

func _pet_sprite_path(pet_type: String) -> String:
	return "res://assets/units/dog_1.png" if pet_type == "dog" else "res://assets/units/wilson.png"

func _pet_type_label(pet_type: String) -> String:
	return "Dog" if pet_type == "dog" else "Cat"

func _open_pet_selection_popup():
	if is_instance_valid(pet_selection_popup):
		pet_selection_popup.queue_free()
	
	var screen_size = get_viewport().get_visible_rect().size
	
	pet_selection_popup = Control.new()
	pet_selection_popup.name = "PetSelectionPopup"
	pet_selection_popup.position = Vector2.ZERO
	pet_selection_popup.size = screen_size
	pet_selection_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(pet_selection_popup)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.position = Vector2.ZERO
	overlay.size = screen_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pet_selection_popup.add_child(overlay)
	
	var panel_size = Vector2(320, 230)
	var panel = PanelContainer.new()
	panel.position = (screen_size - panel_size) / 2
	panel.size = panel_size
	pet_selection_popup.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Choose your companion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var options_row = HBoxContainer.new()
	options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	options_row.add_theme_constant_override("separation", 24)
	vbox.add_child(options_row)
	
	options_row.add_child(_build_pet_option("cat"))
	options_row.add_child(_build_pet_option("dog"))
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func(): pet_selection_popup.queue_free())
	vbox.add_child(cancel_button)

func _build_pet_option(pet_type: String) -> VBoxContainer:
	var option = VBoxContainer.new()
	option.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var button = TextureButton.new()
	button.custom_minimum_size = Vector2(96, 96)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = _pet_sprite_path(pet_type)
	if ResourceLoader.exists(tex_path):
		button.texture_normal = load(tex_path)
	button.pressed.connect(_on_pet_type_chosen.bind(pet_type))
	option.add_child(button)
	
	var label = Label.new()
	label.text = _pet_type_label(pet_type)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.add_child(label)
	
	return option

func _on_pet_type_chosen(pet_type: String):
	selected_pet_type = pet_type
	if is_instance_valid(pet_type_button):
		pet_type_button.text = _pet_type_label(pet_type)
		var tex_path = _pet_sprite_path(pet_type)
		if ResourceLoader.exists(tex_path):
			pet_type_button.icon = load(tex_path)
	if is_instance_valid(pet_selection_popup):
		pet_selection_popup.queue_free()

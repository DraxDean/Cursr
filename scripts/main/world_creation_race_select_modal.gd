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
		"buildings": ["town_center", "barracks", "house", "farmhouse", "fishing_hut", "lumberjack", "research", "stoneworker"]
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

# UI Components
var selected_race: String = "human"
var selected_building: String = "town_center"  # Auto-select town center
var race_buttons: Array[Button] = []
var race_info_container: VBoxContainer
var building_selected_container: VBoxContainer
var buildings_grid: GridContainer

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
	building_section.custom_minimum_size = Vector2(400, 0)
	building_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_container.add_child(building_section)
	
	# Building selected container
	building_selected_container = VBoxContainer.new()
	building_selected_container.custom_minimum_size = Vector2(0, 150)
	building_section.add_child(building_selected_container)
	
	# Buildings grid
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(0, 200)
	building_section.add_child(grid_scroll)
	
	buildings_grid = GridContainer.new()
	buildings_grid.columns = 2
	buildings_grid.add_theme_constant_override("h_separation", 10)
	buildings_grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(buildings_grid)

func _update_race_info():
	# Clear existing info
	for child in race_info_container.get_children():
		child.queue_free()
	
	# Update race button states
	for i in range(race_buttons.size()):
		var button = race_buttons[i]
		var race_key = races.keys()[i]
		if race_key == selected_race:
			button.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
		else:
			button.modulate = Color.WHITE
	
	var race_data = races[selected_race]
	
	# Race image placeholder
	if selected_race == "human":
		# Load human peasant sprite for human race
		var peasant_texture = load("res://assets/units/human_peasant_side.png")
		if peasant_texture:
			var image_rect = TextureRect.new()
			image_rect.texture = peasant_texture
			image_rect.custom_minimum_size = Vector2(300, 200)
			image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image_rect.texture_filter = TEXTURE_FILTER_NEAREST  # Keep pixels sharp
			image_rect.modulate = Color(1.5, 1.5, 1.5)  # Brighten the sprite
			race_info_container.add_child(image_rect)
		else:
			var image_bg = ColorRect.new()
			image_bg.color = Color(0.3, 0.3, 0.3)
			image_bg.custom_minimum_size = Vector2(300, 200)
			race_info_container.add_child(image_bg)
			
			var image_label = Label.new()
			image_label.text = race_data["name"] + " Image"
			image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			image_bg.add_child(image_label)
	else:
		var image_bg = ColorRect.new()
		image_bg.color = Color(0.3, 0.3, 0.3)
		image_bg.custom_minimum_size = Vector2(300, 200)
		race_info_container.add_child(image_bg)
		
		var image_label = Label.new()
		image_label.text = race_data["name"] + " Image"
		image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_bg.add_child(image_label)
	
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

func _update_buildings_grid():
	# Clear existing buildings
	for child in buildings_grid.get_children():
		child.queue_free()
	
	var race_data = races[selected_race]
	for building in race_data["buildings"]:
		var button = Button.new()
		button.text = building.replace("_", " ").capitalize()
		button.custom_minimum_size = Vector2(180, 60)
		button.pressed.connect(_on_building_selected.bind(building))
		
		# Highlight town center as selected by default
		if building == "town_center":
			button.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
		
		buildings_grid.add_child(button)
	
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
	
	# Try to load the actual building image
	var image_path = ""
	# Handle special cases for file naming (building name to actual filename mapping)
	if selected_building == "town_center":
		image_path = "res://assets/buildings/human_towncentre-export.png"
	elif selected_building == "fishing_hut":
		image_path = "res://assets/buildings/human_finshinghut.png"
	elif selected_building == "research":
		image_path = "res://assets/buildings/human_research.png"
	elif selected_building == "lumberjack":
		image_path = "res://assets/buildings/human_lumberjack.png"
	elif selected_building == "stoneworker":
		image_path = "res://assets/buildings/human_stoneworker.png"
	else:
		# Generic mapping: human_[building_name].png
		image_path = "res://assets/buildings/human_" + selected_building.replace("_", "") + ".png"
	
	print("Trying to load building image: ", image_path)
	
	# Try to load the texture
	var building_texture = null
	if ResourceLoader.exists(image_path):
		building_texture = load(image_path)
	
	if building_texture:
		# Create texture rect for the actual image
		var image_rect = TextureRect.new()
		image_rect.texture = building_texture
		image_rect.custom_minimum_size = Vector2(200, 100)
		image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.texture_filter = TEXTURE_FILTER_NEAREST  # Keep pixels sharp
		building_selected_container.add_child(image_rect)
	else:
		# Fallback to colored background with text
		var image_bg = ColorRect.new()
		image_bg.color = Color(0.2, 0.4, 0.2)
		image_bg.custom_minimum_size = Vector2(200, 100)
		building_selected_container.add_child(image_bg)
		
		var fallback_label = Label.new()
		fallback_label.text = "human-" + selected_building + "-img"
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_bg.add_child(fallback_label)
	
	# Building title
	var title_label = Label.new()
	title_label.text = selected_building.replace("_", " ").capitalize()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	building_selected_container.add_child(title_label)
	
	# Building description
	var desc_label = Label.new()
	desc_label.text = "A essential building for " + races[selected_race]["name"] + " settlements."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	building_selected_container.add_child(desc_label)

func _on_race_selected(race_key: String):
	selected_race = race_key
	selected_building = "town_center"  # Auto-select town center for any race
	_update_race_info()
	_update_buildings_grid()

func _on_building_selected(building: String):
	selected_building = building
	
	# Update button highlighting
	for child in buildings_grid.get_children():
		if child is Button:
			var button = child as Button
			var button_building = button.text.to_lower().replace(" ", "_")
			if button_building == building:
				button.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
			else:
				button.modulate = Color.WHITE  # Normal color
	
	_update_selected_building_info()

func _finish_race_selection():
	# This method is now called indirectly through world_creation_modal
	# Just finish the race selection modal, don't advance steps
	_finish_race_selection_internal()

func _finish_race_selection_internal():
	# Store race and building selection in world data
	if world_creation_modal.world_data.has("player_data"):
		world_creation_modal.world_data["player_data"].merge({
			"race": selected_race,
			"starting_building": selected_building
		})
	else:
		world_creation_modal.world_data["player_data"] = {
			"race": selected_race,
			"starting_building": selected_building
		}
	
	# Clean up and let the normal step progression handle the next steps
	queue_free()

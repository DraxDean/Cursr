extends Window

signal building_selected(building_data)

var building_grid;

var building_list = [
	{"name": "human_town_center", "path": "res://assets/sprites/human_towncentre.png"},
	{"name": "human_fishinghut", "path": "res://assets/sprites/human_fishinghut.png"},
	{"name": "human_barracks", "path": "res://assets/sprites/human_barracks.png"}
	
]

func _on_building_button_pressed(building_data):
	print("Building selected: ", building_data)
	building_selected.emit(building_data)
	queue_free()  # Close the window

func filter_building_list():
	print("UIManager: filtering building list.")
	return building_list	

func setup():
	print("Building Selector: Setup...")
	
	building_grid = GridContainer.new()
	building_grid.columns = 2  # Set number of columns
	
	# Add it to the scene (assuming you have a parent container)
	add_child(building_grid)

	print("UIManager: populate building list.")
	for building_data in filter_building_list():
		var button = Button.new()
		button.name = building_data.name + "_button" # Give the button a unique name
		button.text = building_data.name
		button.flat = true # Optional: Make the button appear flat

		var texture_rect = TextureRect.new()
		var texture = load(building_data.path)
		if texture is Texture2D or texture is CompressedTexture2D: # Check if loading was successful
			texture_rect.texture = texture # Assign the loaded texture to the TextureRect
			button.add_child(texture_rect)

			# Set a minimum size for the button to accommodate the image
			button.custom_minimum_size = Vector2(64, 64); # Adjust multiplier as needed for padding
			#button.stretch_mode = TextureButton.STRETCH_SCALE;

			# Store the building data in the button's metadata or a custom property
			button.set_meta("building_data", building_data);
			print("UIManager: Connecting button data: ", building_data);
			button.pressed.connect(_on_building_button_pressed.bind(building_data));
			#print("UIManager: Signal connected successfully for button: ", button.name);
			#print("Button type: ", button.get_class())
			#print("Button disabled: ", button.disabled)
			#print("Button mouse filter: ", button.mouse_filter)
			#print("Connected signals: ", button.pressed.get_connections())

			building_grid.add_child(button);
		else:
			printerr("Error loading texture:", building_data.path);
			button.text = "Error" # Show an error on the button
	for child in building_grid.get_children():
		print("UIManager: Added button: ", child.name, " (Type:", child.get_class(), ")")
			

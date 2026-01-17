extends Node2D

# Building properties
var building_type: String = ""
var building_data: Dictionary = {}

func _ready():
	print("Building script ready")

func setup(data: Dictionary):
	"""Set up the building with the provided data"""
	building_data = data
	if data.has("type"):
		building_type = data["type"]
	
	# Set sprite texture if provided
	if data.has("texture_path") and ResourceLoader.exists(data["texture_path"]):
		var sprite = get_node("Sprite2D")
		var texture = load(data["texture_path"])
		sprite.texture = texture
		
		# Center the sprite within the building node
		# The building node position should be at tile center, sprite should be offset to center on tile
		var tile_size = Vector2(32, 32)  # Get from tilemap if available
		var sprite_size = texture.get_size()
		
		# Calculate offset to center sprite on tile
		var offset_x = (tile_size.x - sprite_size.x) / 2.0
		var offset_y = (tile_size.y - sprite_size.y) / 2.0
		sprite.position = Vector2(offset_x, offset_y)
	
	# Set metadata if provided
	if data.has("owner_player"):
		set_meta("owner_player", data["owner_player"])
	if data.has("building_type"):
		set_meta("building_type", data["building_type"])
	if data.has("construction_day"):
		set_meta("construction_day", data["construction_day"])
	
	print("Building setup complete with data: ", building_data)
	
func get_building_type() -> String:
	return building_type

func get_building_data() -> Dictionary:
	return building_data

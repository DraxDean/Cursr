extends Node2D

# Building properties
var building_type: String = ""
var building_data: Dictionary = {}

func _ready():
	DebugConfig.dprint("buildings", ["Building script ready"])

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
		# For large buildings positioned at the upside-down triangle meeting point,
		# no additional offset is needed - the node position is correct
		sprite.offset = Vector2.ZERO
	
	# Set metadata if provided
	if data.has("owner_player"):
		set_meta("owner_player", data["owner_player"])
	if data.has("building_type"):
		set_meta("building_type", data["building_type"])
	if data.has("construction_day"):
		set_meta("construction_day", data["construction_day"])
	
	DebugConfig.dprint("buildings", ["Building setup complete with data: ", building_data])
	
func get_building_type() -> String:
	return building_type

func get_building_data() -> Dictionary:
	return building_data

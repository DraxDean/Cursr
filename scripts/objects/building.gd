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
	
	print("Building setup complete with data: ", building_data)
	
	# You can add more setup logic here, such as:
	# - Setting building sprite based on type
	# - Configuring building stats
	# - Setting up any building-specific behavior
	
func get_building_type() -> String:
	return building_type

func get_building_data() -> Dictionary:
	return building_data

# building.gd
class_name WorldBuilding
extends WorldObject

@export var building_type: String = "house"
@export var owning_player: String = ""
@export var capacity: int = 4
@export var current_occupants: int = 0
@export var defense_value: int = 0
@export var production_type: String = ""  # What this building produces
@export var production_rate: int = 0  # Items per turn

func _init(p_building_type: String = "house", p_capacity: int = 4):
	object_type = "building"
	blocking = true
	interactable = true
	building_type = p_building_type
	capacity = p_capacity
	
	# Set building-specific properties
	match building_type:
		"house":
			defense_value = 2
		"barracks":
			defense_value = 8
			capacity = 10
		"farm":
			production_type = "food"
			production_rate = 3
		"mine":
			production_type = "ore"
			production_rate = 2
		"castle":
			defense_value = 20
			capacity = 50

func setup_object():
	super.setup_object()
	
	# Set sprite based on building type
	sprite_path = "res://sprites/buildings/human_barracks.png"
	
	# Load the appropriate sprite
	if sprite_path != "" and sprite != null:
		var texture = load(sprite_path)
		if texture:
			sprite.texture = texture
		else:
			print("Warning: Could not load texture: ", sprite_path)

func interact(player):
	match building_type:
		"house":
			print("A cozy house. Occupants: ", current_occupants, "/", capacity)
		"barracks":
			print("Military barracks. Can train units here.")
		"farm":
			print("Farm producing ", production_rate, " food per turn.")
		"mine":
			print("Mine producing ", production_rate, " ore per turn.")
		"castle":
			print("Mighty castle! Defense: ", defense_value)
		_:
			print("A ", building_type, " building.")

func add_occupant() -> bool:
	if current_occupants < capacity:
		current_occupants += 1
		return true
	return false

func remove_occupant() -> bool:
	if current_occupants > 0:
		current_occupants -= 1
		return true
	return false

func get_object_data() -> Dictionary:
	var data = super.get_object_data()
	data["building_type"] = building_type
	data["owner"] = owner
	data["capacity"] = capacity
	data["current_occupants"] = current_occupants
	data["defense_value"] = defense_value
	data["production_type"] = production_type
	data["production_rate"] = production_rate
	return data

func set_object_data(data: Dictionary):
	super.set_object_data(data)
	building_type = data.get("building_type", "house")
	owner = data.get("owner", "")
	capacity = data.get("capacity", 4)
	current_occupants = data.get("current_occupants", 0)
	defense_value = data.get("defense_value", 0)
	production_type = data.get("production_type", "")
	production_rate = data.get("production_rate", 0)

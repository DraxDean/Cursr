# mountain.gd
class_name WorldMountain
extends WorldObject

@export var mountain_type: String = "rocky"
@export var elevation: int = 1000  # Height in meters
@export var mineable: bool = true
@export var ore_type: String = "iron"
@export var ore_yield: int = 10

func _init(p_mountain_type: String = "rocky", p_elevation: int = 1000):
	object_type = "mountain"
	blocking = true
	interactable = true
	mountain_type = p_mountain_type
	elevation = p_elevation

func setup_object():
	super.setup_object()
	
	# Set sprite based on mountain type
	sprite_path = "res://sprites/mountain.png"
	
	# Load the appropriate sprite
	if sprite_path != "" and sprite != null:
		var texture = load(sprite_path)
		if texture:
			sprite.texture = texture
		else:
			print("Warning: Could not load texture: ", sprite_path)

func interact(player):
	if mineable:
		print("Mining ", mountain_type, " mountain! Gained ", ore_yield, " ", ore_type, " ore.")
		# Add ore to player inventory
		# player.add_item(ore_type + "_ore", ore_yield)
	else:
		print("This mountain cannot be mined.")

func get_object_data() -> Dictionary:
	var data = super.get_object_data()
	data["mountain_type"] = mountain_type
	data["elevation"] = elevation
	data["mineable"] = mineable
	data["ore_type"] = ore_type
	data["ore_yield"] = ore_yield
	return data

func set_object_data(data: Dictionary):
	super.set_object_data(data)
	mountain_type = data.get("mountain_type", "rocky")
	elevation = data.get("elevation", 1000)
	mineable = data.get("mineable", true)
	ore_type = data.get("ore_type", "iron")
	ore_yield = data.get("ore_yield", 10)

# tree.gd
class_name WorldTree
extends WorldObject

@export var tree_type: String = "oak"
@export var growth_stage: int = 2  # 0=sapling, 1=young, 2=mature
@export var harvestable: bool = true
@export var wood_yield: int = 5

func _init():
	object_type = "tree"
	blocking = true
	interactable = true

func setup_object():
	super.setup_object()
	
	# Set sprite based on tree type and growth stage
	sprite_path = "res://sprites/tree.png"
	
	print(sprite);
	# Load the appropriate sprite
	if sprite_path != "":
		var texture = load(sprite_path)
		if texture:
			sprite.texture = texture

func interact(player):
	if harvestable:
		print("Chopping down ", tree_type, " tree! Gained ", wood_yield, " wood.")
		# Add wood to player inventory
		# player.add_item("wood", wood_yield)
		# Remove tree from world
		#queue_free()
	else:
		print("This tree is too young to harvest.")

func get_object_data() -> Dictionary:
	var data = super.get_object_data()
	data["tree_type"] = tree_type
	data["growth_stage"] = growth_stage
	data["harvestable"] = harvestable
	data["wood_yield"] = wood_yield
	return data

func set_object_data(data: Dictionary):
	super.set_object_data(data)
	tree_type = data.get("tree_type", "oak")
	growth_stage = data.get("growth_stage", 2)
	harvestable = data.get("harvestable", true)
	wood_yield = data.get("wood_yield", 5)

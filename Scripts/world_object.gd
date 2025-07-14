# world_object.gd
class_name WorldObject
extends Node2D

# Base properties that all world objects share
@export var object_type: String = "generic"
@export var object_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var blocking: bool = false  # Does this object block movement?
@export var interactable: bool = false
@export var sprite_path: String = ""

# Visual components
var sprite: Sprite2D
var collision_shape: CollisionShape2D

# Called when the node enters the scene tree
func _ready():
	create_visual_components()
	setup_object()

# Create the visual components programmatically
func create_visual_components():
	# Create sprite
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create collision area (optional)
	var area = Area2D.new()
	collision_shape = CollisionShape2D.new()
	area.add_child(collision_shape)
	add_child(area)

# Virtual method to be overridden by subclasses
func setup_object():
	if sprite_path != "":
		var texture = load(sprite_path)
		if texture and sprite:
			sprite.texture = texture

# Virtual method for interaction
func interact(player):
	print("Interacting with ", object_type, " at ", grid_position)

# Get object data for serialization
func get_object_data() -> Dictionary:
	return {
		"type": object_type,
		"id": object_id,
		"position": grid_position,
		"blocking": blocking,
		"interactable": interactable
	}

# Set object data from serialized data
func set_object_data(data: Dictionary):
	object_type = data.get("type", "generic")
	object_id = data.get("id", "")
	grid_position = data.get("position", Vector2i.ZERO)
	blocking = data.get("blocking", false)
	interactable = data.get("interactable", false)

# Position the object in world space based on grid coordinates
func set_grid_position(pos: Vector2i, tile_size: int = 32):
	grid_position = pos
	position = Vector2(pos.x * tile_size, pos.y * tile_size)

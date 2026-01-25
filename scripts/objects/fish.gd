extends Node2D

var fish_texture = preload("res://assets/modifiers/fish.png")
var fish_id = -1  # Set by map_object_manager
var tile_coords = Vector2i.ZERO  # Set by map_object_manager

func _ready():
	# Ensure texture is properly loaded
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		sprite.texture = fish_texture
		
		# Validation logging
		if sprite.texture == null:
			push_error("FISH %d: Texture is NULL after assignment!" % fish_id)
		elif sprite.texture != fish_texture:
			push_error("FISH %d: Texture mismatch! Expected %s, got %s" % [fish_id, fish_texture, sprite.texture])
		else:
			print("FISH %d at %s: Texture loaded successfully (%s)" % [fish_id, tile_coords, sprite.texture.resource_path])

func _process(_delta):
	# Runtime validation - check if texture got corrupted
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if sprite.texture == null and fish_id >= 0:
			push_error("FISH %d: Texture became NULL at runtime! Coords: %s" % [fish_id, tile_coords])
			# Try to restore
			sprite.texture = fish_texture


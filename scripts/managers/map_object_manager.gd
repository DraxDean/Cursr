# scripts/managers/map_object_manager.gd
extends Node

# References (set via setup)
var map_objects_holder: Node2D
var tilemap_layer: TileMapLayer
var tree_scene: PackedScene
var mountain_scene: PackedScene

# Tunables (set via setup or kept here)
var tree_spawn_chance: float = 0.7
var mountain_spawn_chance: float = 0.5

# Tile Coordinates (Set via setup)
var forest_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
var mountain_tile_coords: Vector2i = Vector2i.ZERO # Default invalid

var rng = RandomNumberGenerator.new()


func _ready():
	rng.randomize()
	print("MapObjectManager ready.")


func setup(_holder: Node2D, _tilemap: TileMapLayer, _tree_scn: PackedScene, _mountain_scn: PackedScene, _forest_coords: Vector2i, _mountain_coords: Vector2i):
	map_objects_holder = _holder
	tilemap_layer = _tilemap
	tree_scene = _tree_scn
	mountain_scene = _mountain_scn
	forest_tile_coords = _forest_coords
	mountain_tile_coords = _mountain_coords

	if not is_instance_valid(map_objects_holder) or not is_instance_valid(tilemap_layer):
		push_error("MapObjectManager: Invalid holder or tilemap node provided.")
	if not tree_scene: push_warning("MapObjectManager: Tree scene not assigned.")
	if not mountain_scene: push_warning("MapObjectManager: Mountain scene not assigned.")
	print("MapObjectManager setup complete.")


func clear_objects():
	print("MapObjectManager: Clearing existing map objects...")
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node is not valid!"); return
	for child in map_objects_holder.get_children():
		child.queue_free()


func place_objects(world_data: Dictionary):
	print("MapObjectManager: Placing map objects...")
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): print("MapObjectManager: No world data to place objects on."); return
	if forest_tile_coords == Vector2i.ZERO and mountain_tile_coords == Vector2i.ZERO:
		push_warning("MapObjectManager: Tile coordinates for objects not set up.")
		return # Avoid errors if coords weren't set

	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		var current_atlas_coords = tile_info["atlas_coords"]

		# Place Trees
		if current_atlas_coords == forest_tile_coords and tree_scene:
			if rng.randf() < tree_spawn_chance:
				var y_offset = rng.randi_range(-12, -8)
				_place_single_object(tree_scene, coords, y_offset)

		# Place Mountains
		elif current_atlas_coords == mountain_tile_coords and mountain_scene:
			if rng.randf() < mountain_spawn_chance:
				var y_offset = rng.randi_range(0, 4)
				_place_single_object(mountain_scene, coords, y_offset)

	print("MapObjectManager: Map object placement finished.")


func _place_single_object(scene: PackedScene, tile_coords: Vector2i, y_offset: int = 0):
	if not scene: return
	if not is_instance_valid(tilemap_layer) or not is_instance_valid(map_objects_holder): return
	var instance = scene.instantiate()
	var world_pos = tilemap_layer.map_to_local(tile_coords)
	instance.position = world_pos + Vector2(0, y_offset)
	map_objects_holder.add_child(instance)
<<<<<<< Updated upstream
=======

func place_building(building_data, coords):
	print("Map Object Manager: Placing building: ", building_data, " at: ", coords);
	var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
	# Try to set the script manually
	if building_scene.get_script() == null:
		var building_script = preload("res://scripts/objects/building.gd")  # adjust path as needed
		building_scene.set_script(building_script)
	
	if building_scene.has_method("setup"):
		building_scene.setup(building_data)
	else:
		print("ERROR: Building Scene no setup method!")
		
	#	add to building list in the future

	#print("Map Object Manager: at tile: ", coords, " before: ", tilemap_layer.get_cell(coords));
	#tilemap_layer.set_cell(new_cell_data);
	#print("Map Object Manager: at tile: ", coords, " after: ", tilemap_layer.get_cell(coords));

	
>>>>>>> Stashed changes

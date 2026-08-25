# scripts/managers/map_object_manager.gd
extends Node

# References (set via setup)
var map_objects_holder: Node2D
var tilemap_layer: TileMapLayer
var game_node: Node  # Reference to main game node
var tree_scene: PackedScene
var mountain_scene: PackedScene
var fish_scene: PackedScene

# Tunables (set via setup or kept here)
var tree_spawn_chance: float = 0.7
var mountain_spawn_chance: float = 0.5

# Tile Coordinates (Set via setup)
var forest_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
var mountain_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
var ocean_tile_coords: Vector2i = Vector2i.ZERO # Default invalid

var rng = RandomNumberGenerator.new()


func _ready():
	rng.randomize()
	DebugConfig.dprint("map_objects", ["MapObjectManager ready."])


func setup(_holder: Node2D, _tilemap: TileMapLayer, _tree_scn: PackedScene, _mountain_scn: PackedScene, _forest_coords: Vector2i, _mountain_coords: Vector2i, _game_node: Node = null, _fish_scn: PackedScene = null, _ocean_coords: Vector2i = Vector2i.ZERO):
	map_objects_holder = _holder
	tilemap_layer = _tilemap
	game_node = _game_node
	tree_scene = _tree_scn
	mountain_scene = _mountain_scn
	fish_scene = _fish_scn
	forest_tile_coords = _forest_coords
	mountain_tile_coords = _mountain_coords
	ocean_tile_coords = _ocean_coords

	if not is_instance_valid(map_objects_holder) or not is_instance_valid(tilemap_layer):
		push_error("MapObjectManager: Invalid holder or tilemap node provided.")
	if not tree_scene: push_warning("MapObjectManager: Tree scene not assigned.")
	if not mountain_scene: push_warning("MapObjectManager: Mountain scene not assigned.")
	if not fish_scene: push_warning("MapObjectManager: Fish scene not assigned.")
	DebugConfig.dprint("map_objects", ["MapObjectManager setup complete."])


func clear_objects():
	DebugConfig.dprint("map_objects", ["MapObjectManager: Clearing existing map objects..."])
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node is not valid!"); return
	for child in map_objects_holder.get_children():
		child.queue_free()


func place_objects(world_data: Dictionary):
	DebugConfig.dprint("map_objects", ["MapObjectManager: Placing map objects..."])
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): DebugConfig.dprint("map_objects", ["MapObjectManager: No world data to place objects on."]); return
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

	DebugConfig.dprint("map_objects", ["MapObjectManager: Map object placement finished."])

func place_mountains_only(world_data: Dictionary):
	DebugConfig.dprint("map_objects", ["MapObjectManager: Placing mountains only..."])
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): DebugConfig.dprint("map_objects", ["MapObjectManager: No world data to place objects on."]); return
	if mountain_tile_coords == Vector2i.ZERO:
		push_warning("MapObjectManager: Mountain tile coordinates not set up.")
		return

	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		var current_atlas_coords = tile_info["atlas_coords"]

		# Place Mountains only
		if current_atlas_coords == mountain_tile_coords and mountain_scene:
			if rng.randf() < mountain_spawn_chance:
				var y_offset = rng.randi_range(0, 4)
				_place_single_object(mountain_scene, coords, y_offset)

	DebugConfig.dprint("map_objects", ["MapObjectManager: Mountain placement finished."])

func place_trees_only(world_data: Dictionary):
	DebugConfig.dprint("map_objects", ["MapObjectManager: Placing trees only..."])
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): DebugConfig.dprint("map_objects", ["MapObjectManager: No world data to place objects on."]); return
	if forest_tile_coords == Vector2i.ZERO:
		push_warning("MapObjectManager: Forest tile coordinates not set up.")
		return

	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		var current_atlas_coords = tile_info["atlas_coords"]

		# Place Trees only
		if current_atlas_coords == forest_tile_coords and tree_scene:
			if rng.randf() < tree_spawn_chance:
				var y_offset = rng.randi_range(-12, -8)
				_place_single_object(tree_scene, coords, y_offset)

	DebugConfig.dprint("map_objects", ["MapObjectManager: Tree placement finished."])

func place_fish(world_data: Dictionary):
	DebugConfig.dprint("map_objects", ["MapObjectManager: Placing fish..."])
	DebugConfig.dprint("map_objects", ["MapObjectManager: is_instance_valid(map_objects_holder) = %s" % is_instance_valid(map_objects_holder)])
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node invalid!")
		return
	
	DebugConfig.dprint("map_objects", ["MapObjectManager: world_data.is_empty() = %s" % world_data.is_empty()])
	if world_data.is_empty(): 
		DebugConfig.dprint("map_objects", ["MapObjectManager: No world data to place objects on."])
		return
	
	DebugConfig.dprint("map_objects", ["MapObjectManager: fish_scene = %s" % fish_scene])
	if not fish_scene:
		push_error("MapObjectManager: Fish scene not assigned.")
		return

	DebugConfig.dprint("map_objects", ["MapObjectManager: Fish scene is valid. Starting iteration..."])
	var fish_count = 0
	var tiles_checked = 0
	for coords in world_data:
		tiles_checked += 1
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		if not tile_info.has("fish"): continue

		# Place Fish on marked tiles
		if tile_info["fish"] == true:
			DebugConfig.dprint("map_objects", ["MapObjectManager: Placing fish at %s" % coords])
			var y_offset = rng.randi_range(-8, 8)
			_place_single_object(fish_scene, coords, y_offset)
			fish_count += 1

	DebugConfig.dprint("map_objects", ["MapObjectManager: Fish placement finished. Checked %d tiles, placed %d fish." % [tiles_checked, fish_count]])

func clear_mountains_only():
	DebugConfig.dprint("map_objects", ["MapObjectManager: Clearing mountain objects only..."])
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node is not valid!")
		return
		
	# Remove only mountain objects
	for child in map_objects_holder.get_children():
		if child.name.begins_with("Mountain") or child.scene_file_path.ends_with("mountain.tscn"):
			child.queue_free()
	
	DebugConfig.dprint("map_objects", ["MapObjectManager: Mountain objects cleared."])

func clear_trees_only():
	DebugConfig.dprint("map_objects", ["MapObjectManager: Clearing tree objects only..."])
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node is not valid!")
		return
		
	# Remove only tree objects
	for child in map_objects_holder.get_children():
		if child.name.begins_with("Tree") or child.scene_file_path.ends_with("tree.tscn"):
			child.queue_free()
	
	DebugConfig.dprint("map_objects", ["MapObjectManager: Tree objects cleared."])


func _place_single_object(scene: PackedScene, tile_coords: Vector2i, y_offset: int = 0):
	if not scene: return
	if not is_instance_valid(tilemap_layer) or not is_instance_valid(map_objects_holder): return
	var instance = scene.instantiate()
	var world_pos = tilemap_layer.map_to_local(tile_coords)
	instance.position = world_pos + Vector2(0, y_offset)
	map_objects_holder.add_child(instance)
	
	# Register with game's environment system if game node is available
	if game_node:
		if game_node.has_method("register_mountain") and scene == mountain_scene:
			game_node.register_mountain(instance)
		elif game_node.has_method("register_tree") and scene == tree_scene:
			game_node.register_tree(instance)
		elif game_node.has_method("register_fish") and scene == fish_scene:
			DebugConfig.dprint("map_objects", ["_place_single_object: Placing fish at %s" % instance.position])
			game_node.register_fish(instance)

func place_objects_from_save(environment_objects_data: Array):
	"""Restore environment objects at their exact saved positions (no RNG, no re-registration)."""
	if not is_instance_valid(map_objects_holder):
		push_error("MapObjectManager: map_objects_holder invalid in place_objects_from_save")
		return
	for obj_info in environment_objects_data:
		var object_type = obj_info.get("object_type", "")
		var position = obj_info.get("position", Vector2.ZERO)
		var scene: PackedScene = null
		match object_type:
			"mountain": scene = mountain_scene
			"tree": scene = tree_scene
			"fish": scene = fish_scene
		if not scene:
			push_warning("MapObjectManager: No scene for object type '%s'" % object_type)
			continue
		var instance = scene.instantiate()
		instance.position = position
		map_objects_holder.add_child(instance)
	DebugConfig.dprint("map_objects", ["MapObjectManager: Placed %d environment objects from save." % environment_objects_data.size()])


func place_building(building_data, coords):
	DebugConfig.dprint("map_objects", ["Map Object Manager: Placing building: ", building_data, " at: ", coords]);
	var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
	
	# Prepare setup data with texture path
	var setup_data = building_data.duplicate()
	if building_data.has("texture") and building_data["texture"] is Texture2D:
		# Convert texture to path for consistency
		var texture_path = "res://assets/buildings/human_finshinghut.png"  # Default fallback
		if building_data.has("id"):
			match building_data["id"]:
				"house":
					texture_path = "res://assets/buildings/human_finshinghut.png"
				"fishing_hut":
					texture_path = "res://assets/buildings/human_finshinghut.png"
				"town_center":
					texture_path = "res://assets/buildings/human_finshinghut.png"
		setup_data["texture_path"] = texture_path
	
	if building_scene.has_method("setup"):
		building_scene.setup(setup_data)
	else:
		DebugConfig.dprint("map_objects", ["ERROR: Building Scene has no setup method!"])
		
	# Position the building at the correct location (center of tile)
	if is_instance_valid(tilemap_layer) and is_instance_valid(map_objects_holder):
		var world_pos = tilemap_layer.map_to_local(coords)
		building_scene.position = world_pos
		map_objects_holder.add_child(building_scene)
	
	#	add to building list in the future

	#print("Map Object Manager: at tile: ", coords, " before: ", tilemap_layer.get_cell(coords));
	#tilemap_layer.set_cell(new_cell_data);
	#print("Map Object Manager: at tile: ", coords, " after: ", tilemap_layer.get_cell(coords));

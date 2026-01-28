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
var fish_spawn_chance: float = 0.6

# Tile Coordinates (Set via setup)
var forest_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
var mountain_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
<<<<<<< HEAD
var ocean_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
=======
var fish_tile_coords: Vector2i = Vector2i.ZERO # Default invalid
>>>>>>> 2aeb49ef4a2144d1f1dda9b7f0a82b9074dac175

var rng = RandomNumberGenerator.new()


func _ready():
	rng.randomize()
	print("MapObjectManager ready.")


<<<<<<< HEAD
func setup(_holder: Node2D, _tilemap: TileMapLayer, _tree_scn: PackedScene, _mountain_scn: PackedScene, _forest_coords: Vector2i, _mountain_coords: Vector2i, _game_node: Node = null, _fish_scn: PackedScene = null, _ocean_coords: Vector2i = Vector2i.ZERO):
=======
func setup(_holder: Node2D, _tilemap: TileMapLayer, _tree_scn: PackedScene, _mountain_scn: PackedScene, _forest_coords: Vector2i, _mountain_coords: Vector2i, _game_node: Node = null, _fish_scn: PackedScene = null, _fish_coords: Vector2i = Vector2i.ZERO):
>>>>>>> 2aeb49ef4a2144d1f1dda9b7f0a82b9074dac175
	map_objects_holder = _holder
	tilemap_layer = _tilemap
	game_node = _game_node
	tree_scene = _tree_scn
	mountain_scene = _mountain_scn
	fish_scene = _fish_scn
	forest_tile_coords = _forest_coords
	mountain_tile_coords = _mountain_coords
<<<<<<< HEAD
	ocean_tile_coords = _ocean_coords
=======
	fish_tile_coords = _fish_coords
>>>>>>> 2aeb49ef4a2144d1f1dda9b7f0a82b9074dac175

	if not is_instance_valid(map_objects_holder) or not is_instance_valid(tilemap_layer):
		push_error("MapObjectManager: Invalid holder or tilemap node provided.")
	if not tree_scene: push_warning("MapObjectManager: Tree scene not assigned.")
	if not mountain_scene: push_warning("MapObjectManager: Mountain scene not assigned.")
	if not fish_scene: push_warning("MapObjectManager: Fish scene not assigned.")
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
	if forest_tile_coords == Vector2i.ZERO and mountain_tile_coords == Vector2i.ZERO and fish_tile_coords == Vector2i.ZERO:
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

		# Place Fish
		elif current_atlas_coords == fish_tile_coords and fish_scene:
			if rng.randf() < fish_spawn_chance:
				# Fish are water-based, use consistent offset to stay at tile center
				var y_offset = 0
				_place_single_object(fish_scene, coords, y_offset)

	print("MapObjectManager: Map object placement finished.")

func place_mountains_only(world_data: Dictionary):
	print("MapObjectManager: Placing mountains only...")
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): print("MapObjectManager: No world data to place objects on."); return
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

	print("MapObjectManager: Mountain placement finished.")

func place_trees_only(world_data: Dictionary):
	print("MapObjectManager: Placing trees only...")
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): print("MapObjectManager: No world data to place objects on."); return
	if forest_tile_coords == Vector2i.ZERO:
		push_warning("MapObjectManager: Forest tile coordinates not set up.")
		return

	var tree_count = 0
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		var current_atlas_coords = tile_info["atlas_coords"]

		# Place Trees only
		if current_atlas_coords == forest_tile_coords and tree_scene:
			if rng.randf() < tree_spawn_chance:
				var y_offset = rng.randi_range(-12, -8)
				_place_single_object(tree_scene, coords, y_offset)
				tree_count += 1

	print("MapObjectManager: Tree placement finished. Total trees placed: %d" % tree_count)

func place_fish_only(world_data: Dictionary):
	print("MapObjectManager: Placing fish only...")
	if not is_instance_valid(map_objects_holder): push_error("MapObjects holder node invalid!"); return
	if world_data.is_empty(): print("MapObjectManager: No world data to place objects on."); return
	if fish_tile_coords == Vector2i.ZERO:
		push_warning("MapObjectManager: Fish tile coordinates not set up.")
		return
	
	# DEBUG: Check tilemap and holder state
	print("DEBUG: Tilemap position: %s, scale: %s" % [tilemap_layer.position, tilemap_layer.scale])
	print("DEBUG: Objects holder position: %s, scale: %s" % [map_objects_holder.position, map_objects_holder.scale])

	var fish_count = 0
	var placed_coords = []
	for coords in world_data:
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		var current_atlas_coords = tile_info["atlas_coords"]

		# Place Fish only
		if current_atlas_coords == fish_tile_coords and fish_scene:
			if rng.randf() < fish_spawn_chance:
				# Use a consistent Y offset for fish to maintain alignment with ocean tiles
				# Fish are water-based, so they should stay closer to the tile center
				var y_offset = 0  # Fixed at center for water creatures
				_place_single_object(fish_scene, coords, y_offset)
				placed_coords.append(coords)
				fish_count += 1

	print("MapObjectManager: Fish placement finished. Total fish placed: %d" % fish_count)
	if fish_count > 0 and fish_count <= 10:
		print("DEBUG: All fish placed at coordinates: %s" % [placed_coords])

func place_fish(world_data: Dictionary):
	print("MapObjectManager: Placing fish...")
	print("MapObjectManager: is_instance_valid(map_objects_holder) = %s" % is_instance_valid(map_objects_holder))
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node invalid!")
		return
	
	print("MapObjectManager: world_data.is_empty() = %s" % world_data.is_empty())
	if world_data.is_empty(): 
		print("MapObjectManager: No world data to place objects on.")
		return
	
	print("MapObjectManager: fish_scene = %s" % fish_scene)
	if not fish_scene:
		push_error("MapObjectManager: Fish scene not assigned.")
		return

	print("MapObjectManager: Fish scene is valid. Starting iteration...")
	var fish_count = 0
	var tiles_checked = 0
	for coords in world_data:
		tiles_checked += 1
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY or not tile_info.has("atlas_coords"): continue
		if not tile_info.has("fish"): continue

		# Place Fish on marked tiles
		if tile_info["fish"] == true:
			print("MapObjectManager: Placing fish at %s" % coords)
			var y_offset = rng.randi_range(-8, 8)
			_place_single_object(fish_scene, coords, y_offset)
			fish_count += 1

	print("MapObjectManager: Fish placement finished. Checked %d tiles, placed %d fish." % [tiles_checked, fish_count])

func clear_mountains_only():
	print("MapObjectManager: Clearing mountain objects only...")
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node is not valid!")
		return
		
	# Remove only mountain objects
	for child in map_objects_holder.get_children():
		if child.name.begins_with("Mountain") or child.scene_file_path.ends_with("mountain.tscn"):
			child.queue_free()
	
	print("MapObjectManager: Mountain objects cleared.")

func clear_trees_only():
	print("MapObjectManager: Clearing tree objects only...")
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node is not valid!")
		return
		
	# Remove only tree objects
	for child in map_objects_holder.get_children():
		if child.name.begins_with("Tree") or child.scene_file_path.ends_with("tree.tscn"):
			child.queue_free()
	
	print("MapObjectManager: Tree objects cleared.")

func clear_fish_only():
	print("MapObjectManager: Clearing fish objects only...")
	if not is_instance_valid(map_objects_holder): 
		push_error("MapObjects holder node is not valid!")
		return
		
	# Remove only fish objects
	for child in map_objects_holder.get_children():
		if child.name.begins_with("Fish") or child.name.begins_with("fish_") or child.scene_file_path.ends_with("fish.tscn"):
			child.queue_free()
	
	print("MapObjectManager: Fish objects cleared.")


func place_bays_only(world_data: Dictionary):
	print("MapObjectManager: Placing bays only...")
	if world_data.is_empty(): print("MapObjectManager: No world data to place bays on."); return
	
	# Call the world gen bay carving function
	var world_gen = preload("res://scripts/world_gen/world_gen.gd").new()
	world_gen._generate_bays(100, 100, world_data)  # MAP_WIDTH and MAP_HEIGHT are 100
	
	print("MapObjectManager: Bay placement finished.")

func clear_bays_only():
	print("MapObjectManager: Clearing bays (reverting to ocean)...")
	# Bays are terrain, not objects, so we handle this in world_creation_modal by reloading previous state
	print("MapObjectManager: Bays cleared via state revert.")


func _place_single_object(scene: PackedScene, tile_coords: Vector2i, y_offset: int = 0):
	if not scene: return
	if not is_instance_valid(tilemap_layer) or not is_instance_valid(map_objects_holder): return
	var instance = scene.instantiate()
	var world_pos = tilemap_layer.map_to_local(tile_coords)
	instance.position = world_pos + Vector2(0, y_offset)
	
	# Set debug info for fish
	if scene == fish_scene and instance.has_meta("fish_id") == false:
		# Generate a simple counter for fish tracking
		instance.fish_id = hash(tile_coords) % 100000
		instance.tile_coords = tile_coords
	
	map_objects_holder.add_child(instance)
	
	# Register with game's environment system if game node is available
<<<<<<< HEAD
	if game_node:
		if game_node.has_method("register_mountain") and scene == mountain_scene:
			game_node.register_mountain(instance)
		elif game_node.has_method("register_tree") and scene == tree_scene:
			game_node.register_tree(instance)
		elif game_node.has_method("register_fish") and scene == fish_scene:
			print("_place_single_object: Placing fish at %s" % instance.position)
=======
	if game_node and game_node.has_method("register_mountain") and game_node.has_method("register_tree") and game_node.has_method("register_fish"):
		if scene == mountain_scene:
			game_node.register_mountain(instance)
		elif scene == tree_scene:
			game_node.register_tree(instance)
		elif scene == fish_scene:
>>>>>>> 2aeb49ef4a2144d1f1dda9b7f0a82b9074dac175
			game_node.register_fish(instance)


func place_building(building_data, coords):
	print("Map Object Manager: Placing building: ", building_data, " at: ", coords);
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
		print("ERROR: Building Scene has no setup method!")
		
	# Position the building at the correct location (center of tile)
	if is_instance_valid(tilemap_layer) and is_instance_valid(map_objects_holder):
		var world_pos = tilemap_layer.map_to_local(coords)
		building_scene.position = world_pos
		map_objects_holder.add_child(building_scene)
	
	#	add to building list in the future

	#print("Map Object Manager: at tile: ", coords, " before: ", tilemap_layer.get_cell(coords));
	#tilemap_layer.set_cell(new_cell_data);
	#print("Map Object Manager: at tile: ", coords, " after: ", tilemap_layer.get_cell(coords));

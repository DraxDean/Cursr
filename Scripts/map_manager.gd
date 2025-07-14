extends Node

var tilemap_layer
var dynamic_tile_data: Dictionary = {}
var world_objects: Dictionary = {}  # grid_position -> WorldObject
var objects_layer: Node2D
var map_width = 100
var map_height = 100

# Tile type constants - you can adjust these based on your tileset
enum TileType {
	DEFAULT = 0,
	GRASS = 1,
	WATER = 2,
	STONE = 3,
	DIRT = 4,
	SAND = 5,
	ICE = 6,
	FOREST = 7
}

func initialize_dynamic_data():
	# Initialize data for all tiles on the map
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			dynamic_tile_data[coords] = {
				"type": "default",  # Default tile type
				"objects": [],
				"units": [],
			}
			
	print("Map initialized.")

func setup(tilemap_layer_from_game):
	print("Map Manager Setup")
	tilemap_layer = tilemap_layer_from_game
	initialize_dynamic_data()
	
	objects_layer = Node2D.new()
	add_child(objects_layer)
	

func get_tilemap_layer():
	return tilemap_layer

# CREATE MAP - Main function to generate and render the visual map
func create_map():
	print("Creating visual map...")
	
	# Generate terrain data (you can replace this with your own generation logic)
	generate_terrain()
	
	# Render all tiles to the tilemap
	render_tilemap()
	
	print("Map creation complete!")

# Generate terrain data (basic example - you can make this more sophisticated)
func generate_terrain():
	print("Generating terrain...")
	
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			var tile_type = get_terrain_type(x, y)
			dynamic_tile_data[coords]["type"] = tile_type

# Simple terrain generation - you can replace this with noise, perlin noise, etc.
func get_terrain_type(x: int, y: int) -> String:
	# Simple example: water around edges, grass in middle, some random stone
	var distance_from_edge = min(min(x, map_width - x), min(y, map_height - y))
	
	if distance_from_edge < 3:
		return "water"
	elif distance_from_edge < 10 and randf() < 0.1:
		return "stone"
	elif randf() < 0.05:
		return "dirt"
	else:
		return "grass"

# Render the entire tilemap based on dynamic_tile_data
func render_tilemap():
	if not tilemap_layer:
		print("Warning: No tilemap layer assigned!")
		return
	
	print("Rendering tilemap...")
	
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			var tile_data = dynamic_tile_data[coords]
			set_tile_visual(coords, tile_data["type"])

# Set a single tile's visual appearance
func set_tile_visual(coords: Vector2i, tile_type: String):
	if not tilemap_layer:
		print("ERROR: no tilemap_layer")
		return
	
	var source_id = 0  # Usually 0 for the main tileset
	var atlas_coords = get_atlas_coords_for_type(tile_type)
	
	tilemap_layer.set_cell(coords, source_id, atlas_coords)

# Map tile types to tileset coordinates
func get_atlas_coords_for_type(tile_type: String) -> Vector2i:
	match tile_type:
		"default":
			return Vector2i(0, 0)
		"ice":
			return Vector2i(0, 1)
		"water":
			return Vector2i(0, 2)
		"grass":
			return Vector2i(0, 5)
		"stone":
			return Vector2i(0, 3)
		"forest":
			return Vector2i(0, 4)
		"dirt":
			return Vector2i(0, 6)
		_:
			return Vector2i(0, 0)  # Default to grass

# Update a specific tile (useful for dynamic changes)
func update_tile(coords: Vector2i, new_type: String):
	if coords in dynamic_tile_data:
		dynamic_tile_data[coords]["type"] = new_type
		set_tile_visual(coords, new_type)

# Clear the entire tilemap
func clear_map():
	if tilemap_layer:
		tilemap_layer.clear()

# Get tile type at coordinates
func get_tile_type(coords: Vector2i) -> String:
	if coords in dynamic_tile_data:
		return dynamic_tile_data[coords]["type"]
	return ""

# Check if a tile is passable (for pathfinding, etc.)
func is_tile_passable(coords: Vector2i) -> bool:
	var tile_type = get_tile_type(coords)
	match tile_type:
		"water":
			return false
		"stone":
			return false
		_:
			return true

# OBJECT FUNCTIONS (your existing code)
func add_object(obj: WorldObject, coords: Vector2i):
	# Set position and add to world
	obj.set_grid_position(coords)
	obj.position = tile_coords_to_world_pos(coords)
	objects_layer.add_child(obj)
	
	# Store in our tracking dictionary
	world_objects[coords] = obj
	
	# Update dynamic tilemap data
	if coords in dynamic_tile_data:
		dynamic_tile_data[coords]["objects"].append(obj.get_object_data())

func remove_object(coords: Vector2i):
	if coords in world_objects:
		world_objects[coords].queue_free()
		world_objects.erase(coords)
		
		# Remove from dynamic data
		if coords in dynamic_tile_data:
			dynamic_tile_data[coords]["objects"].clear()

func get_object_at(coords: Vector2i) -> WorldObject:
	return world_objects.get(coords, null)

# Add these methods to your map_manager.gd to fix hex object positioning

# Replace your existing tile_coords_to_world_pos function with this:
func tile_coords_to_world_pos(tile_coords: Vector2i) -> Vector2:
	# Use the tilemap's built-in conversion for proper hex positioning
	if tilemap_layer:
		return tilemap_layer.map_to_local(tile_coords)
	else:
		# Fallback to square grid if tilemap not available
		var tile_size = 32
		return Vector2(tile_coords.x * tile_size, tile_coords.y * tile_size)

# Replace your existing world_pos_to_tile_coords function with this:
func world_pos_to_tile_coords(world_pos: Vector2) -> Vector2i:
	# Use the tilemap's built-in conversion for proper hex positioning
	if tilemap_layer:
		return tilemap_layer.local_to_map(world_pos)
	else:
		# Fallback to square grid if tilemap not available
		var tile_size = 32
		return Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

# Also update your handle_tile_click method to use hex coordinates directly:
func handle_tile_click(tile_coords: Vector2i):
	print("Clicked on tile: ", tile_coords)
	print("Tile type: ", get_tile_type(tile_coords))
	
	# Check for objects at this position
	var obj = get_object_at(tile_coords)
	if obj:
		print("Object found: ", obj.object_type)
		obj.interact(null)  # Pass player reference when you have it
	else:
		print("No object at this position")
	
	return tile_coords

# Optional: Add a method to reposition all existing objects if needed
func reposition_all_objects():
	for coords in world_objects:
		var obj = world_objects[coords]
		var correct_world_pos = tile_coords_to_world_pos(coords)
		obj.position = correct_world_pos
		print("Repositioned object at ", coords, " to world pos: ", correct_world_pos)

#TESTS



# Test functions for all object types
func test_add_object():
	var tree = WorldTree.new()
	tree.tree_type = "pine"
	tree.growth_stage = 2
	add_object(tree, Vector2i(5, 3))
	print("Added tree at (5, 3)")

func test_add_mountain():
	var mountain = WorldMountain.new("rocky", 1500)
	mountain.ore_type = "gold"
	mountain.ore_yield = 15
	add_object(mountain, Vector2i(10, 10))
	print("Added mountain at (10, 10)")

func test_add_building():
	var building = WorldBuilding.new("castle", 50)
	building.owning_player = "Player"
	add_object(building, Vector2i(15, 15))
	print("Added castle at (15, 15)")

# Test the map creation with all objects
func test_create_full_map():
	create_map()
	
	# Add test objects
	test_add_object()      # Tree
	test_add_mountain()    # Mountain
	test_add_building()    # Building
	
	print("Full map creation test complete!")

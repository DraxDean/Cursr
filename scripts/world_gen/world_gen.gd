# world_gen.gd
extends RefCounted

# --- Constants ---
const BORDER_SIZE = 2

# Tile Atlas Coordinates (Assuming Source ID 0 for all)
const SOURCE_ID = 0
const OCEAN_COORDS = Vector2i(0, 2)
const DESERT_COORDS = Vector2i(0, 5) # Desert (sand) - was GRASS_COORDS
const MOUNTAIN_COORDS = Vector2i(0, 3)
const FOREST_COORDS = Vector2i(0, 4)
const GRASS_COORDS = Vector2i(0, 6) # Grasslands (plains) - was DESERT_COORDS
const ICE_COORDS = Vector2i(0, 1)
const FISH_COORDS = Vector2i(0, 7) # Fish modifier - ocean resource tiles

# Biome generation parameters
const NUM_MOUNTAIN_PATCHES = 4
const MOUNTAIN_PATCH_RADIUS_MIN = 4
const MOUNTAIN_PATCH_RADIUS_MAX = 10

const NUM_FOREST_PATCHES = 3
const FOREST_PATCH_RADIUS_MIN = 5
const FOREST_PATCH_RADIUS_MAX = 12

const NUM_DESERT_PATCHES = 3
const DESERT_PATCH_RADIUS_MIN = 5
const DESERT_PATCH_RADIUS_MAX = 11

const ICE_CAP_HEIGHT = 4 # How many rows from top/bottom are ice
const NUM_FISH = 60  # Target number of fish to spawn

# Bay generation parameters
const NUM_BAYS = 1  # Number of bays to create on coastline
const BAY_INDENTATION_DEPTH = 8  # How deep the bay carves into land
const BAY_INDENTATION_WIDTH = 15  # Width of the bay opening

# --- Private Variables ---
# Moved rng here so helper methods can access it without passing it everywhere
var _rng = RandomNumberGenerator.new()


# --- Main Generation Function ---

func generate_world_data(map_width: int, map_height: int) -> Dictionary:
	print("--- Starting World Generation ---")
	var world_data: Dictionary = {}
	_rng.randomize() # Initialize RNG

	# 1. Fill with base ocean
	_generate_base_ocean(map_width, map_height, world_data)
	print("Base ocean generated.")

	# 2. Generate the Pangaea continent
	_generate_continent(map_width, map_height, world_data)
	print("Continent generated.")

	# 3. Add biome patches onto the landmass
	_add_biome_patches(map_width, map_height, world_data)
	print("Biomes added.")

	# 4. Add ice caps in the ocean areas at top/bottom
	_add_ice_caps(map_width, map_height, world_data)
	print("Ice caps added.")

	# Note: Bay generation and fish spawning are now manual steps in world creation
	# They are not called automatically here to allow user control in the UI

	print("--- World Generation Finished ---")
	return world_data


# --- Generation Step Functions ---

func _generate_base_ocean(width: int, height: int, world_data: Dictionary):
	for x in range(width):
		for y in range(height):
			world_data[Vector2i(x, y)] = {
				"source_id": SOURCE_ID,
				"atlas_coords": OCEAN_COORDS
			}

func _generate_continent(width: int, height: int, world_data: Dictionary):
	var center = Vector2(width / 2.0, height / 2.0)
	var max_radius = min(center.x, center.y) - BORDER_SIZE

	if max_radius <= 0:
		push_warning("Map too small for border and continent.")
		return

	for x in range(width):
		for y in range(height):
			var current_pos = Vector2(x, y)
			var dist_to_center = current_pos.distance_to(center)
			var noise_factor = _rng.randf_range(0.7, 1.3) # Random variation

			if dist_to_center < max_radius * noise_factor :
				if x >= BORDER_SIZE and x < width - BORDER_SIZE and \
				   y >= BORDER_SIZE and y < height - BORDER_SIZE:
					world_data[Vector2i(x, y)] = {
						"source_id": SOURCE_ID,
						"atlas_coords": DESERT_COORDS
					}


func _add_biome_patches(width: int, height: int, world_data: Dictionary):
	# Calls the helper method _place_patches for each biome type
	print("Adding Mountains...")
	_place_patches(NUM_MOUNTAIN_PATCHES, MOUNTAIN_PATCH_RADIUS_MIN, MOUNTAIN_PATCH_RADIUS_MAX, MOUNTAIN_COORDS, width, height, world_data)
	print("Adding Forests...")
	_place_patches(NUM_FOREST_PATCHES, FOREST_PATCH_RADIUS_MIN, FOREST_PATCH_RADIUS_MAX, FOREST_COORDS, width, height, world_data)
	print("Adding Deserts...")
	_place_patches(NUM_DESERT_PATCHES, DESERT_PATCH_RADIUS_MIN, DESERT_PATCH_RADIUS_MAX, DESERT_COORDS, width, height, world_data)


func _add_ice_caps(width: int, height: int, world_data: Dictionary):
	if ICE_CAP_HEIGHT <= 0: return

	for x in range(width):
		# Top cap
		for y in range(min(ICE_CAP_HEIGHT, height)):
			var coords = Vector2i(x, y)
			if world_data.has(coords) and world_data[coords]["atlas_coords"] == OCEAN_COORDS:
				world_data[coords] = {
					"source_id": SOURCE_ID,
					"atlas_coords": ICE_COORDS
				}
		# Bottom cap
		for y in range(max(0, height - ICE_CAP_HEIGHT), height):
			var coords = Vector2i(x, y)
			if world_data.has(coords) and world_data[coords]["atlas_coords"] == OCEAN_COORDS:
				world_data[coords] = {
					"source_id": SOURCE_ID,
					"atlas_coords": ICE_COORDS
				}


# --- Helper Methods ---

# Helper method to place patches of a specific biome
# (Previously the nested function inside _add_biome_patches)
func _place_patches(num_patches: int, min_radius: int, max_radius: int, biome_coords: Vector2i, width: int, height: int, world_data: Dictionary):
	var placed_patches = 0
	var attempts = 0
	while placed_patches < num_patches and attempts < num_patches * 10:
		attempts += 1
		var center_x = _rng.randi_range(BORDER_SIZE, width - BORDER_SIZE - 1)
		var center_y = _rng.randi_range(BORDER_SIZE, height - BORDER_SIZE - 1)
		var potential_center_coords = Vector2i(center_x, center_y)

		if world_data.has(potential_center_coords):
			var current_tile = world_data[potential_center_coords]["atlas_coords"]
			var can_place = false
			
			# Determine if we can place this biome at this location
			if biome_coords == FOREST_COORDS:
				# Forests can be placed on desert or mountains
				can_place = (current_tile == DESERT_COORDS or current_tile == MOUNTAIN_COORDS)
			else:
				# Other biomes only on desert
				can_place = (current_tile == DESERT_COORDS)
			
			if can_place:
				var patch_radius = _rng.randi_range(min_radius, max_radius)
				_apply_circular_patch(potential_center_coords, patch_radius, biome_coords, width, height, world_data)
				placed_patches += 1


# Helper to apply a circular patch of a specific tile
func _apply_circular_patch(center: Vector2i, radius: int, tile_coords: Vector2i, width: int, height: int, world_data: Dictionary):
	# Using integer radius squared avoids needing sqrt
	var radius_squared = radius * radius
	for x_offset in range(-radius, radius + 1):
		for y_offset in range(-radius, radius + 1):
			# More accurate circular check using squared lengths
			if Vector2(x_offset, y_offset).length_squared() <= radius_squared:
				var current_coords = center + Vector2i(x_offset, y_offset)

				# Check map bounds
				if current_coords.x >= 0 and current_coords.x < width and \
				   current_coords.y >= 0 and current_coords.y < height:

					# Check if the target tile is Desert or Mountain before overwriting (allow forests on mountains)
					if world_data.has(current_coords):
						var current_tile = world_data[current_coords]["atlas_coords"]
						if tile_coords == FOREST_COORDS:
							# Forests can grow on desert or mountains
							if current_tile == DESERT_COORDS or current_tile == MOUNTAIN_COORDS:
								world_data[current_coords] = {
									"source_id": SOURCE_ID,
									"atlas_coords": tile_coords
								}
						else:
							# Other biomes only on desert
							if current_tile == DESERT_COORDS:
								world_data[current_coords] = {
									"source_id": SOURCE_ID,
									"atlas_coords": tile_coords
								}

<<<<<<< HEAD
func _place_fish(width: int, height: int, world_data: Dictionary):
	"""Place fish markers in ocean tiles"""
	var fish_placed = 0
	var attempts = 0
	var max_attempts = NUM_FISH * 5  # Allow multiple attempts per fish
	
	while fish_placed < NUM_FISH and attempts < max_attempts:
		attempts += 1
		var random_x = _rng.randi_range(0, width - 1)
		var random_y = _rng.randi_range(0, height - 1)
		var coords = Vector2i(random_x, random_y)
		
		if world_data.has(coords):
			var current_tile = world_data[coords]["atlas_coords"]
			# Place fish only in ocean tiles (not ice)
			if current_tile == OCEAN_COORDS:
				if not world_data[coords].has("fish"):
					world_data[coords]["fish"] = true
					fish_placed += 1
	
	print("_place_fish: Placed %d fish markers in the ocean (attempts: %d)" % [fish_placed, attempts])
=======
func _generate_bays(width: int, height: int, world_data: Dictionary):
	"""Generate coastal bays/indentations on the island coastline"""
	var _center = Vector2(width / 2.0, height / 2.0)
	
	# Choose random side for bay (top, bottom, left, right)
	var bay_sides = ["top", "bottom", "left", "right"]
	var bay_side = bay_sides[_rng.randi() % bay_sides.size()]
	
	var bay_center_x: int
	var bay_center_y: int
	
	match bay_side:
		"top":
			bay_center_y = BORDER_SIZE + 10
			bay_center_x = _rng.randi_range(BORDER_SIZE + 10, width - BORDER_SIZE - 10)
		"bottom":
			bay_center_y = height - BORDER_SIZE - 10
			bay_center_x = _rng.randi_range(BORDER_SIZE + 10, width - BORDER_SIZE - 10)
		"left":
			bay_center_x = BORDER_SIZE + 10
			bay_center_y = _rng.randi_range(BORDER_SIZE + 10, height - BORDER_SIZE - 10)
		"right":
			bay_center_x = width - BORDER_SIZE - 10
			bay_center_y = _rng.randi_range(BORDER_SIZE + 10, height - BORDER_SIZE - 10)
	
	# Carve out the bay
	_carve_bay(Vector2i(bay_center_x, bay_center_y), bay_side, width, height, world_data)


func _carve_bay(center: Vector2i, side: String, width: int, height: int, world_data: Dictionary):
	"""Carve a bay indentation from the specified side using circular pattern"""
	var indent_radius = int(float(BAY_INDENTATION_DEPTH) * 0.7)  # Slightly smaller for circular pattern
	var radius_squared = indent_radius * indent_radius
	
	# Create a circular indentation and offset it to the appropriate side
	for x_offset in range(-indent_radius, indent_radius + 1):
		for y_offset in range(-indent_radius, indent_radius + 1):
			# Use circular distance for natural bay shape
			if Vector2(x_offset, y_offset).length_squared() <= radius_squared:
				var x: int
				var y: int
				
				match side:
					"top":
						x = center.x + x_offset
						y = center.y + y_offset  # offset goes downward into the land
					"bottom":
						x = center.x + x_offset
						y = center.y - y_offset  # offset goes upward into the land
					"left":
						x = center.x + y_offset  # depth becomes x offset
						y = center.y + x_offset  # width becomes y offset
					"right":
						x = center.x - y_offset  # depth becomes negative x offset
						y = center.y + x_offset  # width becomes y offset
				
				if x >= BORDER_SIZE and x < width - BORDER_SIZE and y >= BORDER_SIZE and y < height - BORDER_SIZE:
					if world_data.has(Vector2i(x, y)):
						world_data[Vector2i(x, y)] = {
							"source_id": SOURCE_ID,
							"atlas_coords": OCEAN_COORDS
						}


func _add_fish_to_waters(_width: int, _height: int, world_data: Dictionary):
	"""Add fish tiles to ocean and bay waters for food productivity"""
	var fish_spawn_chance = 0.15  # 15% chance of fish on ocean tiles
	
	for coords in world_data:
		if world_data[coords]["atlas_coords"] == OCEAN_COORDS:
			# Add fish to some ocean tiles, especially in bays
			if _rng.randf() < fish_spawn_chance:
				world_data[coords] = {
					"source_id": SOURCE_ID,
					"atlas_coords": FISH_COORDS
				}
>>>>>>> 2aeb49ef4a2144d1f1dda9b7f0a82b9074dac175

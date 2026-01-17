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

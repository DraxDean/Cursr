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

# Mountain range/chain generation (replaces the old round patches above)
const MOUNTAIN_RANGE_DEFAULT_COUNT = 3       # 0-6, slider-controlled in the wizard
const MOUNTAIN_RANGE_MIN_SEGMENTS = 4         # Chain length at range_size = 0
const MOUNTAIN_RANGE_MAX_SEGMENTS = 14        # Chain length at range_size = 1
const MOUNTAIN_RANGE_MIN_RADIUS = 3.0         # Segment half-width at range_size = 0
const MOUNTAIN_RANGE_MAX_RADIUS = 8.0         # Segment half-width at range_size = 1

const NUM_FOREST_PATCHES = 3
const FOREST_PATCH_RADIUS_MIN = 5
const FOREST_PATCH_RADIUS_MAX = 12

# Forest tendril generation (replaces the round patches above) — an Eden-growth-model-style
# random spread from a seed tile, same family of algorithm as diffusion-limited aggregation's
# branching "Brownian trees", which is what gives real tree-cover its fingered, non-circular
# edges (following watersheds/disturbance patterns) rather than a uniform disc.
const FOREST_CLUSTER_MIN_TILES = 40    # Cluster tile budget at forest_size = 0
const FOREST_CLUSTER_MAX_TILES = 380   # Cluster tile budget at forest_size = 1
const FOREST_SELECTION_EPSILON = 0.05  # Keeps every boundary candidate pickable, never fully zero weight

const NUM_DESERT_PATCHES = 3
const DESERT_PATCH_RADIUS_MIN = 5
const DESERT_PATCH_RADIUS_MAX = 11

const ICE_CAP_HEIGHT = 4 # How many rows from top/bottom are ice
const NUM_FISH = 60  # Target number of fish to spawn

# --- Private Variables ---
# Moved rng here so helper methods can access it without passing it everywhere
var _rng = RandomNumberGenerator.new()


# --- Main Generation Function ---

func generate_world_data(map_width: int, map_height: int) -> Dictionary:
	DebugConfig.dprint("world_gen", ["--- Starting World Generation ---"])
	var world_data: Dictionary = {}
	_rng.randomize() # Initialize RNG

	# 1. Fill with base ocean
	_generate_base_ocean(map_width, map_height, world_data)
	DebugConfig.dprint("world_gen", ["Base ocean generated."])

	# 2. Generate the Pangaea continent
	_generate_continent(map_width, map_height, world_data)
	DebugConfig.dprint("world_gen", ["Continent generated."])

	# 3. Add biome patches onto the landmass
	_add_biome_patches(map_width, map_height, world_data)
	DebugConfig.dprint("world_gen", ["Biomes added."])

	# Ice caps disabled for now (see _add_ice_caps) — left in place in case they come back.

	DebugConfig.dprint("world_gen", ["--- World Generation Finished ---"])
	return world_data


# --- Generation Step Functions ---

func _generate_base_ocean(width: int, height: int, world_data: Dictionary):
	for x in range(width):
		for y in range(height):
			world_data[Vector2i(x, y)] = {
				"source_id": SOURCE_ID,
				"atlas_coords": OCEAN_COORDS
			}

func _generate_continent(width: int, height: int, world_data: Dictionary, landmass: float = 0.5, coast_noise: float = 0.5):
	# landmass in [0,1]: 0.5 preserves the original fixed radius (multiplier 1.0); 0 = tiny
	# island, 1 = near-full-map continent.
	var landmass_multiplier: float = 0.4 + landmass * 1.2
	# coast_noise in [0,1]: 0.5 reproduces the original ±0.3 per-tile jitter; 0 = smooth
	# circular coastline, 1 = very jagged/scattered.
	var noise_amplitude: float = coast_noise * 0.6

	var center = Vector2(width / 2.0, height / 2.0)
	var max_radius = (min(center.x, center.y) - BORDER_SIZE) * landmass_multiplier

	if max_radius <= 0:
		push_warning("Map too small for border and continent.")
		return

	for x in range(width):
		for y in range(height):
			var current_pos = Vector2(x, y)
			var dist_to_center = current_pos.distance_to(center)
			var noise_factor = _rng.randf_range(1.0 - noise_amplitude, 1.0 + noise_amplitude)

			if dist_to_center < max_radius * noise_factor :
				if x >= BORDER_SIZE and x < width - BORDER_SIZE and \
				   y >= BORDER_SIZE and y < height - BORDER_SIZE:
					world_data[Vector2i(x, y)] = {
						"source_id": SOURCE_ID,
						"atlas_coords": DESERT_COORDS
					}


func _add_biome_patches(width: int, height: int, world_data: Dictionary):
	# Mountains are generated as winding chains/ranges rather than round patches — see
	# _generate_mountain_ranges.
	DebugConfig.dprint("world_gen", ["Adding Mountains..."])
	_generate_mountain_ranges(width, height, world_data)
	DebugConfig.dprint("world_gen", ["Adding Forests..."])
	_generate_forest_clusters(width, height, world_data)
	DebugConfig.dprint("world_gen", ["Adding Deserts..."])
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

# Mountain ranges: each range is a winding chain of overlapping elliptical "stamps" walked
# across the landmass, tapering thin at both ends and wide in the middle — reads as a real
# ridge/chain instead of a round blob. See _stamp_mountain_ellipse for the peak-sharpness shaping.
func _generate_mountain_ranges(width: int, height: int, world_data: Dictionary,
		num_ranges: int = MOUNTAIN_RANGE_DEFAULT_COUNT, range_size: float = 0.5, peak_sharpness: float = 0.5) -> void:
	for i in range(num_ranges):
		_generate_single_mountain_range(width, height, world_data, range_size, peak_sharpness)

func _generate_single_mountain_range(width: int, height: int, world_data: Dictionary, range_size: float, peak_sharpness: float) -> void:
	var start = _pick_random_land_tile(width, height, world_data)
	if start == null:
		return  # No land generated yet — nothing to place a range on
	var num_segments: int = int(round(lerp(float(MOUNTAIN_RANGE_MIN_SEGMENTS), float(MOUNTAIN_RANGE_MAX_SEGMENTS), range_size)))
	var base_radius: float = lerp(MOUNTAIN_RANGE_MIN_RADIUS, MOUNTAIN_RANGE_MAX_RADIUS, range_size)
	var angle: float = _rng.randf_range(0.0, TAU)
	var pos := Vector2(start.x, start.y)
	for i in range(num_segments):
		# Bell-curve taper: thin at both ends of the chain, thick through the middle.
		var t: float = float(i) / float(max(num_segments - 1, 1))
		var taper: float = sin(t * PI)
		var seg_radius: float = base_radius * lerp(0.35, 1.0, taper)
		_stamp_mountain_ellipse(world_data, pos, seg_radius, angle, peak_sharpness, width, height)
		# Gentle winding rather than a straight line, so the chain looks natural.
		angle += _rng.randf_range(-0.35, 0.35)
		pos += Vector2(cos(angle), sin(angle)) * seg_radius * 0.9

# Stamps one elliptical "link" of a mountain chain. peak_sharpness 0 = circular (round patch,
# same as the old behavior); 1 = a stretched "eye" shape elongated along the chain direction.
func _stamp_mountain_ellipse(world_data: Dictionary, center: Vector2, radius: float, angle: float, peak_sharpness: float, width: int, height: int) -> void:
	var major: float = radius * lerp(1.0, 2.2, peak_sharpness)   # along the chain direction
	var minor: float = radius * lerp(1.0, 0.55, peak_sharpness)  # across the chain
	var cos_a: float = cos(-angle)
	var sin_a: float = sin(-angle)
	var bound: int = int(ceil(max(major, minor))) + 1
	var cx: int = int(round(center.x))
	var cy: int = int(round(center.y))
	for x in range(max(cx - bound, BORDER_SIZE), min(cx + bound + 1, width - BORDER_SIZE)):
		for y in range(max(cy - bound, BORDER_SIZE), min(cy + bound + 1, height - BORDER_SIZE)):
			var dx: float = float(x) - center.x
			var dy: float = float(y) - center.y
			# Rotate into the ellipse's local frame so it's aligned with the chain direction.
			var rx: float = dx * cos_a - dy * sin_a
			var ry: float = dx * sin_a + dy * cos_a
			if (rx * rx) / (major * major) + (ry * ry) / (minor * minor) <= 1.0:
				var coords := Vector2i(x, y)
				if world_data.has(coords) and world_data[coords]["atlas_coords"] == DESERT_COORDS:
					world_data[coords] = {
						"source_id": SOURCE_ID,
						"atlas_coords": MOUNTAIN_COORDS
					}

func _pick_random_land_tile(width: int, height: int, world_data: Dictionary):
	return _pick_random_tile_of_types(width, height, world_data, [DESERT_COORDS])

func _pick_random_tile_of_types(width: int, height: int, world_data: Dictionary, allowed_types: Array):
	var candidates: Array[Vector2i] = []
	for x in range(BORDER_SIZE, width - BORDER_SIZE):
		for y in range(BORDER_SIZE, height - BORDER_SIZE):
			var coords := Vector2i(x, y)
			if world_data.has(coords) and allowed_types.has(world_data[coords]["atlas_coords"]):
				candidates.append(coords)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

# Forest clusters: grows a cluster by always converting boundary (edge-adjacent) tiles until
# it reaches its target size — unlike the old version, growth here never probabilistically
# dies out early, since "how many tiles" (forest_size) and "what shape" (tendril_spread) are
# fully decoupled. tendril_spread instead biases WHICH boundary tile gets picked each step:
# tiles with few already-forest neighbors extend the cluster outward into thin fingers, tiles
# with many neighbors fill it in as a compact blob. Finishes with a hole-filling pass so any
# pocket of land fully enclosed by forest (from multiple tendrils looping back on themselves)
# gets absorbed into the forest too.
func _generate_forest_clusters(width: int, height: int, world_data: Dictionary,
		forest_size: float = 0.5, tendril_spread: float = 0.5) -> void:
	for i in range(NUM_FOREST_PATCHES):
		_generate_single_forest_cluster(width, height, world_data, forest_size, tendril_spread)
	_fill_enclosed_forest_holes(width, height, world_data)

func _generate_single_forest_cluster(width: int, height: int, world_data: Dictionary, forest_size: float, tendril_spread: float) -> void:
	# Forests only take root on open land now — mountains are solid and never get eaten into
	# by tendril growth or the hole-filler (previously they could, which visibly ate away at
	# mountain terrain once forest clusters got big enough to reliably reach their target size).
	var start = _pick_random_tile_of_types(width, height, world_data, [DESERT_COORDS])
	if start == null:
		return
	var target_count: int = int(round(lerp(float(FOREST_CLUSTER_MIN_TILES), float(FOREST_CLUSTER_MAX_TILES), forest_size)))
	var neighbor_offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	var forest_tiles: Dictionary = {}   # tiles already converted to forest by this cluster
	var boundary: Dictionary = {}       # eligible land tiles adjacent to the cluster, not yet converted
	var placed: int = 0

	if world_data[start]["atlas_coords"] != FOREST_COORDS:
		world_data[start] = {"source_id": SOURCE_ID, "atlas_coords": FOREST_COORDS}
		placed += 1
	forest_tiles[start] = true
	_add_forest_boundary_neighbors(start, world_data, forest_tiles, boundary, neighbor_offsets, width, height)

	while placed < target_count and not boundary.is_empty():
		var candidate: Vector2i = _pick_forest_boundary_candidate(boundary, forest_tiles, neighbor_offsets, tendril_spread)
		boundary.erase(candidate)
		if not world_data.has(candidate):
			continue
		var tile = world_data[candidate]["atlas_coords"]
		if tile != DESERT_COORDS:
			continue  # Something else claimed this tile since it was queued (e.g. another cluster)
		world_data[candidate] = {"source_id": SOURCE_ID, "atlas_coords": FOREST_COORDS}
		forest_tiles[candidate] = true
		placed += 1
		_add_forest_boundary_neighbors(candidate, world_data, forest_tiles, boundary, neighbor_offsets, width, height)

func _add_forest_boundary_neighbors(coords: Vector2i, world_data: Dictionary, forest_tiles: Dictionary,
		boundary: Dictionary, neighbor_offsets: Array, width: int, height: int) -> void:
	for off in neighbor_offsets:
		var n: Vector2i = coords + off
		if forest_tiles.has(n) or boundary.has(n):
			continue
		if n.x < BORDER_SIZE or n.x >= width - BORDER_SIZE or n.y < BORDER_SIZE or n.y >= height - BORDER_SIZE:
			continue
		if not world_data.has(n):
			continue
		var tile = world_data[n]["atlas_coords"]
		if tile != DESERT_COORDS:
			continue
		boundary[n] = true

func _count_forest_neighbors(coords: Vector2i, forest_tiles: Dictionary, neighbor_offsets: Array) -> int:
	var count: int = 0
	for off in neighbor_offsets:
		if forest_tiles.has(coords + off):
			count += 1
	return count

func _pick_forest_boundary_candidate(boundary: Dictionary, forest_tiles: Dictionary, neighbor_offsets: Array, tendril_spread: float) -> Vector2i:
	"""Weighted pick from the boundary: tendril_spread=0 favors tiles with MANY forest
	neighbors (fills in as a thick, compact blob); tendril_spread=1 favors tiles with FEW
	forest neighbors (keeps extending outward as thin, branching fingers)."""
	var keys = boundary.keys()
	if keys.size() == 1:
		return keys[0]
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for k in keys:
		var forest_neighbor_count: int = _count_forest_neighbors(k, forest_tiles, neighbor_offsets)
		var fill_weight: float = float(forest_neighbor_count)
		var extension_weight: float = 1.0 / float(forest_neighbor_count)
		var w: float = lerp(fill_weight, extension_weight, tendril_spread) + FOREST_SELECTION_EPSILON
		weights.append(w)
		total_weight += w
	var roll: float = _rng.randf() * total_weight
	var acc: float = 0.0
	for i in range(keys.size()):
		acc += weights[i]
		if roll <= acc:
			return keys[i]
	return keys[keys.size() - 1]

func _fill_enclosed_forest_holes(width: int, height: int, world_data: Dictionary) -> void:
	"""Any non-forest land tile that's fully enclosed by forest — unreachable from the map
	edge or open ocean without crossing a forest tile — is a 'hole' left behind by tendrils
	looping back on themselves (or two clusters meeting). Flood-fill inward from the outside
	and fill in whatever it never reaches."""
	var neighbor_offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var reachable: Dictionary = {}
	var queue: Array = []

	# Seed from every non-forest tile along the map border, plus every ocean tile anywhere —
	# both count as "outside" the forest for enclosure purposes.
	for x in range(width):
		for y in range(height):
			var coords := Vector2i(x, y)
			if not world_data.has(coords):
				continue
			var atlas = world_data[coords]["atlas_coords"]
			if atlas == FOREST_COORDS:
				continue
			var is_border_tile: bool = x == 0 or y == 0 or x == width - 1 or y == height - 1
			if (is_border_tile or atlas == OCEAN_COORDS) and not reachable.has(coords):
				reachable[coords] = true
				queue.append(coords)

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]; head += 1
		for off in neighbor_offsets:
			var n: Vector2i = current + off
			if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height:
				continue
			if reachable.has(n) or not world_data.has(n):
				continue
			if world_data[n]["atlas_coords"] == FOREST_COORDS:
				continue  # Forest blocks the flood — can't pass through
			reachable[n] = true
			queue.append(n)

	# Anything never reached is land sealed off by forest on every side — absorb it.
	for coords in world_data.keys():
		var tile_info = world_data[coords]
		if typeof(tile_info) != TYPE_DICTIONARY:
			continue
		var atlas = tile_info["atlas_coords"]
		if atlas == FOREST_COORDS or atlas == OCEAN_COORDS or atlas == ICE_COORDS or atlas == MOUNTAIN_COORDS:
			continue
		if not reachable.has(coords):
			world_data[coords] = {"source_id": SOURCE_ID, "atlas_coords": FOREST_COORDS}

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
	
	DebugConfig.dprint("world_gen", ["_place_fish: Placed %d fish markers in the ocean (attempts: %d)" % [fish_placed, attempts]])

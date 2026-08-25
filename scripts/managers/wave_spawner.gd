# scripts/managers/wave_spawner.gd
# Manages periodic hostile wave spawning.
# Each season (WAVE_INTERVAL days) a new enemy faction spawns a barracks on the
# land tile farthest from the human player's town centre.
extends Node

# --- Config ---
const WAVE_INTERVAL: int = 28        # Days between waves (one "season")
const SPAWN_CANDIDATE_POOL: int = 8  # Pick randomly from the N farthest valid tiles

# Atlas coords from world_gen — tiles we can build on
const BUILDABLE_ATLAS = [
	Vector2i(0, 5),  # DESERT_COORDS
	Vector2i(0, 6),  # GRASS_COORDS
	Vector2i(0, 4),  # FOREST_COORDS
]

# --- State ---
var game: Node   # Reference to game.gd
var wave_number: int = 0
var next_wave_day: int = WAVE_INTERVAL  # Day the next wave fires

signal wave_spawned(wave_number: int, enemy_player_id: int, tile: Vector2i)

# ------------------------------------------------------------------ setup ---

func setup(game_reference: Node):
	game = game_reference
	DebugConfig.dprint("wave", ["WaveSpawner: Ready. First wave on day %d." % next_wave_day])

# ----------------------------------------------------------------- tick ----

func on_day_end(current_day: int):
	if current_day >= next_wave_day:
		wave_number += 1
		next_wave_day += WAVE_INTERVAL
		_spawn_wave(wave_number)

# --------------------------------------------------------------- spawn -----

func _spawn_wave(wave_num: int):
	DebugConfig.dprint("wave", ["WaveSpawner: Spawning wave %d!" % wave_num])

	var enemy_player_id = 1000 + wave_num
	_register_enemy_player(enemy_player_id, wave_num)

	var spawn_tile = _find_spawn_tile()
	if spawn_tile == Vector2i(-1, -1):
		DebugConfig.dprint("wave", ["WaveSpawner: No valid spawn tile found for wave %d. Skipping." % wave_num])
		return

	_place_enemy_barracks(spawn_tile, enemy_player_id)
	wave_spawned.emit(wave_num, enemy_player_id, spawn_tile)
	DebugConfig.dprint("wave", ["WaveSpawner: Wave %d enemy (player %d) barracks placed at tile %s." % [wave_num, enemy_player_id, str(spawn_tile)]])

# --------------------------------------------------------- player setup ----

func _register_enemy_player(player_id: int, wave_num: int):
	if game.players_data.has(player_id):
		return  # Already exists (shouldn't happen, but be safe)
	game.players_data[player_id] = {
		"name": "Marauders %d" % wave_num,
		"race": "human",
		"faction": "enemy",
		"wave_number": wave_num,
		"buildings": [],
		"units": [],
		"resources": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0},
		"resource_rates": {"gold": 0, "food": 0, "wood": 0, "stone": 0, "science": 0},
		"population": {
			"total": 0, "housed": 0, "working": 0,
			"unhoused": 0, "unemployed": 0, "growth_accumulator": 0.0
		},
		"technologies": {
			"work_ethic": 0, "fishing_bonus": 0,
			"woodcutting_bonus": 0, "stoneworking_bonus": 0
		}
	}
	DebugConfig.dprint("wave", ["WaveSpawner: Registered enemy player %d (%s)." % [player_id, game.players_data[player_id]["name"]]])

# ---------------------------------------------------------- tile search ----

func _find_spawn_tile() -> Vector2i:
	"""Return a land tile far from player 1's town centre, or (-1,-1) if none found.
	   Uses a fast sparse sample rather than a full 100×100 scan."""
	var town_centre_world = game.players_data.get(1, {}).get("town_centre_position", Vector2.ZERO)
	var tilemap: TileMapLayer = game.tilemap_layer
	var used_rect: Rect2i = tilemap.get_used_rect()

	# Build a candidate pool by sampling the map perimeter + random interior points.
	# This keeps the search fast (~500 checks) while still finding a distant tile.
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var sample: Array = []

	# Perimeter ring (every 4th tile on each edge)
	var step := 4
	for x in range(used_rect.position.x, used_rect.end.x, step):
		sample.append(Vector2i(x, used_rect.position.y))
		sample.append(Vector2i(x, used_rect.end.y - 1))
	for y in range(used_rect.position.y, used_rect.end.y, step):
		sample.append(Vector2i(used_rect.position.x, y))
		sample.append(Vector2i(used_rect.end.x - 1, y))

	# Random interior sample (200 random tiles)
	for _i in range(200):
		sample.append(Vector2i(
			rng.randi_range(used_rect.position.x, used_rect.end.x - 1),
			rng.randi_range(used_rect.position.y, used_rect.end.y - 1)
		))

	# Score valid candidates
	var candidates: Array = []
	for tile_coords in sample:
		if not _is_buildable_land(tile_coords):
			continue
		if _tile_occupied(tile_coords):
			continue
		var world_pos: Vector2 = tilemap.map_to_local(tile_coords)
		var dist: float = world_pos.distance_to(town_centre_world)
		candidates.append({"tile": tile_coords, "dist": dist})

	if candidates.is_empty():
		return Vector2i(-1, -1)

	# Sort descending by distance, pick from top N
	candidates.sort_custom(func(a, b): return a["dist"] > b["dist"])
	var pool_size = mini(SPAWN_CANDIDATE_POOL, candidates.size())
	return candidates[rng.randi_range(0, pool_size - 1)]["tile"]

func _is_buildable_land(tile_coords: Vector2i) -> bool:
	"""True when the tile atlas coord is one of the buildable terrain types."""
	if not game.world_data.has(tile_coords):
		return false
	var tile_info: Dictionary = game.world_data[tile_coords]
	var atlas: Vector2i = tile_info.get("atlas_coords", Vector2i(-1, -1))
	return atlas in BUILDABLE_ATLAS

func _tile_occupied(tile_coords: Vector2i) -> bool:
	"""True if a building or environment object is already on this tile."""
	if not game.map_objects_holder:
		return false
	for child in game.map_objects_holder.get_children():
		var child_tile = game.tilemap_layer.local_to_map(child.position)
		if child_tile == tile_coords:
			return true
	return false

# ---------------------------------------------------------- placement -----

func _place_enemy_barracks(tile_coords: Vector2i, owner_player_id: int):
	var building_type = "barracks"
	var texture_path = "res://assets/buildings/human_barracks.png"
	if not ResourceLoader.exists(texture_path):
		push_error("WaveSpawner: Barracks texture not found at %s" % texture_path)
		return

	var building_id = game._get_next_building_id(building_type)
	var building_name = building_type + str(building_id)

	var building_scene = preload("res://scenes/objects/building.tscn").instantiate()
	building_scene.name = building_name

	var world_pos: Vector2 = game.tilemap_layer.map_to_local(tile_coords)
	building_scene.position = world_pos
	building_scene.z_index = 5

	var setup_data = {
		"type": building_type,
		"texture_path": texture_path,
		"owner_player": owner_player_id,
		"building_type": building_type,
		"construction_day": game.turn_manager.get_day(),
		"living_occupancy": 0,
		"worker_occupancy": 0,
		"station_occupancy": 0,
		"training_occupancy": 0,
	}
	if building_scene.has_method("setup"):
		building_scene.setup(setup_data)

	building_scene.set_meta("living_occupancy", 0)
	building_scene.set_meta("worker_occupancy", 0)
	building_scene.set_meta("station_occupancy", 0)
	building_scene.set_meta("training_occupancy", 0)
	building_scene.set_meta("resource_jobs", [])

	game.map_objects_holder.add_child(building_scene)

	# Register in the enemy player's buildings list
	if game.players_data.has(owner_player_id):
		game.players_data[owner_player_id]["buildings"].append(building_name)

	DebugConfig.dprint("wave", ["WaveSpawner: Placed %s ('%s') for player %d at world %s." % [building_type, building_name, owner_player_id, str(world_pos)]])

# scripts/managers/wave_spawner.gd
# Manages periodic hostile wave spawning.
# Each season (WAVE_INTERVAL days) a new enemy faction spawns a barracks on the
# land tile farthest from the human player's town centre.
extends Node

# --- Config ---
const WAVE_INTERVAL: int = 28        # Days between waves (one "season")
const SPAWN_CANDIDATE_POOL: int = 8  # Pick randomly from the N farthest valid tiles
const ATTACK_INTERVAL: int = 10      # Days between marauder raids on player buildings

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
	_process_marauder_attacks(current_day)

# --------------------------------------------------------------- spawn -----

func _spawn_wave(wave_num: int):
	DebugConfig.dprint("wave", ["WaveSpawner: Spawning wave %d!" % wave_num])

	var enemy_player_id = 1000 + wave_num
	_register_enemy_player(enemy_player_id, wave_num)

	var spawn_tile = _find_spawn_tile()
	if spawn_tile == Vector2i(-1, -1):
		DebugConfig.dprint("wave", ["WaveSpawner: No valid spawn tile found for wave %d. Skipping." % wave_num])
		return

	var barracks_node = _place_enemy_barracks(spawn_tile, enemy_player_id)
	if is_instance_valid(barracks_node):
		_spawn_marauder_units(barracks_node, enemy_player_id, 5)
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

func _place_enemy_barracks(tile_coords: Vector2i, owner_player_id: int) -> Node2D:
	var building_type = "barracks"
	var texture_path = "res://assets/buildings/human_barracks.png"
	if not ResourceLoader.exists(texture_path):
		push_error("WaveSpawner: Barracks texture not found at %s" % texture_path)
		return null

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

	# Schedule this camp's first raid on a player building
	building_scene.set_meta("next_attack_day", game.turn_manager.get_day() + ATTACK_INTERVAL)

	# Register in the enemy player's buildings list
	if game.players_data.has(owner_player_id):
		game.players_data[owner_player_id]["buildings"].append(building_name)

	DebugConfig.dprint("wave", ["WaveSpawner: Placed %s ('%s') for player %d at world %s." % [building_type, building_name, owner_player_id, str(world_pos)]])
	return building_scene

# -------------------------------------------------------- unit spawning ----

func _spawn_marauder_units(barracks_node: Node2D, owner_player_id: int, count: int) -> void:
	"""Spawn `count` marauder units at the camp. They live under the marauder player's
	data only (never player 1's unit list) and idle-wander around their barracks."""
	if not game.players_data.has(owner_player_id):
		return
	var barracks_name: String = barracks_node.name
	for _i in range(count):
		var uid: String = game._get_next_unit_id()
		var scatter_angle: float = randf() * TAU
		var scatter_dist: float = randf_range(20.0, 60.0)
		var spawn_pos: Vector2 = barracks_node.position + Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_dist
		var unit_data: Dictionary = {
			"unique_id": uid,
			"name": game._generate_random_name("human", "male"),
			"type": "marauder",
			"race": "human",
			"gender": "male",
			"player_id": owner_player_id,
			"position": spawn_pos,
			"living_quarters": null,
			"job": barracks_name,  # Anchors idle-wander to the barracks (their "town centre")
			"assigned_job_index": -1,
			"previous_job": null,
			"job_connections": [],
			"current_path": [],
			"path_index": 0,
			"movement_state": "idle_wander",
			"movement_target": null,
			"movement_cycle_step": 0,
			"work_timer": randf_range(0.0, 3.0),
			"wander_wait_time": randf_range(1.0, 4.0),
			"movement_speed": 25.0,
			"speed_multiplier": randf_range(0.85, 1.15),
			"sprite_id": uid,
			"specialties": [],
			"training": null
		}
		game.players_data[owner_player_id]["units"].append(unit_data)
		game._spawn_event_unit_sprite(unit_data)
	DebugConfig.dprint("wave", ["WaveSpawner: Spawned %d marauder units for player %d at barracks '%s'." % [count, owner_player_id, barracks_name]])

# --------------------------------------------------------- raid attacks ----

func _process_marauder_attacks(current_day: int) -> void:
	"""Check every enemy barracks and raid a player building once its timer is up."""
	if not is_instance_valid(game.map_objects_holder):
		return
	for child in game.map_objects_holder.get_children():
		if not game._is_building_node(child):
			continue
		if child.get_meta("building_type", "") != "barracks":
			continue
		var owner_player = child.get_meta("owner_player", 1)
		if not game.players_data.has(owner_player):
			continue
		if game.players_data[owner_player].get("faction", "") != "enemy":
			continue
		var next_attack_day: int = get_or_init_attack_day(child)
		if current_day < next_attack_day:
			continue
		_launch_attack(child, current_day)
		child.set_meta("next_attack_day", current_day + ATTACK_INTERVAL)

# ------------------------------------------------------------------ misc ---

func get_or_init_attack_day(barracks_node: Node2D) -> int:
	"""Read a camp's next raid day, backfilling it for camps that predate this
	timer (e.g. loaded saves) instead of leaving them stuck forever."""
	var next_attack_day: int = barracks_node.get_meta("next_attack_day", -1)
	if next_attack_day < 0:
		next_attack_day = game.turn_manager.get_day() + ATTACK_INTERVAL
		barracks_node.set_meta("next_attack_day", next_attack_day)
	return next_attack_day

func _find_nearest_target_building(barracks_node: Node2D) -> Node2D:
	"""Find the nearest player-1 building that isn't a town centre."""
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for child in game.map_objects_holder.get_children():
		if not game._is_building_node(child):
			continue
		if child.get_meta("owner_player", 1) != 1:
			continue  # Only raid the human player's buildings
		if child.get_meta("building_type", "") == "town_center":
			continue  # Town centre is protected
		var dist: float = barracks_node.position.distance_to(child.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = child
	return nearest

func _launch_attack(barracks_node: Node2D, current_day: int) -> void:
	"""Raid the nearest player building: destroy it and kill every unit working there."""
	var target: Node2D = _find_nearest_target_building(barracks_node)
	if not is_instance_valid(target):
		return  # Nothing left to raid but the town centre

	var building_name: String = target.name
	var building_type: String = target.get_meta("building_type", "unknown")
	var target_owner: int = target.get_meta("owner_player", 1)
	var target_pos: Vector2 = target.position

	var killed_count: int = 0
	if game.players_data.has(target_owner):
		var player_units: Array = game.players_data[target_owner].get("units", [])
		var survivors: Array = []
		for unit in player_units:
			var job: String = unit.get("job", "") if unit.get("job", null) != null else ""
			var works_here: bool = job == building_name or job.begins_with(building_name + "_")
			if works_here:
				killed_count += 1
				var uid: String = unit.get("unique_id", "")
				if uid != "" and is_instance_valid(game.map_objects_holder):
					var sprite = game.map_objects_holder.get_node_or_null(uid)
					if is_instance_valid(sprite):
						sprite.queue_free()
				game.unit_sprite_map.erase(uid)
			else:
				# Building's gone — clear the reference for anyone who merely lived there
				if unit.get("living_quarters", null) == building_name:
					unit["living_quarters"] = null
				survivors.append(unit)
		game.players_data[target_owner]["units"] = survivors

	game.remove_building_from_player(building_name, target_owner)
	target.queue_free()

	if game.players_data.has(target_owner):
		game.update_player_population(target_owner)
	if is_instance_valid(game.resource_bar):
		game.resource_bar.refresh()

	var type_label: String = building_type.capitalize().replace("_", " ")
	var body: String
	if killed_count > 0:
		body = "The %s was razed. %d %s lost." % [type_label, killed_count, "unit was" if killed_count == 1 else "units were"]
	else:
		body = "The %s was razed to the ground." % type_label

	if is_instance_valid(game.game_log):
		var GL = preload("res://scripts/managers/game_log.gd")
		game.game_log.add(current_day, GL.Category.COMBAT, "⚔ Marauders raided and destroyed %s! %s" % [building_name, body])

	if is_instance_valid(game.turn_event_manager):
		game.turn_event_manager.push_event("Marauders Raid!", body, "🔥")

	if is_instance_valid(game.notification_panel):
		game.notification_panel.push(
			"Marauders Raid!",
			body,
			"🔥",
			Color(0.85, 0.18, 0.10),
			{"action": "pan_to", "world_pos": target_pos}
		)

	DebugConfig.dprint("wave", ["WaveSpawner: Marauders razed %s (%s), killing %d units." % [building_name, building_type, killed_count]])

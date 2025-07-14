extends Node

var ui_manager
var map_manager
@onready var camera = $Camera2D  # Adjust path as needed
@onready var tilemap_layer = $TileMapLayer  # Adjust path as needed

# Camera movement variables
var camera_speed = 300.0  # Adjust this value to change camera speed
var camera_zoom_speed = 0.1
var min_zoom = 0.5
var max_zoom = 3.0

func _ready():
	print("Game Start")
	
	# Create map manager - try scene instantiation first
	# If map_manager is a scene file, use this:
	# map_manager = preload("res://Scenes/MapManager.tscn").instantiate()
	# If it's just a script, use this:
	map_manager = preload("res://Scripts/map_manager.gd").new()
	add_child(map_manager)
	
	# Create UI manager
	ui_manager = preload("res://Scenes/UI.tscn").instantiate()
	add_child(ui_manager)
	
	# Setup references
	setup_managers()
	
	start_game()

func setup_managers():
	# Make sure tilemap_layer is valid before passing it
	if tilemap_layer:
		map_manager.setup(tilemap_layer)
	else:
		print("Warning: tilemap_layer is null!")
	
	if ui_manager:
		ui_manager.setup(map_manager)
	else:
		print("Warning: ui_manager is null!")

func start_game():
	print("Start Game...")
	map_manager.test_create_full_map()

func _process(delta):
	handle_camera_movement(delta)

func handle_camera_movement(delta):
	if not camera:
		return
	
	var movement = Vector2.ZERO
	
	# WASD movement
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		movement.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		movement.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		movement.y += 1
	
	# Normalize diagonal movement
	if movement.length() > 0:
		movement = movement.normalized()
		
		# Adjust speed based on zoom level (move faster when zoomed out)
		var zoom_factor = 1.0 / camera.zoom.x
		camera.position += movement * camera_speed * zoom_factor * delta

func _input(event):
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_mouse_click(event.global_position)
		
		# Handle zoom with mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(1.0 + camera_zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1.0 - camera_zoom_speed)
	
	# Handle keyboard zoom (optional)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			zoom_camera(1.0 + camera_zoom_speed)
		elif event.keycode == KEY_MINUS:
			zoom_camera(1.0 - camera_zoom_speed)

func zoom_camera(zoom_factor: float):
	if not camera:
		return
	
	var new_zoom = camera.zoom * zoom_factor
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	camera.zoom = new_zoom

func handle_mouse_click(screen_pos: Vector2):
	# Convert screen position to world position
	var world_pos = screen_pos
	
	# If using a camera, convert from screen to world coordinates
	if camera:
		world_pos = camera.get_global_mouse_position()
	
	# Convert world position to hex tile coordinates
	var tile_coords = world_to_hex_tile(world_pos)
	
	# Debug: Check what's actually at this position in the tilemap
	var tile_data = tilemap_layer.get_cell_tile_data(tile_coords)
	var source_id = tilemap_layer.get_cell_source_id(tile_coords)
	var atlas_coords = tilemap_layer.get_cell_atlas_coords(tile_coords)
	
	print("Screen pos: ", screen_pos)
	print("World pos: ", world_pos)
	print("Calculated tile coords: ", tile_coords)
	print("Tile data exists: ", tile_data != null)
	print("Source ID: ", source_id)
	print("Atlas coords: ", atlas_coords)
	
	# Try nearby coordinates to see if there's an offset issue
	print("Checking nearby tiles:")
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var check_coords = Vector2i(tile_coords.x + x_offset, tile_coords.y + y_offset)
			var check_source = tilemap_layer.get_cell_source_id(check_coords)
			if check_source != -1:
				print("  Found tile at offset (", x_offset, ",", y_offset, "): ", check_coords)
	
	# Let the map manager handle the click with tile coordinates
	map_manager.handle_tile_click(tile_coords)
	
	print("Game received click at hex tile: ", tile_coords)

func world_to_hex_tile(world_pos: Vector2) -> Vector2i:
	# Use the tilemap's built-in conversion directly
	# This should properly handle hexagonal tile layouts
	var tile_coords = tilemap_layer.local_to_map(tilemap_layer.to_local(world_pos))
	
	return tile_coords

# Alternative direct approach - try this if the above doesn't work
func handle_mouse_click_direct(screen_pos: Vector2):
	# Get mouse position in world coordinates
	var world_pos = camera.get_global_mouse_position() if camera else screen_pos
	
	# Try different coordinate conversion methods
	var tile_coords1 = tilemap_layer.local_to_map(tilemap_layer.to_local(world_pos))
	var tile_coords2 = tilemap_layer.local_to_map(world_pos)
	
	print("Method 1 coords: ", tile_coords1)
	print("Method 2 coords: ", tile_coords2)
	
	# Check both coordinate results
	var source1 = tilemap_layer.get_cell_source_id(tile_coords1)
	var source2 = tilemap_layer.get_cell_source_id(tile_coords2)
	
	print("Method 1 has tile: ", source1 != -1)
	print("Method 2 has tile: ", source2 != -1)
	
	# Use whichever method finds a tile
	var final_coords = tile_coords1
	if source1 == -1 and source2 != -1:
		final_coords = tile_coords2
	
	# Let the map manager handle the click
	map_manager.handle_tile_click(final_coords)

func hex_round(hex: Vector2) -> Vector2i:
	# Convert to cube coordinates for rounding
	var q = hex.x
	var r = hex.y
	var s = -q - r
	
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	
	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)
	
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	else:
		rs = -rq - rr
	
	return Vector2i(int(rq), int(rr))

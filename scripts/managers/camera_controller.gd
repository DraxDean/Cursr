# scripts/managers/camera_controller.gd
extends Node

# Tunables
var scroll_speed: float = 300.0
var zoom_factor: float = 1.1
var min_zoom: float = 0.3
var max_zoom: float = 2.5
var trackpad_scroll_zoom_sensitivity: float = 0.05

# References (set via setup)
var camera_node: Camera2D
var map_pixel_width: int = 0
var map_pixel_height: int = 0

# World creation mode
var world_creation_mode: bool = false
var tile_selection_mode: bool = false
signal tile_clicked(tile_pos: Vector2)
signal camera_moved()  # Emitted when camera position or zoom changes

# State
var is_left_dragging: bool = false
var drag_start_mouse_pos: Vector2
var drag_start_camera_pos: Vector2


func setup(_camera: Camera2D, _map_width: int, _map_height: int):
	camera_node = _camera
	map_pixel_width = _map_width
	map_pixel_height = _map_height
	if not is_instance_valid(camera_node):
		push_error("CameraController: Invalid Camera2D node provided.")
	print("CameraController setup complete.")


func handle_input(event: InputEvent, is_paused: bool):
	if is_paused: return # Don't handle camera input if paused

	# --- Left-Click Drag Handling ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				# Check for tile selection mode first
				if tile_selection_mode:
					_handle_tile_click(event.global_position)
					get_viewport().set_input_as_handled()
					return
					
				is_left_dragging = true
				drag_start_mouse_pos = get_viewport().get_mouse_position()
				drag_start_camera_pos = camera_node.position
				get_viewport().set_input_as_handled() # Use viewport, not get_tree().get_root() here
			elif is_left_dragging:
				is_left_dragging = false
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_left_dragging:
		var mouse_delta = get_viewport().get_mouse_position() - drag_start_mouse_pos
		camera_node.position = drag_start_camera_pos - mouse_delta
		_clamp_camera()
		camera_moved.emit()  # Notify listeners of camera movement
		get_viewport().set_input_as_handled(); return # Consume event if dragging

	# --- Zoom Handling (Gestures and Wheel) ---
	if is_left_dragging: return # Don't zoom while dragging

	var zoom_changed = false
	var target_zoom = camera_node.zoom

	if event is InputEventPanGesture:
		target_zoom *= pow(zoom_factor, -event.delta.y * trackpad_scroll_zoom_sensitivity); zoom_changed = true
	elif event is InputEventMagnifyGesture:
		if event.factor != 0: target_zoom /= event.factor; zoom_changed = true
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: target_zoom /= zoom_factor; zoom_changed = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: target_zoom *= zoom_factor; zoom_changed = true

	if zoom_changed:
		target_zoom.x = clampf(target_zoom.x, min_zoom, max_zoom); target_zoom.y = clampf(target_zoom.y, min_zoom, max_zoom)
		camera_node.zoom = target_zoom
		_clamp_camera()
		camera_moved.emit()  # Notify listeners of camera zoom change
		get_viewport().set_input_as_handled()


func process_movement(delta: float, is_paused: bool):
	if is_paused or is_left_dragging: return # No key scroll if paused or dragging

	var move_direction := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): move_direction.x += 1
	if Input.is_action_pressed("ui_left"):  move_direction.x -= 1
	if Input.is_action_pressed("ui_down"):  move_direction.y += 1
	if Input.is_action_pressed("ui_up"):    move_direction.y -= 1

	if move_direction != Vector2.ZERO:
		move_direction = move_direction.normalized()
		camera_node.position += move_direction * scroll_speed * delta
		_clamp_camera()
		camera_moved.emit()  # Notify listeners of keyboard camera movement


func _clamp_camera():
	if not is_instance_valid(camera_node): return

	var viewport_rect = get_viewport().get_visible_rect()
	var camera_limits = Rect2()
	var cam_zoom = camera_node.zoom # Use local var for clarity
	var half_vp = viewport_rect.size / 2.0 / cam_zoom

	# Allow negative coordinates for more flexible camera movement
	camera_limits.position.x = -half_vp.x  # Allow scrolling into negative X
	camera_limits.position.y = -half_vp.y  # Allow scrolling into negative Y
	camera_limits.end.x = map_pixel_width + half_vp.x  # Allow scrolling past map edge
	camera_limits.end.y = map_pixel_height + half_vp.y # Allow scrolling past map edge

	var cam_pos = camera_node.position # Use local var
	cam_pos.x = clampf(cam_pos.x, camera_limits.position.x, camera_limits.end.x)
	cam_pos.y = clampf(cam_pos.y, camera_limits.position.y, camera_limits.end.y)

	# Handle map smaller than viewport - keep centered behavior for small maps
	if map_pixel_width < viewport_rect.size.x / cam_zoom.x: cam_pos.x = map_pixel_width / 2.0
	if map_pixel_height < viewport_rect.size.y / cam_zoom.y: cam_pos.y = map_pixel_height / 2.0

	camera_node.position = cam_pos # Assign back


func center_camera():
	if is_instance_valid(camera_node) and map_pixel_width > 0 and map_pixel_height > 0:
		camera_node.position = Vector2(map_pixel_width / 2.0, map_pixel_height / 2.0)
		_clamp_camera()

func pan_to(world_pos: Vector2, zoom_level: float = 2.0):
	"""Instantly pan to a world position and optionally set zoom."""
	if not is_instance_valid(camera_node):
		return
	camera_node.position = world_pos
	if zoom_level > 0:
		camera_node.zoom = Vector2(zoom_level, zoom_level)
	_clamp_camera()
	camera_moved.emit()


func reset_drag_state():
	is_left_dragging = false

func _handle_tile_click(_global_pos: Vector2):
	# Convert screen position to world position
	var world_pos = camera_node.get_global_mouse_position()
	# Convert world position to tile coordinates (assuming 64x64 tiles)
	var tile_size = 64
	var tile_x = int(world_pos.x / tile_size)
	var tile_y = int(world_pos.y / tile_size)
	var tile_pos = Vector2(tile_x, tile_y)
	
	print("Tile clicked at: ", tile_pos)
	tile_clicked.emit(tile_pos)

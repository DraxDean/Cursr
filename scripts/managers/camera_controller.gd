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


# NEW: Convert screen position to world position accounting for camera transform
func screen_to_world(screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(camera_node):
		push_error("CameraController: Invalid camera node")
		return Vector2.ZERO
	
	# Get viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Convert screen position to camera-relative position
	# Screen coordinates are from top-left, camera position is center-based
	var camera_relative_pos = (screen_pos - viewport_size / 2.0) / camera_node.zoom
	
	# Add camera position to get world position
	var world_pos = camera_node.position + camera_relative_pos
	
	return world_pos


# NEW: Get the current mouse position in world coordinates
func get_world_mouse_position() -> Vector2:
	var screen_mouse_pos = get_viewport().get_mouse_position()
	return screen_to_world(screen_mouse_pos)


# NEW: Check if a screen position click should be handled by the camera (for UI to check)
func is_handling_input() -> bool:
	return is_left_dragging


func handle_input(event: InputEvent, is_paused: bool):
	if is_paused: return # Don't handle camera input if paused

	# --- Left-Click Drag Handling ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
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
		get_viewport().set_input_as_handled(); return # Consume event if dragging

	# --- Zoom Handling (Gestures and Wheel) ---
	if is_left_dragging: return # Don't zoom while dragging

	var zoom_changed = false
	var target_zoom = camera_node.zoom

	#if event is InputEventPanGesture:
		#target_zoom *= pow(zoom_factor, -event.delta.y * trackpad_scroll_zoom_sensitivity); zoom_changed = true
	#elif event is InputEventMagnifyGesture:
		#if event.factor != 0: target_zoom /= event.factor; zoom_changed = true
	#elif event is InputEventMouseButton and event.is_pressed():
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP: target_zoom /= zoom_factor; zoom_changed = true
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: target_zoom *= zoom_factor; zoom_changed = true

	if zoom_changed:
		target_zoom.x = clampf(target_zoom.x, min_zoom, max_zoom); target_zoom.y = clampf(target_zoom.y, min_zoom, max_zoom)
		camera_node.zoom = target_zoom
		_clamp_camera()
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


func _clamp_camera():
	if not is_instance_valid(camera_node): return

	var viewport_rect = get_viewport().get_visible_rect()
	var camera_limits = Rect2()
	var cam_zoom = camera_node.zoom # Use local var for clarity
	var half_vp = viewport_rect.size / 2.0 / cam_zoom

	camera_limits.position.x = half_vp.x
	camera_limits.position.y = half_vp.y
	camera_limits.end.x = map_pixel_width - half_vp.x
	camera_limits.end.y = map_pixel_height - half_vp.y

	var cam_pos = camera_node.position # Use local var
	cam_pos.x = clampf(cam_pos.x, camera_limits.position.x, camera_limits.end.x)
	cam_pos.y = clampf(cam_pos.y, camera_limits.position.y, camera_limits.end.y)

	# Handle map smaller than viewport
	if map_pixel_width < viewport_rect.size.x / cam_zoom.x: cam_pos.x = map_pixel_width / 2.0
	if map_pixel_height < viewport_rect.size.y / cam_zoom.y: cam_pos.y = map_pixel_height / 2.0

	camera_node.position = cam_pos # Assign back


func center_camera():
	if is_instance_valid(camera_node) and map_pixel_width > 0 and map_pixel_height > 0:
		camera_node.position = Vector2(map_pixel_width / 2.0, map_pixel_height / 2.0)
		_clamp_camera()


func reset_drag_state():
	is_left_dragging = false

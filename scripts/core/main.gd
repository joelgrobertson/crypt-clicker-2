extends Node3D
## Main game controller — manages stages, camera, and global game state.

# -- Camera Settings --
const CAMERA_SPEED := 15.0
const CAMERA_ZOOM_SPEED := 2.0
const CAMERA_ZOOM_MIN := 8.0
const CAMERA_ZOOM_MAX := 25.0

# -- Node References --
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hand: Node3D = $NecromancerHand
@onready var dungeon: Node3D = $Dungeon

# -- State --
var camera_zoom := 15.0
var mouse_world_pos := Vector3.ZERO  # Where the mouse ray hits the ground plane

func _ready() -> void:
	# Lock mouse to window (we'll use custom cursor via the hand)
	# Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)  # Uncomment if desired
	
	# Set initial camera zoom
	_update_camera_zoom()
	
	print("Crypt Clicker V5 — The crypt awaits...")

func _process(delta: float) -> void:
	_handle_camera_movement(delta)
	_update_mouse_world_position()
	_update_hand_position()

func _unhandled_input(event: InputEvent) -> void:
	# Zoom with scroll wheel (Ctrl+Scroll per design doc)
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_zoom = max(camera_zoom - CAMERA_ZOOM_SPEED, CAMERA_ZOOM_MIN)
				_update_camera_zoom()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_zoom = min(camera_zoom + CAMERA_ZOOM_SPEED, CAMERA_ZOOM_MAX)
				_update_camera_zoom()

func _handle_camera_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
	
	# WASD camera pan — note these move along the GROUND plane,
	# not the camera's local axes, so "up" always means "away from camera"
	if Input.is_action_pressed("camera_up"):
		move_dir.z -= 1.0
	if Input.is_action_pressed("camera_down"):
		move_dir.z += 1.0
	if Input.is_action_pressed("camera_left"):
		move_dir.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		move_dir.x += 1.0
	
	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		camera_rig.position += move_dir * CAMERA_SPEED * delta

func _update_camera_zoom() -> void:
	# Camera is a child of CameraRig, positioned at an offset
	# Adjusting the camera's position.y and position.z controls zoom
	# For isometric: camera sits high and back, looking down at ~45 degrees
	camera.position = Vector3(0, camera_zoom, camera_zoom * 0.7)
	camera.look_at(camera_rig.global_position, Vector3.UP)

func _update_mouse_world_position() -> void:
	## Cast a ray from the mouse position to the ground plane (Y=0).
	## This tells us where in 3D world space the player is "pointing."
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	# Intersect with ground plane (Y = 0)
	# Formula: t = -origin.y / direction.y
	if ray_dir.y != 0:
		var t := -ray_origin.y / ray_dir.y
		if t > 0:
			mouse_world_pos = ray_origin + ray_dir * t

func _update_hand_position() -> void:
	## The necromancer hand follows the mouse cursor in 3D space,
	## floating slightly above the ground.
	var target := mouse_world_pos
	target.y = 1.5  # Float above the ground
	
	# Smooth follow — the hand glides toward the mouse position
	hand.global_position = hand.global_position.lerp(target, 0.15)
	
	# Rotate hand to face movement direction
	var velocity := target - hand.global_position
	if velocity.length() > 0.01:
		var angle := atan2(velocity.x, velocity.z)
		hand.rotation.y = lerp_angle(hand.rotation.y, angle, 0.1)

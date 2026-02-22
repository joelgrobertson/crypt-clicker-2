extends Node3D
## Main game controller — wires together all systems:
## Camera, Hand, Wave Spawner, Enemy damage, HUD updates.

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
@onready var wave_spawner: Node3D = $WaveSpawner
@onready var hud: Control = $HUDLayer/HUD

# -- Game State --
var camera_zoom := 15.0
var mouse_world_pos := Vector3.ZERO
var total_kills := 0
var total_xp := 0.0
var door_health := 20  # Heroes that can breach before stage is lost
var game_started := false

func _ready() -> void:
	_update_camera_zoom()
	
	# Connect hand signals to game logic
	hand.smite_hit.connect(_on_smite_hit)
	hand.entity_grabbed.connect(_on_entity_grabbed)
	hand.entity_thrown.connect(_on_entity_thrown)
	
	# Connect wave spawner signals
	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	wave_spawner.enemy_killed.connect(_on_enemy_killed)
	wave_spawner.enemy_breached.connect(_on_enemy_breached)
	
	# Start waves after a short delay so player can look around
	await get_tree().create_timer(2.0).timeout
	wave_spawner.start_waves()
	game_started = true
	
	print("Crypt Clicker V5 — Defend the crypt!")

func _process(delta: float) -> void:
	_handle_camera_movement(delta)
	_update_mouse_world_position()
	_update_hand_position()
	
	# Update HUD
	if hud and game_started:
		hud.update_display(
			wave_spawner.current_wave,
			total_kills,
			wave_spawner.global_timer,
			door_health
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_zoom = max(camera_zoom - CAMERA_ZOOM_SPEED, CAMERA_ZOOM_MIN)
				_update_camera_zoom()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_zoom = min(camera_zoom + CAMERA_ZOOM_SPEED, CAMERA_ZOOM_MAX)
				_update_camera_zoom()

# ========== CAMERA ==========

func _handle_camera_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
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
	camera.position = Vector3(0, camera_zoom, camera_zoom * 0.7)
	camera.look_at(camera_rig.global_position, Vector3.UP)

# ========== MOUSE → 3D WORLD ==========

func _update_mouse_world_position() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	if ray_dir.y != 0:
		var t := -ray_origin.y / ray_dir.y
		if t > 0:
			mouse_world_pos = ray_origin + ray_dir * t

func _update_hand_position() -> void:
	var target := mouse_world_pos
	target.y = 1.5
	hand.global_position = hand.global_position.lerp(target, 0.15)
	
	var vel := target - hand.global_position
	if vel.length() > 0.01:
		var angle := atan2(vel.x, vel.z)
		hand.rotation.y = lerp_angle(hand.rotation.y, angle, 0.1)

# ========== GAME EVENTS ==========

func _on_smite_hit(target: Node3D, damage: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)

func _on_entity_grabbed(entity: Node3D) -> void:
	if entity is Enemy:
		entity.is_grabbed = true

func _on_entity_thrown(entity: Node3D, throw_velocity: Vector3) -> void:
	if entity is Enemy and is_instance_valid(entity):
		entity.is_grabbed = false
		entity.start_thrown(throw_velocity)

func _on_wave_started(wave_number: int) -> void:
	print("=== WAVE %d ===" % wave_number)

func _on_wave_cleared(wave_number: int) -> void:
	print("Wave %d cleared!" % wave_number)

func _on_enemy_killed(xp_value: float) -> void:
	total_kills += 1
	total_xp += xp_value

func _on_enemy_breached() -> void:
	door_health -= 1
	if door_health <= 0:
		print("THE DOOR HAS FALLEN! Retreating deeper...")
		# TODO: Stage transition
		door_health = 20

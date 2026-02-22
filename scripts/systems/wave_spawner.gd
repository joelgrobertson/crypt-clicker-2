extends Node3D
## Spawns waves of enemies that march toward the stage door.
## Difficulty scales with a global timer (Risk of Rain mechanic).
class_name WaveSpawner

# -- Wave Config --
@export var enemies_per_wave := 4
@export var wave_growth := 2          # Extra enemies added each wave
@export var spawn_interval := 0.8     # Seconds between each spawn within a wave
@export var wave_delay := 4.0         # Seconds pause between waves
@export var enemy_scene: PackedScene  # Assign in editor or set in code

# -- State --
var current_wave := 0
var enemies_alive := 0
var total_kills := 0
var global_timer := 0.0
var is_spawning := false
var is_wave_transitioning := false  # Guard against multiple wave triggers
var spawn_points: Array[Node3D] = []
var door_target := Vector3(0, 0, 8)  # Default; overridden from antechamber

# -- Signals --
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal enemy_killed(xp_value: float)
signal enemy_breached()

func _ready() -> void:
	# Auto-discover spawn points and door target from the Antechamber
	_find_stage_markers()
	
	# Load enemy scene if not assigned
	if enemy_scene == null:
		enemy_scene = load("res://scenes/entities/enemies/basic_hero.tscn")

func _process(delta: float) -> void:
	global_timer += delta

func _find_stage_markers() -> void:
	## Look for SpawnPoint and DoorTarget markers in the scene tree.
	## These are Marker3D nodes placed in the antechamber scene.
	await get_tree().process_frame  # Wait one frame for scene to be ready
	
	# Find spawn points
	for node in get_tree().get_nodes_in_group("spawn_points"):
		spawn_points.append(node)
	
	# If no spawn points found via groups, search by name
	if spawn_points.is_empty():
		var antechamber := get_tree().current_scene.get_node_or_null("Dungeon/Antechamber")
		if antechamber:
			for child in antechamber.get_children():
				if child.name.begins_with("SpawnPoint"):
					spawn_points.append(child)
				elif child.name == "DoorTarget":
					door_target = child.global_position
	
	# Fallback spawn points if nothing found
	if spawn_points.is_empty():
		print("WaveSpawner: No spawn points found, using defaults")
		var marker := Marker3D.new()
		marker.position = Vector3(0, 0, -8)
		add_child(marker)
		spawn_points.append(marker)
	
	print("WaveSpawner: Found %d spawn points, door at %s" % [spawn_points.size(), door_target])

func start_waves() -> void:
	_start_next_wave()

func _start_next_wave() -> void:
	if is_wave_transitioning:
		return
	is_wave_transitioning = true
	
	current_wave += 1
	var enemy_count := enemies_per_wave + (current_wave - 1) * wave_growth
	
	wave_started.emit(current_wave)
	is_spawning = true
	
	for i in range(enemy_count):
		if not is_spawning:
			break
		_spawn_single_enemy()
		await get_tree().create_timer(spawn_interval).timeout
	
	is_spawning = false
	is_wave_transitioning = false

func _spawn_single_enemy() -> void:
	if enemy_scene == null:
		push_warning("WaveSpawner: No enemy scene!")
		return
	
	# Pick a random spawn point
	var spawn_point: Node3D = spawn_points.pick_random()
	
	# Add randomness so they don't stack perfectly
	var offset := Vector3(
		randf_range(-1.5, 1.5),
		0,
		randf_range(-0.5, 0.5)
	)
	
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	
	# Position at spawn point
	# Note: We add to the scene tree FIRST, then set global_position
	# This is important in Godot — global_position only works when the node is in the tree
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_point.global_position + offset
	enemy.global_position.y = 0  # Make sure they're on the ground
	enemy.target_position = door_target
	
	# Scale stats with global timer (Risk of Rain mechanic)
	# +20% HP per minute, slight speed increase
	var difficulty_mult := 1.0 + (global_timer / 60.0) * 0.2
	enemy.max_health *= difficulty_mult
	enemy.health = enemy.max_health  # Reset health after scaling
	enemy.move_speed *= 1.0 + (global_timer / 120.0) * 0.1
	
	# Connect signals
	enemy.died.connect(_on_enemy_died)
	enemy.reached_door.connect(_on_enemy_reached_door)
	
	enemies_alive += 1

func _on_enemy_died(enemy: Enemy) -> void:
	enemies_alive -= 1
	total_kills += 1
	enemy_killed.emit(enemy.xp_value)
	
	# Check if wave is cleared
	if enemies_alive <= 0 and not is_spawning and not is_wave_transitioning:
		wave_cleared.emit(current_wave)
		await get_tree().create_timer(wave_delay).timeout
		_start_next_wave()

func _on_enemy_reached_door(enemy: Enemy) -> void:
	enemies_alive -= 1
	enemy_breached.emit()
	
	# Enemy disappears through the door with a quick animation
	var tween := enemy.create_tween()
	tween.tween_property(enemy, "scale", Vector3(0.1, 2.0, 0.1), 0.2)
	tween.tween_callback(enemy.queue_free)
	
	# Check if wave is cleared
	if enemies_alive <= 0 and not is_spawning and not is_wave_transitioning:
		wave_cleared.emit(current_wave)
		await get_tree().create_timer(wave_delay).timeout
		_start_next_wave()

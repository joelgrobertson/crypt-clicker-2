extends Node3D
## Spawns waves of enemies from defined spawn points.
## Controls wave pacing, enemy count scaling, and the global difficulty timer.
class_name WaveSpawner

# -- Wave Config --
@export var enemies_per_wave := 5
@export var wave_growth := 2       # Extra enemies per wave
@export var spawn_interval := 1.0  # Seconds between individual spawns
@export var wave_delay := 5.0      # Seconds between waves
@export var enemy_scene: PackedScene  # The enemy to spawn

# -- Spawn Points --
@export var spawn_points: Array[Marker3D] = []
@export var target_position := Vector3.ZERO  # Where enemies walk toward (the door)

# -- State --
var current_wave := 0
var enemies_alive := 0
var total_kills := 0
var global_timer := 0.0  # Risk of Rain style — difficulty scales with this
var is_spawning := false

# -- Signals --
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal enemy_killed(xp_value: float)

func _ready() -> void:
	# If no spawn points defined, create a default one
	if spawn_points.is_empty():
		var marker := Marker3D.new()
		marker.position = Vector3(0, 0, -15)
		add_child(marker)
		spawn_points.append(marker)

func _process(delta: float) -> void:
	global_timer += delta

func start_waves() -> void:
	_start_next_wave()

func _start_next_wave() -> void:
	current_wave += 1
	var enemy_count := enemies_per_wave + (current_wave - 1) * wave_growth
	
	wave_started.emit(current_wave)
	print("Wave %d — %d enemies incoming!" % [current_wave, enemy_count])
	
	is_spawning = true
	
	# Spawn enemies one at a time with delays
	for i in range(enemy_count):
		if not is_spawning:
			break
		_spawn_single_enemy()
		await get_tree().create_timer(spawn_interval).timeout
	
	is_spawning = false

func _spawn_single_enemy() -> void:
	if enemy_scene == null:
		push_warning("WaveSpawner: No enemy scene assigned!")
		return
	
	# Pick a random spawn point
	var spawn_point: Marker3D = spawn_points.pick_random()
	
	# Add some randomness to spawn position
	var offset := Vector3(
		randf_range(-2.0, 2.0),
		0,
		randf_range(-1.0, 1.0)
	)
	
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.global_position = spawn_point.global_position + offset
	enemy.target_position = target_position
	
	# Scale enemy stats with global timer (Risk of Rain mechanic)
	var difficulty_mult := 1.0 + (global_timer / 60.0) * 0.2  # +20% per minute
	enemy.max_health *= difficulty_mult
	enemy.move_speed *= 1.0 + (global_timer / 120.0) * 0.1  # Slight speed increase
	
	# Connect signals
	enemy.died.connect(_on_enemy_died)
	enemy.reached_door.connect(_on_enemy_reached_door)
	
	get_parent().add_child(enemy)
	enemies_alive += 1

func _on_enemy_died(enemy: Enemy) -> void:
	enemies_alive -= 1
	total_kills += 1
	enemy_killed.emit(enemy.xp_value)
	
	if enemies_alive <= 0 and not is_spawning:
		wave_cleared.emit(current_wave)
		# Brief pause then next wave
		await get_tree().create_timer(wave_delay).timeout
		_start_next_wave()

func _on_enemy_reached_door(enemy: Enemy) -> void:
	# An enemy got through! This is the "breach" mechanic
	# TODO: Reduce door health, trigger retreat when door breaks
	enemies_alive -= 1
	enemy.queue_free()
	print("A hero breached the door!")

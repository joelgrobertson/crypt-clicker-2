extends Node3D
## The Necromancer's Hand — the player's avatar and primary interaction tool.
## Handles smite (left click), grab/throw (right click), and visual feedback.

# -- Smite Settings --
const SMITE_DAMAGE := 10.0
const SMITE_RANGE := 3.0
const SMITE_COOLDOWN := 0.15

# -- Grab Settings --
const GRAB_RANGE := 2.5
const THROW_FORCE_MULTIPLIER := 20.0
const THROW_FORCE_MAX := 40.0

# -- State --
var smite_timer := 0.0
var is_holding := false  # Left click held for channel augments
var grabbed_entity: Node3D = null
var grab_mouse_history: Array[Vector2] = []  # For calculating throw velocity
var previous_mouse_pos := Vector2.ZERO

# -- Signals --
signal smite_hit(target: Node3D, damage: float)
signal entity_grabbed(entity: Node3D)
signal entity_thrown(entity: Node3D, velocity: Vector3)

func _ready() -> void:
	# The hand mesh will be a child node (CSG placeholder for now)
	pass

func _process(delta: float) -> void:
	smite_timer = max(0.0, smite_timer - delta)
	
	if grabbed_entity:
		_update_grabbed_entity()
		_track_mouse_movement()

func _unhandled_input(event: InputEvent) -> void:
	# -- Left Click: Smite --
	if event.is_action_pressed("smite"):
		is_holding = true
		_try_smite()
	elif event.is_action_released("smite"):
		is_holding = false
	
	# -- Right Click: Grab/Throw --
	if event.is_action_pressed("grab"):
		if grabbed_entity == null:
			_try_grab()
	elif event.is_action_released("grab"):
		if grabbed_entity != null:
			_throw_entity()

func _try_smite() -> void:
	if smite_timer > 0.0:
		return
	
	smite_timer = SMITE_COOLDOWN
	
	# Find nearest enemy within range
	var nearest := _find_nearest_in_group("enemies", SMITE_RANGE)
	if nearest:
		smite_hit.emit(nearest, SMITE_DAMAGE)
		_play_smite_effect(nearest.global_position)

func _try_grab() -> void:
	# Find nearest grabbable entity (enemies or friendly units)
	var nearest := _find_nearest_in_group("grabbable", GRAB_RANGE)
	if nearest:
		grabbed_entity = nearest
		grab_mouse_history.clear()
		entity_grabbed.emit(nearest)
		
		# Visual feedback: tint purple
		_set_entity_tint(nearest, Color(0.6, 0.2, 0.8))

func _throw_entity() -> void:
	if grabbed_entity == null:
		return
	
	# Calculate throw velocity from mouse movement
	var throw_vel := _calculate_throw_velocity()
	
	# Reset tint
	_set_entity_tint(grabbed_entity, Color.WHITE)
	
	entity_thrown.emit(grabbed_entity, throw_vel)
	grabbed_entity = null
	grab_mouse_history.clear()

func _update_grabbed_entity() -> void:
	## Grabbed entity follows the hand position
	if grabbed_entity and is_instance_valid(grabbed_entity):
		var target_pos := global_position
		target_pos.y = 2.0  # Lift slightly higher than hand
		grabbed_entity.global_position = grabbed_entity.global_position.lerp(target_pos, 0.3)
		
		# Spin the grabbed entity for visual flair
		grabbed_entity.rotation.y += 0.1

func _track_mouse_movement() -> void:
	var current_mouse := get_viewport().get_mouse_position()
	grab_mouse_history.append(current_mouse)
	# Keep only last 5 frames for velocity calculation
	if grab_mouse_history.size() > 5:
		grab_mouse_history.pop_front()

func _calculate_throw_velocity() -> Vector3:
	## Estimate throw direction and force from recent mouse movement.
	if grab_mouse_history.size() < 2:
		return Vector3.ZERO
	
	var recent := grab_mouse_history[-1]
	var older := grab_mouse_history[0]
	var mouse_delta := recent - older
	
	# Convert 2D mouse movement to 3D world direction
	# mouse X → world X, mouse Y → world Z (inverted because screen Y is down)
	var throw_dir := Vector3(mouse_delta.x, 0, mouse_delta.y).normalized()
	var force: Variant = clamp(mouse_delta.length() * THROW_FORCE_MULTIPLIER * 0.1, 0.0, THROW_FORCE_MAX)
	
	# Add some upward arc
	throw_dir.y = 0.3
	throw_dir = throw_dir.normalized()
	
	return throw_dir * force

func _find_nearest_in_group(group_name: String, max_range: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := max_range
	
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			var dist := global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	
	return nearest

func _play_smite_effect(_pos: Vector3) -> void:
	# TODO: Particle effect, screen shake, sound
	# For now, just a debug print
	print("SMITE!")

func _set_entity_tint(_entity: Node3D, _color: Color) -> void:
	# TODO: Set material tint on the entity's mesh
	# Will need to iterate through MeshInstance3D children
	pass

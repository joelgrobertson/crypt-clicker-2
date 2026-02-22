extends Node3D
## The Necromancer's Hand — the player's avatar and primary interaction tool.
## Left click = Smite (damage nearest enemy)
## Right click = Grab → drag → release = Throw

# -- Smite Settings --
const SMITE_DAMAGE := 10.0
const SMITE_RANGE := 4.0
const SMITE_COOLDOWN := 0.12

# -- Grab Settings --
const GRAB_RANGE := 3.5
const THROW_FORCE_MULTIPLIER := 25.0
const THROW_FORCE_MAX := 45.0

# -- State --
var smite_timer := 0.0
var is_holding := false
var grabbed_entity: Node3D = null
var grab_mouse_history: Array[Vector2] = []

# -- Signals (main.gd listens to these) --
signal smite_hit(target: Node3D, damage: float)
signal entity_grabbed(entity: Node3D)
signal entity_thrown(entity: Node3D, velocity: Vector3)

func _process(delta: float) -> void:
	smite_timer = max(0.0, smite_timer - delta)
	
	if grabbed_entity:
		if not is_instance_valid(grabbed_entity):
			grabbed_entity = null
			grab_mouse_history.clear()
			return
		_update_grabbed_entity()
		_track_mouse_movement()

func _unhandled_input(event: InputEvent) -> void:
	# -- Left Click: Smite --
	if event.is_action_pressed("smite"):
		is_holding = true
		_try_smite()
	elif event.is_action_released("smite"):
		is_holding = false
	
	# -- Right Click: Grab / Throw --
	if event.is_action_pressed("grab"):
		if grabbed_entity == null:
			_try_grab()
	elif event.is_action_released("grab"):
		if grabbed_entity != null:
			_throw_entity()

# ========== SMITE ==========

func _try_smite() -> void:
	if smite_timer > 0.0:
		return
	smite_timer = SMITE_COOLDOWN
	
	var nearest := _find_nearest_in_group("enemies", SMITE_RANGE)
	if nearest:
		smite_hit.emit(nearest, SMITE_DAMAGE)
		_play_smite_vfx(nearest.global_position)
		_hand_punch_animation()

func _play_smite_vfx(pos: Vector3) -> void:
	## Quick flash of light at the impact point
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.3)
	flash.light_energy = 8.0
	flash.omni_range = 3.0
	flash.omni_attenuation = 2.0
	flash.global_position = pos
	get_tree().current_scene.add_child(flash)
	
	# Fade out and remove
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _hand_punch_animation() -> void:
	## Quick scale punch on the hand mesh for satisfying feedback
	var mesh := get_node_or_null("HandMesh")
	if mesh:
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.05)
		tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

# ========== GRAB ==========

func _try_grab() -> void:
	var nearest := _find_nearest_in_group("grabbable", GRAB_RANGE)
	if nearest == null:
		return
	
	# Check weight class for grab immunity
	if nearest is Enemy and nearest.weight_class == Enemy.WeightClass.BOSS:
		return  # Bosses can't be grabbed
	
	grabbed_entity = nearest
	grab_mouse_history.clear()
	entity_grabbed.emit(nearest)
	
	# Visual: purple tint
	_set_entity_tint(nearest, Color(0.6, 0.2, 0.9))

func _update_grabbed_entity() -> void:
	var target_pos := global_position
	target_pos.y = 2.5  # Lift above hand
	grabbed_entity.global_position = grabbed_entity.global_position.lerp(target_pos, 0.25)
	grabbed_entity.rotation.y += 0.12  # Spin for visual flair

func _track_mouse_movement() -> void:
	var current_mouse := get_viewport().get_mouse_position()
	grab_mouse_history.append(current_mouse)
	if grab_mouse_history.size() > 6:
		grab_mouse_history.pop_front()

# ========== THROW ==========

func _throw_entity() -> void:
	if grabbed_entity == null:
		return
	
	var throw_vel := _calculate_throw_velocity()
	
	# Reset tint
	_set_entity_tint(grabbed_entity, Color(1.0, 1.0, 1.0))
	
	entity_thrown.emit(grabbed_entity, throw_vel)
	grabbed_entity = null
	grab_mouse_history.clear()

func _calculate_throw_velocity() -> Vector3:
	if grab_mouse_history.size() < 2:
		# No mouse movement — just drop it
		return Vector3(0, 2.0, 0)
	
	var recent := grab_mouse_history[-1]
	var older := grab_mouse_history[0]
	var mouse_delta := recent - older
	
	# Convert screen-space mouse movement to world-space throw direction
	# Screen X → World X, Screen Y → World Z (negated: screen down = world forward)
	var throw_dir: Vector3 = Vector3(mouse_delta.x, 0.0, mouse_delta.y).normalized()
	var speed: float = mouse_delta.length()
	var force: float = clampf(speed * THROW_FORCE_MULTIPLIER * 0.1, 5.0, THROW_FORCE_MAX)
	
	# Weight class affects throw distance
	if grabbed_entity is Enemy:
		match grabbed_entity.weight_class:
			Enemy.WeightClass.LIGHT:
				force *= 1.4
			Enemy.WeightClass.HEAVY:
				force *= 0.5
	
	# Add upward arc so they fly through the air
	throw_dir.y = 0.4
	throw_dir = throw_dir.normalized()
	
	return throw_dir * force

# ========== HELPERS ==========

func _find_nearest_in_group(group_name: String, max_range: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := max_range
	
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D and is_instance_valid(node):
			# Skip dead enemies
			if node is Enemy and node.is_dead:
				continue
			var dist: float = global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	
	return nearest

func _set_entity_tint(entity: Node3D, color: Color) -> void:
	## Apply a color tint to all CSG/Mesh children of an entity.
	## Works by modifying the shader's albedo_color parameter.
	for child in entity.get_children():
		if child is CSGPrimitive3D or child is MeshInstance3D:
			var mat: ShaderMaterial = child.material_override as ShaderMaterial
			if mat:
				# Duplicate material so we don't affect the shared resource
				if not child.has_meta("has_unique_mat"):
					mat = mat.duplicate() as ShaderMaterial
					child.material_override = mat
					child.set_meta("has_unique_mat", true)
				mat.set_shader_parameter("albedo_color", color)

extends CharacterBody3D
## Base enemy (hero) that navigates toward the stage door.
## Can be smited, grabbed, thrown, and used as a projectile against other enemies.
class_name Enemy

# -- Stats --
@export var max_health := 30.0
@export var move_speed := 3.0
@export var damage_to_door := 1.0
@export var xp_value := 10.0
@export var weight_class := WeightClass.MEDIUM

enum WeightClass {
	LIGHT,   # Peasants — fly far when thrown
	MEDIUM,  # Knights — moderate throw
	HEAVY,   # Paladins — stubby throw
	BOSS     # Immune to grab
}

# -- State --
var health: float
var target_position := Vector3.ZERO
var is_dead := false
var is_grabbed := false
var is_thrown := false
var throw_velocity := Vector3.ZERO
var throw_time := 0.0
var throw_gravity := 20.0

# -- Constants --
const IMPACT_AOE_RANGE := 3.0
const IMPACT_DAMAGE_MULTIPLIER := 0.6
const CORPSE_BOWLING_RANGE := 2.0
const CORPSE_BOWLING_DAMAGE := 8.0

# -- Signals --
signal died(enemy: Enemy)
signal reached_door(enemy: Enemy)

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	add_to_group("grabbable")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Thrown state — simulate physics arc
	if is_thrown:
		_process_thrown(delta)
		return
	
	# Grabbed state — hand controls position
	if is_grabbed:
		return
	
	# Normal state — walk toward the door
	_process_walking(delta)

func _process_walking(delta: float) -> void:
	var direction := (target_position - global_position)
	direction.y = 0
	
	if direction.length() < 1.0:
		reached_door.emit(self)
		return
	
	direction = direction.normalized()
	velocity = direction * move_speed
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	move_and_slide()
	
	# Face movement direction
	if velocity.length() > 0.1:
		var face_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, face_angle, 0.1)

func _process_thrown(delta: float) -> void:
	## Fly through the air in a physics arc.
	## When we hit the ground or a wall, deal AOE damage and stop.
	
	# Apply gravity to throw velocity
	throw_velocity.y -= throw_gravity * delta
	
	# Move
	velocity = throw_velocity
	move_and_slide()
	
	# If we hit a wall or obstacle, count it as an impact
	if get_slide_collision_count() > 0:
		_on_thrown_impact()
		return
	
	# Spin while flying
	rotation.x += 8.0 * delta
	rotation.z += 5.0 * delta
	
	# Safety: track flight time
	throw_time += delta
	
	# Kill if out of bounds or flying too long
	if global_position.y < -5.0 or throw_time > 3.0 or global_position.length() > 50.0:
		die()
	
	# Check if we hit the floor
	if is_on_floor() and throw_velocity.y < 0:
		_on_thrown_impact()

func start_thrown(vel: Vector3) -> void:
	## Called by main.gd when the hand throws this enemy.
	is_thrown = true
	is_grabbed = false
	throw_velocity = vel
	throw_time = 0.0
	
	# Briefly disable collision with other enemies so we fly through
	# (re-enabled on impact)
	set_collision_mask_value(2, false)

func _on_thrown_impact() -> void:
	## We hit the ground after being thrown!
	is_thrown = false
	rotation.x = 0
	rotation.z = 0
	set_collision_mask_value(2, true)
	
	var impact_force: float = throw_velocity.length()
	throw_velocity = Vector3.ZERO
	
	# Self damage from impact
	take_damage(impact_force * IMPACT_DAMAGE_MULTIPLIER)
	
	# AOE damage to nearby enemies (corpse bowling!)
	_deal_impact_aoe(impact_force)
	
	# Screen shake effect via light flash
	_play_impact_vfx()

func _deal_impact_aoe(force: float) -> void:
	## Damage nearby enemies based on impact force.
	## This is the corpse bowling mechanic!
	var aoe_range := IMPACT_AOE_RANGE
	var aoe_damage := force * 0.4
	
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		if node is Enemy and not node.is_dead and is_instance_valid(node):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < aoe_range:
				# Damage falls off with distance
				var falloff := 1.0 - (dist / aoe_range)
				node.take_damage(aoe_damage * falloff)
				
				# Push nearby enemies away (knockback)
				var push_dir: Vector3 = (node.global_position - global_position).normalized()
				push_dir.y = 0.3
				node.velocity = push_dir * force * 0.3

func _play_impact_vfx() -> void:
	## Flash of light + brief camera nudge on impact
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.5, 0.2)
	flash.light_energy = 6.0
	flash.omni_range = IMPACT_AOE_RANGE
	flash.omni_attenuation = 2.0
	flash.global_position = global_position
	get_tree().current_scene.add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

# ========== DAMAGE ==========

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	health -= amount
	_flash_damage()
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	is_grabbed = false
	is_thrown = false
	
	# Remove from groups so hand stops targeting us
	remove_from_group("enemies")
	remove_from_group("grabbable")
	
	died.emit(self)
	
	# Death animation: flash white, shrink, remove
	_set_color(Color(2.0, 2.0, 2.0))  # Bright white flash
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.1)  # Squash
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)  # Shrink to nothing
	tween.tween_callback(queue_free)

func _flash_damage() -> void:
	## Brief white flash on hit — very satisfying feedback
	_set_color(Color(3.0, 3.0, 3.0))  # Bright white
	
	# Return to normal after a brief moment
	var tween := create_tween()
	tween.tween_interval(0.06)
	tween.tween_callback(_reset_color)

func _set_color(color: Color) -> void:
	for child in get_children():
		if child is CSGPrimitive3D or child is MeshInstance3D:
			var mat: ShaderMaterial = child.material_override as ShaderMaterial
			if mat:
				if not child.has_meta("has_unique_mat"):
					mat = mat.duplicate() as ShaderMaterial
					child.material_override = mat
					child.set_meta("has_unique_mat", true)
				mat.set_shader_parameter("albedo_color", color)

func _reset_color() -> void:
	_set_color(Color(0.8, 0.7, 0.5))  # Default enemy color

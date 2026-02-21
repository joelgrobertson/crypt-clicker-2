extends CharacterBody3D
## Base enemy (hero) that navigates toward the stage door.
## All enemy types inherit from this.
class_name Enemy

# -- Stats --
@export var max_health := 30.0
@export var move_speed := 3.0
@export var damage_to_door := 1.0
@export var xp_value := 10.0
@export var weight_class := WeightClass.MEDIUM

enum WeightClass {
	LIGHT,   # Peasants, archers — fly far when thrown
	MEDIUM,  # Knights, rogues — moderate throw, slight grab delay
	HEAVY,   # Paladins, ogres — short throw distance
	BOSS     # Immune to grab
}

# -- State --
var health: float
var target_position := Vector3.ZERO  # Where this enemy is trying to go (the door)
var is_dead := false
var is_grabbed := false

# -- Signals --
signal died(enemy: Enemy)
signal reached_door(enemy: Enemy)

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	add_to_group("grabbable")

func _physics_process(delta: float) -> void:
	if is_dead or is_grabbed:
		return
	
	# Move toward target
	var direction := (target_position - global_position)
	direction.y = 0  # Stay on ground plane
	
	if direction.length() < 1.0:
		# Reached the door!
		reached_door.emit(self)
		return
	
	direction = direction.normalized()
	velocity = direction * move_speed
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	health -= amount
	
	# Flash red (visual feedback)
	_flash_damage()
	
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	died.emit(self)
	
	# TODO: Death animation, drop XP orb, ragdoll
	# For now, just remove after a short delay
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

func _flash_damage() -> void:
	# Quick white flash on hit
	# TODO: Modify material emission briefly
	pass

## Called by the throw system when this enemy lands after being thrown
func on_thrown_impact(impact_velocity: Vector3) -> void:
	var impact_force := impact_velocity.length()
	take_damage(impact_force * 0.5)
	
	# TODO: AOE splash damage to nearby enemies
	# TODO: Corpse bowling if dead

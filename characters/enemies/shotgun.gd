extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }
enum AttackType { BURST, SHOTGUN }

@export_category("Combat Settings")
@export var bullet_scene: PackedScene
@export var shoot_direction: Vector2 = Vector2.LEFT

# Define the sequence of colors to shoot. 
# Default pattern: Red -> Red -> Green -> Blue
@export var color_pattern: Array[ColorState] = [
	ColorState.RED, 
	ColorState.RED, 
	ColorState.GREEN, 
	ColorState.BLUE
]

@export_category("Burst Settings")
@export var burst_count: int = 3      # How many bullets per burst
@export var shot_delay: float = 0.3   # Time between shots inside a burst
@export var burst_reload_time: float = 2.0  # Time between bursts

@export_category("Shotgun Settings")
@export var bullet_count: int = 8
@export var spread_angle_deg: float = 45.0
@export var shotgun_reload_time: float = 2.0

@export_category("Attack Randomness")
@export var attack_types: Array[AttackType] = [
	AttackType.BURST,
	AttackType.SHOTGUN
]
@export var attack_weights: Array[float] = [
	1.0, # BURST weight
	0.7  # SHOTGUN weight
]
@export var attack_cooldowns: Array[float] = [
	2.0, # BURST cooldown
	2.0  # SHOTGUN cooldown
]

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 3
var current_pattern_index: int = 0 # Tracks position in the color_pattern array

var rng: = RandomNumberGenerator.new()
var is_attacking: = false
var last_attack_index: = -1

func _ready() -> void:
	# Set the timer to the "Reload" time
	rng.randomize()
	timer.wait_time = burst_reload_time
	timer.start()
	timer.timeout.connect(_on_timer_timeout)
	sprite.play("idle")

func _on_timer_timeout() -> void:
	# When timer hits 0, fire a whole burst
	if is_attacking: return
	
	is_attacking = true
	
	var idx: int = roll_weighted_attack()

	# Safety if arrays are mismatched / empty
	if attack_types.is_empty():
		idx = 0
	elif idx < 0 or idx >= attack_types.size():
		idx = 0

	var attack := int(attack_types[idx]) as AttackType

	match attack:
		AttackType.BURST:
			await fire_burst()
		AttackType.SHOTGUN:
			fire_shotgun()

	_schedule_next_attack(get_attack_cooldown(idx))

	is_attacking = false
	timer.start()
	
# -------------------------
# Attacks
# -------------------------
func fire_burst() -> void:
	# Loop X times for the burst
	print("burst fired")

	for i in range(burst_count):
		shoot_next_bullet(shoot_direction.normalized())
		
		# Pause execution for a split second between shots
		# (This creates the rapid-fire effect)
		await get_tree().create_timer(shot_delay).timeout

func fire_shotgun() -> void:
	print("shotgun fired")
	if bullet_scene == null: return
	if color_pattern.is_empty(): return

	var base_dir: Vector2 = shoot_direction.normalized()
	var count: int = max(1, bullet_count)

	# Choose ONE color for the whole blast (do NOT advance per pellet)
	var chosen_color: ColorState = (int(color_pattern[current_pattern_index]) as ColorState)
	update_visual_color(chosen_color)
	
	var half: float = spread_angle_deg * 0.5

	if count == 1:
		shoot_next_bullet(base_dir)
	else:
		for i in range(count):
			# evenly spaced angles across the cone
			var t: float = float(i) / float(count - 1) # 0..1
			var angle_deg: float = lerp(-half, half, t)
			var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_deg)).normalized()
			spawn_bullet(dir, chosen_color)

# Advance pattern ONCE after the whole shotgun blast
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()
		
# -------------------------
# Bullet spawning (color pattern preserved)
# -------------------------
func shoot_next_bullet(dir: Vector2) -> void:
	if bullet_scene == null: return
	
	if color_pattern.is_empty(): return

	# 1. Determine which color to use from the pattern
	var chosen_color: = int(color_pattern[current_pattern_index]) as ColorState
	# 2. Update the Enemy's visual color to match what it just shot
	update_visual_color(chosen_color)
	
	# 3. Create and Fire Bullet
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = shoot_direction
	bullet.bullet_color = chosen_color
	
	get_parent().add_child(bullet)
	
	# 4. Advance the pattern index (Loop back to 0 if at end)
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()

func spawn_bullet(dir: Vector2, color: ColorState) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = dir
	bullet.bullet_color = color
	get_parent().add_child(bullet)

func roll_weighted_attack() -> int:
	# Returns an index into attack_types/weights/cooldowns
	if attack_types.is_empty():
		return 0
	
	# If weights array is wrong size, fallback to uniform random
	if attack_weights.size() != attack_types.size():
		return rng.randi_range(0,attack_types.size())
		
	var total: float = 0.0
	for w in attack_weights:
		total += max(w, 0.0)

	if total <= 0.0:
		return rng.randi_range(0, attack_types.size() - 1)

	var r: float = rng.randf() * total
	for i in range(attack_weights.size()):
		r -= max(attack_weights[i], 0.0)
		if r <= 0.0:
			return i

	return attack_weights.size() - 1
	
func get_attack_cooldown(idx: int) -> float:
	if attack_cooldowns.size() == attack_types.size():
		return max(0.0, attack_cooldowns[idx])
	return 2.0

func _schedule_next_attack(seconds: float) -> void:
	timer.stop()
	timer.wait_time = max(0.01, seconds)

func update_visual_color(state: ColorState) -> void:
	match state:
		ColorState.RED: sprite.modulate = Color.RED
		ColorState.GREEN: sprite.modulate = Color.GREEN
		ColorState.BLUE: sprite.modulate = Color.BLUE

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy Health: ", health)
	
	# Flash White
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	# Return to the color of the NEXT bullet in the chamber
	var next_color = color_pattern[current_pattern_index] 
	tween.tween_property(sprite, "modulate", get_color_value(next_color), 0.1)

	if health <= 0:
		queue_free()

# Helper to convert Enum to actual Color
func get_color_value(state: ColorState) -> Color:
	match state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

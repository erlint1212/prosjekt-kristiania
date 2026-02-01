extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }
enum AttackType { BURST, SHOTGUN }

@export_category("Combat Settings")
@export var bullet_scene: PackedScene
@export var shoot_direction: Vector2 = Vector2.LEFT
@export var score_value: int = 500 # Added Score!

@export var color_pattern: Array[ColorState] = [
	ColorState.RED, 
	ColorState.RED, 
	ColorState.GREEN, 
	ColorState.BLUE
]

@export_category("Burst Settings")
@export var burst_count: int = 3      
@export var shot_delay: float = 0.3   
@export var burst_reload_time: float = 2.0 

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
	0.5  # SHOTGUN weight
]
@export var attack_cooldowns: Array[float] = [
	2.0, # BURST cooldown
	2.0  # SHOTGUN cooldown
]

@export_category("Effects")
@export var death_effect_scene: PackedScene

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D

var health: int = 5 # Increased health for a tougher enemy
var current_pattern_index: int = 0
var rng: = RandomNumberGenerator.new()
var is_attacking: = false
var original_scale: Vector2

func _ready() -> void:
	rng.randomize()
	
	original_scale = sprite.scale
	
	timer.wait_time = burst_reload_time
	
	# FIX: Prevent "Signal already connected" error
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
		
	timer.start()
	
	# Initialize Color
	if not color_pattern.is_empty():
		update_visual_color(color_pattern[0])

func _on_timer_timeout() -> void:
	if is_attacking: return
	
	is_attacking = true
	var idx: int = roll_weighted_attack()

	if attack_types.is_empty(): idx = 0
	elif idx < 0 or idx >= attack_types.size(): idx = 0

	var attack: AttackType = attack_types[idx]

	match attack:
		AttackType.BURST:
			await fire_burst()
		AttackType.SHOTGUN:
			# CHANGED: Added 'await' so we wait for the charge-up animation
			await fire_shotgun() 

	_schedule_next_attack(get_attack_cooldown(idx))
	is_attacking = false
	timer.start()

# -------------------------
# Attacks
# -------------------------
func fire_burst() -> void:
	print("Burst fired")
	for i in range(burst_count):
		shoot_next_bullet(shoot_direction.normalized())
		await get_tree().create_timer(shot_delay).timeout

func fire_shotgun() -> void:
	print("Shotgun charging...")
	if bullet_scene == null: return
	if color_pattern.is_empty(): return

	# --- TELEGRAPH START ---
	var charge_time: float = 0.5
	var chosen_color: ColorState = color_pattern[current_pattern_index]
	update_visual_color(chosen_color)
	
	var tween = create_tween()
	# 1. Grow larger (1.5x original size)
	tween.tween_property(sprite, "scale", original_scale * 1.5, charge_time).set_trans(Tween.TRANS_CUBIC)
	
	# 2. Glow Brighter (using raw values > 1 for HDR glow)
	# We mix the current color with pure white brightness
	var glow_color = get_color_value(chosen_color)
	glow_color.r += 1.0 
	glow_color.g += 1.0
	glow_color.b += 1.0
	tween.parallel().tween_property(sprite, "modulate", glow_color, charge_time)
	
	# Wait for the animation to finish
	await tween.finished
	# --- TELEGRAPH END ---

	print("BLAST!")
	
	# --- FIRE LOGIC (Existing Code) ---
	var base_dir: Vector2 = shoot_direction.normalized()
	var count: int = max(1, bullet_count)
	var half: float = spread_angle_deg * 0.5

	if count == 1:
		shoot_next_bullet(base_dir)
	else:
		for i in range(count):
			var t: float = float(i) / float(count - 1)
			var angle_deg: float = lerp(-half, half, t)
			var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_deg)).normalized()
			spawn_bullet(dir, chosen_color)

	# Advance pattern
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()
	
	# --- RECOIL / RESET ---
	# Snap back to normal size quickly
	var reset_tween = create_tween()
	reset_tween.tween_property(sprite, "scale", original_scale, 0.1).set_trans(Tween.TRANS_BOUNCE)
	reset_tween.parallel().tween_property(sprite, "modulate", get_color_value(color_pattern[current_pattern_index]), 0.1)
	
# -------------------------
# Bullet spawning
# -------------------------
func shoot_next_bullet(dir: Vector2) -> void:
	if bullet_scene == null: return
	if color_pattern.is_empty(): return

	var chosen_color: ColorState = color_pattern[current_pattern_index]
	update_visual_color(chosen_color)

	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	
	# FIX: Actually use the 'dir' parameter passed to the function!
	bullet.direction = dir 
	
	bullet.bullet_color = chosen_color
	get_parent().add_child(bullet)
	
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()

func spawn_bullet(dir: Vector2, color: ColorState) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = dir
	bullet.bullet_color = color
	get_parent().add_child(bullet)

# -------------------------
# Helpers & Health
# -------------------------
func roll_weighted_attack() -> int:
	if attack_types.is_empty(): return 0
	if attack_weights.size() != attack_types.size():
		return rng.randi_range(0, attack_types.size() - 1)
		
	var total: float = 0.0
	for w in attack_weights: total += max(w, 0.0)

	if total <= 0.0: return 0

	var r: float = rng.randf() * total
	for i in range(attack_weights.size()):
		r -= max(attack_weights[i], 0.0)
		if r <= 0.0: return i

	return attack_weights.size() - 1

func get_attack_cooldown(idx: int) -> float:
	if idx < attack_cooldowns.size():
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

func get_color_value(state: ColorState) -> Color:
	match state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

func take_damage(amount: int) -> void:
	health -= amount
	# Flash White
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	var next_color = color_pattern[current_pattern_index] 
	tween.tween_property(sprite, "modulate", get_color_value(next_color), 0.1)

	if health <= 0:
		die()

# FIX: Added missing die function
func die() -> void:
	if GameManager:
		GameManager.add_score(score_value)
	
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		effect.modulate = sprite.modulate 
		get_parent().add_child(effect)

	queue_free()

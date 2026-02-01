extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }
enum AttackType { BURST, SHOTGUN }

# --- CRITICAL: Needed for bullet to hit ---
var enemy_color: ColorState = ColorState.RED 

@export_category("Combat Settings")
@export var bullet_scene: PackedScene
@export var shoot_direction: Vector2 = Vector2.LEFT 
@export var score_value: int = 500 

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
	1.0, 0.5 
]
@export var attack_cooldowns: Array[float] = [
	2.0, 2.0
]

@export_category("Effects")
@export var death_effect_scene: PackedScene

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
#@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite = $AnimatedSprite2D
@onready var glow_light: PointLight2D = $GlowLight

var health: int = 5 
var current_pattern_index: int = 0
var rng: = RandomNumberGenerator.new()
var is_attacking: = false
var original_scale: Vector2
var player_ref: Node2D = null

func _ready() -> void:
	rng.randomize()
	original_scale = sprite.scale
	
	# Start Dark
	if glow_light: glow_light.energy = 0.0
	
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_ref = players[0]
	
	timer.wait_time = burst_reload_time
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
		
	timer.start()
	if not color_pattern.is_empty():
		update_visual_color(color_pattern[0])

func _physics_process(delta: float) -> void:
	if player_ref:
		shoot_direction = (player_ref.global_position - global_position).normalized()
		if shoot_direction.x < 0:
			sprite.flip_h = false 
		else:
			sprite.flip_h = true

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
			await fire_shotgun() 

	_schedule_next_attack(get_attack_cooldown(idx))
	is_attacking = false
	timer.start()

# --- NEW SHARED TELEGRAPH FUNCTION ---
func animate_telegraph(duration: float) -> void:
	var chosen_color = color_pattern[current_pattern_index]
	update_visual_color(chosen_color)
	
	var c = get_color_value(chosen_color)
	
	# 1. Light Up
	if glow_light:
		glow_light.color = c
		var light_tween = create_tween()
		light_tween.tween_property(glow_light, "energy", 2.0, duration)
	
	# 2. Scale & Modulate
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale * 1.3, duration).set_trans(Tween.TRANS_CUBIC)
	
	var glow_c = c
	glow_c.r += 1.0; glow_c.g += 1.0; glow_c.b += 1.0
	tween.parallel().tween_property(sprite, "modulate", glow_c, duration)
	
	await tween.finished

func fire_burst() -> void:
	# 1. Telegraph (Includes Glow now!)
	await animate_telegraph(0.4) 
	
	# 2. Fire
	for i in range(burst_count):
		var current_aim = shoot_direction
		if player_ref:
			current_aim = (player_ref.global_position - global_position).normalized()
		shoot_next_bullet(current_aim)
		await get_tree().create_timer(shot_delay).timeout
		
	reset_animation()

func fire_shotgun() -> void:
	# 1. Telegraph
	await animate_telegraph(0.8) # Longer charge for shotgun
	
	# 2. Fire
	var base_dir: Vector2 = shoot_direction.normalized()
	if player_ref:
		base_dir = (player_ref.global_position - global_position).normalized()
		
	var count: int = max(1, bullet_count)
	var half: float = spread_angle_deg * 0.5

	for i in range(count):
		var t: float = float(i) / float(count - 1)
		var angle_deg: float = lerp(-half, half, t)
		var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_deg)).normalized()
		var chosen = color_pattern[current_pattern_index]
		spawn_bullet(dir, chosen)

	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()
	reset_animation()

func reset_animation() -> void:
	# Snap back to normal size
	var reset_tween = create_tween()
	reset_tween.tween_property(sprite, "scale", original_scale, 0.2)
	
	# Update color to next item in chamber
	update_visual_color(color_pattern[current_pattern_index])
	
	# Turn light off
	if glow_light:
		var dim_tween = create_tween()
		dim_tween.tween_property(glow_light, "energy", 0.0, 0.3)

# ... (Bullet spawning and helpers remain the same) ...

func shoot_next_bullet(dir: Vector2) -> void:
	if bullet_scene == null: return
	if color_pattern.is_empty(): return

	var chosen_color: ColorState = color_pattern[current_pattern_index]
	# Don't update visual here if you want to keep the telegraph color active
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = dir 
	bullet.bullet_color = chosen_color
	
	# --- FIX: Tell the bullet who fired it ---
	bullet.shooter = self 
	# -----------------------------------------
	
	get_parent().add_child(bullet)
	
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()

func spawn_bullet(dir: Vector2, color: ColorState) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = dir
	bullet.bullet_color = color
	
	# --- FIX: Tell the bullet who fired it ---
	bullet.shooter = self
	# -----------------------------------------
	
	get_parent().add_child(bullet)

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
	enemy_color = state
	var c = get_color_value(state)
	sprite.modulate = c
	# NOTE: We don't update light here because we want to control light brightness via animation

func get_color_value(state: ColorState) -> Color:
	match state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

func take_damage(amount: int) -> void:
	health -= amount
	
	# 1. Flash Sprite (HDR White)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", get_color_value(enemy_color), 0.15)
	
	# 2. Flash Light
	# We force the energy high. The _physics_process might fight this, 
	# but the tween usually overrides for the split second needed.
	if glow_light:
		var light_tween = create_tween()
		light_tween.tween_property(glow_light, "color", Color.WHITE, 0.05)
		light_tween.parallel().tween_property(glow_light, "energy", 3.0, 0.05)
		# Fade back to a low "alive" glow instead of 0.0, since laser enemy usually glows a bit
		light_tween.tween_property(glow_light, "color", get_color_value(enemy_color), 0.1)
		light_tween.parallel().tween_property(glow_light, "energy", 0.5, 0.1)

	if health <= 0:
		die()

func die() -> void:
	if GameManager: GameManager.add_score(score_value)
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		effect.modulate = sprite.modulate 
		get_parent().add_child(effect)
	queue_free()

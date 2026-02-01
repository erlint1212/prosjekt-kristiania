extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

# --- CONFIGURATION ---
@export_category("Combat Settings")
@export var score_value: int = 300
@export var damage: int = 3  # UPDATED: Default to 3 damage
@export var rotation_speed: float = 2.0 

@export var color_pattern: Array[ColorState] = [ColorState.RED, ColorState.RED]

@export_category("Timing")
@export var telegraph_duration: float = 1.5 
@export var lock_duration: float = 0.5      
@export var fire_duration: float = 0.2      
@export var reload_time: float = 2.0

@export_category("Effects")
@export var death_effect_scene: PackedScene 

# --- NODES ---
@onready var laser_ray: RayCast2D = $LaserRay
@onready var laser_line: Line2D = $LaserLine
@onready var laser_glow: Line2D = $LaserGlow 
@onready var sprite: Sprite2D = $Sprite2D
@onready var timer: Timer = $Timer

# --- STATE MACHINE ---
enum State { IDLE, TELEGRAPH, LOCKED, FIRING }
var current_state: State = State.IDLE
var current_pattern_index: int = 0
var enemy_color: ColorState = ColorState.RED
var health: int = 3
var player_ref: Node2D = null

# NEW: Track if we are currently being reflected
var is_being_reflected: bool = false
# NEW: Ensure we only deal damage once per shot
var has_dealt_damage: bool = false 

func _ready() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_ref = players[0]
	
	laser_line.visible = false
	laser_glow.visible = false 
	laser_ray.enabled = true
	
	timer.wait_time = reload_time
	timer.start()
	
	if not timer.timeout.is_connected(start_attack_sequence):
		timer.timeout.connect(start_attack_sequence)
		
func _physics_process(delta: float) -> void:
	is_being_reflected = false
	
	match current_state:
		State.IDLE:
			pass
			
		State.TELEGRAPH:
			if player_ref:
				var target_dir = (player_ref.global_position - global_position).normalized()
				var angle_to = transform.x.angle_to(target_dir)
				rotate(sign(angle_to) * min(delta * rotation_speed, abs(angle_to)))
			
			update_laser_visuals(2.0, 0.15, 1.0, 20.0) 
			
		State.LOCKED:
			update_laser_visuals(4.0, 0.8, 1.2, 40.0) 
			
		State.FIRING:
			check_laser_collision()
			if is_being_reflected:
				update_laser_visuals(15.0, 1.0, 3.0, 80.0) 
			else:
				update_laser_visuals(12.0, 1.0, 2.0, 60.0)

func start_attack_sequence() -> void:
	timer.stop()
	
	# 1. SETUP & RESET
	has_dealt_damage = false # Reset damage flag for new shot
	var upcoming_color = color_pattern[current_pattern_index]
	enemy_color = upcoming_color
	update_sprite_color(upcoming_color)
	
	# 2. SEQUENCE
	current_state = State.TELEGRAPH
	laser_line.visible = true
	laser_glow.visible = true 
	await get_tree().create_timer(telegraph_duration).timeout
	
	current_state = State.LOCKED
	await get_tree().create_timer(lock_duration).timeout
	
	current_state = State.FIRING
	await get_tree().create_timer(fire_duration).timeout
	
	# 3. RESET
	current_state = State.IDLE
	laser_line.visible = false
	laser_glow.visible = false
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()
	
	timer.wait_time = reload_time
	timer.start()

func update_laser_visuals(width: float, opacity: float, brightness: float, glow_width: float) -> void:
	laser_line.width = width
	var c = get_color_value(enemy_color)
	
	var visual_color = c
	visual_color.r *= brightness
	visual_color.g *= brightness
	visual_color.b *= brightness
	visual_color.a = opacity
	laser_line.default_color = visual_color
	
	laser_glow.width = glow_width
	var glow_c = c 
	glow_c.a = opacity * 0.5
	laser_glow.default_color = glow_c

	var start_point = Vector2.ZERO
	var end_point = laser_ray.target_position
	
	if laser_ray.is_colliding():
		end_point = to_local(laser_ray.get_collision_point())
	
	laser_line.clear_points()
	laser_line.add_point(start_point)
	laser_line.add_point(end_point)
	
	laser_glow.clear_points()
	laser_glow.add_point(start_point)
	laser_glow.add_point(end_point)
	
	if is_being_reflected:
		laser_line.add_point(start_point) 
		laser_glow.add_point(start_point)

func check_laser_collision() -> void:
	if not laser_ray.is_colliding():
		return
		
	var collider = laser_ray.get_collider()
	if not collider: return

	if collider.is_in_group("Player"):
		var player = collider
		
		# 1. CHECK REFLECTION 
		var player_color = player.current_color_state if "current_color_state" in player else -1
		
		var is_reflect_match = false
		match enemy_color:
			ColorState.RED:   is_reflect_match = (player_color == ColorState.GREEN)
			ColorState.GREEN: is_reflect_match = (player_color == ColorState.BLUE)
			ColorState.BLUE:  is_reflect_match = (player_color == ColorState.RED)
		
		if is_reflect_match:
			# REFLECTION VISUALS (Always happen every frame to look good)
			is_being_reflected = true
			
			# REFLECTION DAMAGE (Only happen ONCE per burst)
			if not has_dealt_damage:
				take_damage(3) # Kill self (or take 3 damage)
				has_dealt_damage = true
			
		# 2. CHECK DAMAGE (If not reflected)
		elif player_color != enemy_color:
			# DAMAGE PLAYER (Only happen ONCE per burst)
			if not has_dealt_damage:
				if player.has_method("take_damage"):
					player.take_damage(damage)
					has_dealt_damage = true

# --- BOILERPLATE ---
func update_sprite_color(state: ColorState) -> void:
	sprite.modulate = get_color_value(state)

func get_color_value(state: ColorState) -> Color:
	match state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

func take_damage(amount: int) -> void:
	health -= amount
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", get_color_value(enemy_color), 0.1)
	if health <= 0: die()

func die() -> void:
	if GameManager: GameManager.add_score(score_value)
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		effect.modulate = sprite.modulate 
		get_parent().add_child(effect)
	queue_free()

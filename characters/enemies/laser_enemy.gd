extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

# --- CONFIGURATION ---
@export_category("Combat Settings")
@export var score_value: int = 300
@export var damage: int = 1
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

func _ready() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_ref = players[0]
	
	laser_line.visible = false
	laser_ray.enabled = true
	
	timer.wait_time = reload_time
	timer.start()
	timer.timeout.connect(start_attack_sequence)
	laser_line.visible = false
	laser_glow.visible = false # Hide glow initially too
	laser_ray.enabled = true
	
	timer.wait_time = reload_time
	timer.start()
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
			
			# UPDATED: Lower opacity (0.4 -> 0.15)
			# Width: 2.0 main, 20.0 glow
			update_laser_visuals(2.0, 0.15, 1.0, 20.0) 
			
		State.LOCKED:
			# Pulsing warning
			update_laser_visuals(4.0, 0.8, 1.2, 40.0) 
			
		State.FIRING:
			check_laser_collision()
			if is_being_reflected:
				# Snap back visual
				update_laser_visuals(15.0, 1.0, 3.0, 80.0) 
			else:
				# Normal firing
				update_laser_visuals(12.0, 1.0, 2.0, 60.0)

func start_attack_sequence() -> void:
	timer.stop()
	
	# 1. SETUP COLOR
	var upcoming_color = color_pattern[current_pattern_index]
	enemy_color = upcoming_color
	update_sprite_color(upcoming_color)
	
	# 2. SEQUENCE
	current_state = State.TELEGRAPH
	laser_line.visible = true
	laser_glow.visible = true # Show glow
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

# UPDATED: Now takes 'brightness' to make it glow
func update_laser_visuals(width: float, opacity: float, brightness: float, glow_width: float) -> void:
	# 1. Update Main Beam
	laser_line.width = width
	var c = get_color_value(enemy_color)
	
	# Apply Brightness
	var visual_color = c
	visual_color.r *= brightness
	visual_color.g *= brightness
	visual_color.b *= brightness
	visual_color.a = opacity
	laser_line.default_color = visual_color
	
	# 2. Update Glow Beam (Background Gradient)
	laser_glow.width = glow_width
	# Glow is usually the same color but softer opacity
	var glow_c = c 
	glow_c.a = opacity * 0.5 # Glow is always a bit more transparent
	laser_glow.default_color = glow_c

	# 3. Calculate Points (Shared by both lines)
	var start_point = Vector2.ZERO
	var end_point = laser_ray.target_position
	
	if laser_ray.is_colliding():
		end_point = to_local(laser_ray.get_collision_point())
	
	# Sync Points
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
		
		# 1. CHECK REFLECTION (Rock Paper Scissors)
		var player_color = player.current_color_state if "current_color_state" in player else -1
		
		var is_reflect_match = false
		match enemy_color:
			ColorState.RED:   is_reflect_match = (player_color == ColorState.GREEN)
			ColorState.GREEN: is_reflect_match = (player_color == ColorState.BLUE)
			ColorState.BLUE:  is_reflect_match = (player_color == ColorState.RED)
		
		if is_reflect_match:
			# REFLECTION HAPPENED!
			is_being_reflected = true
			take_damage(1) # Damage SELF immediately
			
		# 2. CHECK DAMAGE (If not reflected, and colors mismatch)
		elif player_color != enemy_color:
			if player.has_method("take_damage"):
				player.take_damage(damage)

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
	# Flash White
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

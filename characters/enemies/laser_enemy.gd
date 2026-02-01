extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

# --- AUDIO EXPORTS ---
# Drag sound files here if you didn't set them in the scene inspector
@export_category("Audio")
@export var reflect_sound: AudioStream
@onready var charge_player: AudioStreamPlayer2D = $ChargePlayer
@onready var beam_player: AudioStreamPlayer2D = $BeamPlayer

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
#@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite = $AnimatedSprite2D
@onready var timer: Timer = $Timer

@onready var glow_light: PointLight2D = $GlowLight # The enemy body glow
@onready var impact_light: PointLight2D = $ImpactLight # The laser hit glow

# --- STATE MACHINE ---
enum State { IDLE, TELEGRAPH, LOCKED, FIRING }
var current_state: State = State.IDLE
var current_pattern_index: int = 0
var enemy_color: ColorState = ColorState.RED
var health: int = 3
var player_ref: Node2D = null
var was_reflected_last_frame: bool = false

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
	sprite.play("default")
	
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
	# --- NEW SOUND LOGIC FOR REFLECTION ---
	# We only play the sound on the exact frame reflection starts
	if is_being_reflected and not was_reflected_last_frame:
		if reflect_sound:
			GameManager.play_sound_at(global_position, reflect_sound, 5.0) # Play loud!
	
	was_reflected_last_frame = is_being_reflected

func start_attack_sequence() -> void:
	timer.stop()
	
	# 1. SETUP & RESET
	has_dealt_damage = false 
	var upcoming_color = color_pattern[current_pattern_index]
	enemy_color = upcoming_color
	update_sprite_color(upcoming_color)
	
	# --- AUDIO START: CHARGE ---
	if charge_player.stream:
		# Pitch scale can make it sound faster/slower based on duration
		charge_player.pitch_scale = 1.0 
		charge_player.play()
	
	# 2. SEQUENCE (Telegraph)
	current_state = State.TELEGRAPH
	laser_line.visible = true
	laser_glow.visible = true 
	await get_tree().create_timer(telegraph_duration).timeout
	
	# (Locked)
	current_state = State.LOCKED
	await get_tree().create_timer(lock_duration).timeout
	
	# --- AUDIO SWITCH: FIRE ---
	charge_player.stop() # Stop charging
	if beam_player.stream:
		beam_player.play() # Start looping hum
	
	# (Firing)
	current_state = State.FIRING
	await get_tree().create_timer(fire_duration).timeout
	
	# --- AUDIO STOP ---
	beam_player.stop()
	
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

	# --- NEW LIGHTING LOGIC ---
	
	# 1. Body Glow Logic (Pulsing with the laser state)
	# When opacity is high (attacking), make the body glow brighter
	glow_light.energy = 0.5 + (brightness * 0.5) 
	glow_light.color = get_color_value(enemy_color)

	# 2. Impact Light Logic
	if laser_ray.is_colliding():
		end_point = to_local(laser_ray.get_collision_point())
		# Turn light ON if hitting something
		impact_light.enabled = true
		impact_light.position = end_point
		impact_light.color = get_color_value(enemy_color)
		impact_light.energy = brightness # Scales with attack state (dim -> bright)
	else:
		# Turn light OFF if shooting into void
		impact_light.enabled = false

func check_laser_collision() -> void:
	if not laser_ray.is_colliding():
		return
		
	var collider = laser_ray.get_collider()
	if not collider: return

	if collider.is_in_group("Player"):
		var player = collider
		
		# Get Player Color
		var player_color = player.current_color_state if "current_color_state" in player else -1
		
		# --- NEW RULES ---
		
		# 1. REFLECTION: Same Color
		if player_color == enemy_color:
			is_being_reflected = true
			
			if not has_dealt_damage:
				take_damage(3) # Reflects back and kills enemy
				has_dealt_damage = true
			
		# 2. DAMAGE: Different Colord
		else:
			if not has_dealt_damage:
				if player.has_method("take_damage"):
					player.take_damage(damage)
					has_dealt_damage = true

# --- BOILERPLATE ---
func update_sprite_color(state: ColorState) -> void:
	var c = get_color_value(state)
	sprite.modulate = c
	
	# NEW: Update lights
	if glow_light:
		glow_light.color = c
	if impact_light:
		impact_light.color = c

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

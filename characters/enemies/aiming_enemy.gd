extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

# --- CONFIGURATION ---
@export_category("Combat Settings")
@export var bullet_scene: PackedScene
@export var score_value: int = 200 # Worth more points!

@export var color_pattern: Array[ColorState] = [
	ColorState.BLUE, 
	ColorState.BLUE, 
	ColorState.RED
]

@export_category("Burst Settings")
@export var burst_count: int = 1      # Snipers usually shoot once per reload
@export var shot_delay: float = 0.5
@export var reload_time: float = 3.0  # Slower reload

@export_category("Telegraph Settings")
@export var telegraph_time: float = 1.0 # Longer warning time

@export_category("Effects")
@export var death_effect_scene: PackedScene 

# --- INTERNAL VARIABLES ---
var enemy_color: ColorState = ColorState.RED 
var health: int = 3
var current_pattern_index: int = 0
var player_ref: Node2D = null # Store reference to player

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 1. FIND THE PLAYER
	# We look for the "Player" group. Make sure your Player node is in this group!
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_ref = players[0]
	
	# 2. Setup Timer
	timer.wait_time = reload_time
	timer.start()
	timer.timeout.connect(_on_timer_timeout)

func _physics_process(_delta: float) -> void:
	# 3. ROTATE TOWARDS PLAYER
	if player_ref:
		look_at(player_ref.global_position)
		
		# Optional: Ensure sprite isn't upside down if you want
		# (Not strictly necessary for top-down or simple shapes)

func _on_timer_timeout() -> void:
	fire_burst()

func fire_burst() -> void:
	for i in range(burst_count):
		await telegraph_shot()
		shoot_at_player()
		await get_tree().create_timer(shot_delay).timeout

func telegraph_shot() -> void:
	var upcoming_color = color_pattern[current_pattern_index]
	enemy_color = upcoming_color 
	
	update_visual_color(upcoming_color)
	
	# Flash White
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, telegraph_time * 0.5)
	tween.tween_property(sprite, "modulate", get_color_value(upcoming_color), telegraph_time * 0.5)
	
	await tween.finished

func shoot_at_player() -> void:
	if bullet_scene == null: return

	var chosen_color = color_pattern[current_pattern_index]
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	
	# --- KEY CHANGE: AIMING ---
	# Since the enemy rotated using look_at(), the Muzzle is already facing the player.
	# We just need to take the enemy's rotation, or calculate the vector again.
	
	# Method A: Use the enemy's rotation (Easiest since we used look_at)
	bullet.direction = Vector2.RIGHT.rotated(rotation)
	
	bullet.bullet_color = chosen_color
	bullet.shooter = self 
	
	get_parent().add_child(bullet)
	
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()

# --- UTILS (Same as before) ---
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
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	var next_color = color_pattern[current_pattern_index] 
	tween.tween_property(sprite, "modulate", get_color_value(next_color), 0.1)

	if health <= 0:
		die()

func die() -> void:
	if GameManager:
		GameManager.add_score(score_value)
	
	if death_effect_scene:
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		effect.modulate = sprite.modulate 
		get_parent().add_child(effect)

	queue_free()

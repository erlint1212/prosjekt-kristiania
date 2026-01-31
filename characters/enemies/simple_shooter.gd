extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

# --- ADD THIS LINE ---
# This variable allows the Bullet to "read" the enemy's current color
var enemy_color: ColorState = ColorState.RED 

@export_category("Combat Settings")
@export var bullet_scene: PackedScene
@export var shoot_direction: Vector2 = Vector2.LEFT

@export var color_pattern: Array[ColorState] = [
	ColorState.RED, 
	ColorState.RED, 
	ColorState.GREEN, 
	ColorState.BLUE
]

# ... (Keep Burst Settings as they are) ...
@export_category("Burst Settings")
@export var burst_count: int = 3
@export var shot_delay: float = 0.3
@export var reload_time: float = 2.0

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D

@export_category("Telegraph Settings")
@export var telegraph_time: float = 0.4 

@export_category("Effects")
@export var death_effect_scene: PackedScene

var health: int = 3
var current_pattern_index: int = 0

func _ready() -> void:
	timer.wait_time = reload_time
	timer.start()
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	fire_burst()

func fire_burst() -> void:
	for i in range(burst_count):
		await telegraph_shot()
		shoot_next_bullet()
		await get_tree().create_timer(shot_delay).timeout

# UPDATED: No more scaling
func telegraph_shot() -> void:
	var upcoming_color = color_pattern[current_pattern_index]
	enemy_color = upcoming_color 
	
	update_visual_color(upcoming_color)
	
	var tween = create_tween()
	
	# Just flash WHITE to warn the player (No scale change)
	tween.tween_property(sprite, "modulate", Color.WHITE, telegraph_time * 0.5)
	
	# Return to the correct color
	tween.tween_property(sprite, "modulate", get_color_value(upcoming_color), telegraph_time * 0.5)
	
	await tween.finished

# UPDATED: Spawns particles
func die() -> void:
	# DEBUG: Check if the scene is actually assigned
	if death_effect_scene == null:
		print("ERROR: death_effect_scene is NULL! I cannot explode.")
	else:
		print("Spawning effect...")
		var effect = death_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)

	queue_free()

func shoot_next_bullet() -> void:
	if bullet_scene == null: return

	var chosen_color = color_pattern[current_pattern_index]
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = shoot_direction
	bullet.bullet_color = chosen_color
	
	# --- OPTIONAL: Make sure the bullet knows who shot it ---
	bullet.shooter = self 
	
	get_parent().add_child(bullet)
	
	current_pattern_index = (current_pattern_index + 1) % color_pattern.size()

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
		die()

# Helper to convert Enum to actual Color
func get_color_value(state: ColorState) -> Color:
	match state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

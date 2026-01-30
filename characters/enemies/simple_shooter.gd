extends CharacterBody2D

enum ColorState { RED, GREEN, BLUE }

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
@export var reload_time: float = 2.0  # Time between bursts

@onready var muzzle: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D

var health: int = 3
var current_pattern_index: int = 0 # Tracks position in the color_pattern array

func _ready() -> void:
	# Set the timer to the "Reload" time
	timer.wait_time = reload_time
	timer.start()
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	# When timer hits 0, fire a whole burst
	fire_burst()

func fire_burst() -> void:
	# Loop X times for the burst
	for i in range(burst_count):
		shoot_next_bullet()
		
		# Pause execution for a split second between shots
		# (This creates the rapid-fire effect)
		await get_tree().create_timer(shot_delay).timeout

func shoot_next_bullet() -> void:
	if bullet_scene == null: return

	# 1. Determine which color to use from the pattern
	var chosen_color = color_pattern[current_pattern_index]
	
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

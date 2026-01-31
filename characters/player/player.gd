extends CharacterBody2D

# --- NEW SIGNALS ---
signal health_changed(current_value, max_value)
signal player_died

# --- COLOR LOGIC (Keep existing) ---
enum ColorState { RED, GREEN, BLUE }
var current_color_state: ColorState = ColorState.RED
@onready var sprite_visual: Node2D = $Sprite2D

# --- NEW HEALTH VARIABLES ---
@export var max_health: int = 5
@onready var current_health: int = max_health

# --- PHYSICS VARIABLES (Keep existing) ---
@export_category("Movement Stats")
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	change_color(ColorState.RED)
	# Initialize HUD immediately
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	# Gravity logic...
	if not is_on_floor():
		velocity.y += gravity * delta

	# 1. JUMP (Mapped to 'W' in Input Map)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 2. LEFT/RIGHT (Mapped to 'A' and 'D' in Input Map)
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Check for color change keys (1, 2, 3)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			change_color(ColorState.RED)
		elif event.keycode == KEY_2:
			change_color(ColorState.GREEN)
		elif event.keycode == KEY_3:
			change_color(ColorState.BLUE)

func change_color(new_state: ColorState) -> void:
	current_color_state = new_state
	
	# If you are using PlaceholderTexture or ColorRect, 'modulate' works for both
	match current_color_state:
		ColorState.RED:
			sprite_visual.modulate = Color.RED
		ColorState.GREEN:
			sprite_visual.modulate = Color.GREEN
		ColorState.BLUE:
			sprite_visual.modulate = Color.BLUE

# --- UPDATED DAMAGE LOGIC ---
func take_damage(amount: int) -> void:
	current_health -= amount
	
	# Broadcast the update to the HUD
	health_changed.emit(current_health, max_health)
	
	print("Player took damage: ", amount, " | Health: ", current_health)
	
	# Visual feedback (flash white)
	var tween = create_tween()
	tween.tween_property(sprite_visual, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite_visual, "modulate", get_current_color_value(), 0.1)

	if current_health <= 0:
		die()

func die() -> void:
	player_died.emit()
	print("Player Died!")
	# For now, just reload the scene to try again
	get_tree().reload_current_scene()

func get_current_color_value() -> Color:
	match current_color_state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

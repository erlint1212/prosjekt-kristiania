extends CharacterBody2D

# --- COLOR LOGIC (Keep this) ---
enum ColorState { RED, GREEN, BLUE }
var current_color_state: ColorState = ColorState.RED
# Use ColorRect if you switched to it, otherwise use Sprite2D
@onready var sprite_visual: Node2D = $Sprite2D # Change to $ColorRect if you are using that

# --- PHYSICS VARIABLES ---
@export_category("Movement Stats")
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0 # Negative goes UP in Godot

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	# Initialize color on start
	change_color(ColorState.RED)

func _physics_process(delta: float) -> void:
	# Gravity logic...
	if not is_on_floor():
		velocity.y += gravity * delta

	# 1. JUMP (Mapped to 'W' in Input Map)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		if Input.is_action_just_released("jump") and velocity.y < jump_velocity / 2:
			velocity.y = jump_velocity / 2
	
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

func take_damage(amount: int) -> void:
	print("Player took damage: ", amount)
	# Add health logic here, e.g.:
	# health -= amount
	# if health <= 0: die()
	
	# Visual feedback (flash white)
	var tween = create_tween()
	tween.tween_property(sprite_visual, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite_visual, "modulate", get_current_color_value(), 0.1)

func get_current_color_value() -> Color:
	# Helper to get the actual Color object for the tween above
	match current_color_state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

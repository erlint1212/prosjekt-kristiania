extends CharacterBody2D

# --- SIGNALS ---
signal health_changed(current_value, max_value)
signal player_died

# --- COLOR & TEXTURE SETTINGS ---
enum ColorState { RED, GREEN, BLUE }
var current_color_state: ColorState = ColorState.RED

@onready var sprite_visual: Sprite2D = $Sprite2D

# NEW: Drag your PNGs here in the Inspector
@export_category("Mask Visuals")
@export var red_mask_texture: Texture2D
@export var green_mask_texture: Texture2D
@export var blue_mask_texture: Texture2D

# --- STATS ---
@export_category("Stats")
@export var max_health: int = 5
@onready var current_health: int = max_health

@export_category("Movement Stats")
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var fast_fall_multiplier: float = 4.0

@export var mask_size: Vector2 = Vector2(40, 40) # The target size in pixels

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	# Initialize HUD
	health_changed.emit(current_health, max_health)
	change_color(ColorState.RED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		if Input.is_action_pressed("move_down"):
			velocity.y += gravity * fast_fall_multiplier * delta
		else:
			velocity.y += gravity * delta

	# DROP DOWN LOGIC
	# Check if on floor, holding DOWN, and pressed JUMP
	if is_on_floor() and Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump"):
		position.y += 1 # Push player 1 pixel into the platform so physics lets them fall
		return # Skip the normal jump logic

	# NORMAL JUMP
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			change_color(ColorState.RED)
		elif event.keycode == KEY_2:
			change_color(ColorState.GREEN)
		elif event.keycode == KEY_3:
			change_color(ColorState.BLUE)

func change_color(new_state: ColorState) -> void:
	current_color_state = new_state
	
	match current_color_state:
		ColorState.RED:
			sprite_visual.modulate = Color.RED
			apply_texture(red_mask_texture)
				
		ColorState.GREEN:
			sprite_visual.modulate = Color.GREEN
			apply_texture(green_mask_texture)
				
		ColorState.BLUE:
			sprite_visual.modulate = Color.BLUE
			apply_texture(blue_mask_texture)

func apply_texture(tex: Texture2D) -> void:
	# 1. Safety Check: If no texture is assigned, don't crash
	if tex == null:
		return
		
	# 2. Assign the texture
	sprite_visual.texture = tex
	
	# 3. Calculate the correct scale
	# Formula: Target Size / Actual Image Size
	var tex_size = tex.get_size()
	
	# Option A: Stretch to fit exactly 40x40 (might distort shape)
	sprite_visual.scale = mask_size / tex_size
	
	# Option B: Keep Aspect Ratio (Fit INSIDE 40x40 box) - Uncomment if prefered
	# var scale_factor = min(mask_size.x / tex_size.x, mask_size.y / tex_size.y)
	# sprite_visual.scale = Vector2(scale_factor, scale_factor)

func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health, max_health)
	print("Player took damage: ", amount, " | Health: ", current_health)
	
	var tween = create_tween()
	tween.tween_property(sprite_visual, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite_visual, "modulate", get_current_color_value(), 0.1)

	if current_health <= 0:
		die()

func die() -> void:
	player_died.emit()
	print("Player Died!")
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func get_current_color_value() -> Color:
	match current_color_state:
		ColorState.RED: return Color.RED
		ColorState.GREEN: return Color.GREEN
		ColorState.BLUE: return Color.BLUE
	return Color.WHITE

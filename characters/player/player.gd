extends CharacterBody2D

# --- SIGNALS ---
signal health_changed(current_value, max_value)
signal player_died

# --- COLOR & TEXTURE SETTINGS ---
enum ColorState { RED, GREEN, BLUE }
var current_color_state: ColorState = ColorState.RED

@onready var sprite_visual: Sprite2D = $Sprite2D

# NEW: Track the damage tween so we can cancel it
var damage_tween: Tween

@export_category("Mask Visuals")
@export var red_mask_texture: Texture2D
@export var green_mask_texture: Texture2D
@export var blue_mask_texture: Texture2D

# --- STATS ---
@export_category("Stats")
@export var max_health: int = 10
@onready var current_health: int = max_health

@export_category("Movement Stats")
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var fast_fall_multiplier: float = 4.0

@export var mask_size: Vector2 = Vector2(40, 40) 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	health_changed.emit(current_health, max_health)
	change_color(ColorState.RED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		if Input.is_action_pressed("move_down"):
			velocity.y += gravity * fast_fall_multiplier * delta
		else:
			velocity.y += gravity * delta

	# DROP DOWN
	if is_on_floor() and Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump"):
		position.y += 1 
		return 

	# JUMP
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
	# 1. STOP FLASHING: If we change masks, kill the damage animation immediately
	# so the new color sticks.
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	
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
	if tex == null: return
	sprite_visual.texture = tex
	var tex_size = tex.get_size()
	sprite_visual.scale = mask_size / tex_size

func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health, max_health)
	print("Player took damage: ", amount, " | Health: ", current_health)
	
	# 2. SAVE TWEEN REFERENCE
	# We assign the tween to a variable so 'change_color' can access it.
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill() # Kill previous damage flash if taking damage rapidly
		
	damage_tween = create_tween()
	
	# Step 1: Flash White
	damage_tween.tween_property(sprite_visual, "modulate", Color.WHITE, 0.1)
	
	# Step 2: Return to CURRENT color
	# Note: We must call get_current_color_value() here to bake the correct color 
	# into the animation at this moment.
	damage_tween.tween_property(sprite_visual, "modulate", get_current_color_value(), 0.1)

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

extends Area2D

# Define the same enum as the player/enemy
enum ColorState { RED, GREEN, BLUE }

@export var speed: float = 400.0
@export var damage: int = 1
@export var bullet_color: ColorState = ColorState.RED

var direction: Vector2 = Vector2.RIGHT
var reflected: bool = false
var shooter: Node2D # The character who fired (or reflected) this bullet

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 1. Set visual color
	match bullet_color:
		ColorState.RED: sprite.modulate = Color.RED
		ColorState.GREEN: sprite.modulate = Color.GREEN
		ColorState.BLUE: sprite.modulate = Color.BLUE
	
	# 2. Cleanup when off-screen (requires VisibleOnScreenNotifier2D child node)
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# 3. Connect collision
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Ignore the person who shot this bullet so you don't hit yourself
	if body == shooter: 
		return
	
	# If we hit a Wall/Floor
	if body is TileMapLayer:
		queue_free()
		return

	# If we hit a Character (Player OR Enemy)
	# We check if they have the color property (Player uses 'current_color_state', Enemy uses 'enemy_color')
	if "current_color_state" in body or "enemy_color" in body:
		handle_character_collision(body)

func handle_character_collision(target: Node2D) -> void:
	# Normalize property names
	var target_color = null
	if "current_color_state" in target:
		target_color = target.current_color_state
	elif "enemy_color" in target:
		target_color = target.enemy_color
	
	# --- NEW LOGIC STARTS HERE ---
	
	# 1. SPECIAL RULE: If this is an Enemy and the bullet is Reflected, ALWAYS DAMAGE.
	# We skip the color math because the player already did the work to reflect it.
	if reflected and "enemy_color" in target:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
		return
	
	# --- NEW LOGIC ENDS HERE ---
	
	# 2. Standard Logic (Player getting hit, or un-reflected bullets)
	if target_color == bullet_color:
		return # Phase through

	# Check reflection conditions (Rock Paper Scissors)
	var is_reflect_match = false
	match bullet_color:
		ColorState.RED:   is_reflect_match = (target_color == ColorState.GREEN)
		ColorState.GREEN: is_reflect_match = (target_color == ColorState.BLUE)
		ColorState.BLUE:  is_reflect_match = (target_color == ColorState.RED)

	if is_reflect_match:
		reflect_bullet(target)
	else:
		# Deal damage (Player getting hit)
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()

func reflect_bullet(new_shooter: Node2D) -> void:
	if reflected: return
	
	reflected = true
	direction = -direction
	
	# CHANGE THIS: Increase speed significantly (e.g., 3x or 4x)
	speed *= 3.0 
	
	shooter = new_shooter
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

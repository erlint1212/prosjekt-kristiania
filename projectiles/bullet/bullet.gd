extends Area2D

enum ColorState { RED, GREEN, BLUE }

@export var speed: float = 400.0
@export var damage: int = 1
@export var bullet_color: ColorState = ColorState.RED

var direction: Vector2 = Vector2.RIGHT
var reflected: bool = false
var shooter: Node2D 

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	# 1. Set visual color
	var c = Color.WHITE
	match bullet_color:
		ColorState.RED: c = Color(1.5, 0.2, 0.2)
		ColorState.GREEN: c = Color(0.2, 1.5, 0.2)
		ColorState.BLUE: c = Color(0.2, 0.2, 1.5)
	
	sprite.modulate = c
	if light: light.color = c
	
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Ignore the shooter (or the person who just reflected it)
	if body == shooter: 
		return
	
	# Wall Collision
	if body is TileMapLayer:
		queue_free()
		return

	# Character Collision (Player OR Enemy)
	if "current_color_state" in body or "enemy_color" in body:
		handle_character_collision(body)

func handle_character_collision(target: Node2D) -> void:
	# 1. Get Target Color
	var target_color = null
	if "current_color_state" in target:
		target_color = target.current_color_state
	elif "enemy_color" in target:
		target_color = target.enemy_color
	
	# --- NEW RULES START ---
	
	# 2. SPECIAL: If Enemy is hit by a Reflected bullet, they take damage regardless of color
	# (Optional: keep this if you want reflected shots to always kill, otherwise remove)
	if reflected and "enemy_color" in target:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
		return

	# 3. REFLECTION: Same Color = Reflect
	if target_color == bullet_color:
		reflect_bullet(target)
		return

	# 4. DAMAGE: Different Color = Damage
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	queue_free()
	# --- NEW RULES END ---

func reflect_bullet(new_shooter: Node2D) -> void:
	if reflected: return
	
	reflected = true
	direction = -direction
	speed *= 3.0 
	
	shooter = new_shooter
	# Ensure it can hit everything now
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)

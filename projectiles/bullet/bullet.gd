extends Area2D

# Define the same enum as the player for consistency
enum ColorState { RED, GREEN, BLUE }

@export var speed: float = 400.0
@export var damage: int = 1
@export var bullet_color: ColorState = ColorState.RED

var direction: Vector2 = Vector2.RIGHT
var reflected: bool = false # Tracks if the bullet has been reflected

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Set visual color
	match bullet_color:
		ColorState.RED: sprite.modulate = Color.RED
		ColorState.GREEN: sprite.modulate = Color.GREEN
		ColorState.BLUE: sprite.modulate = Color.BLUE
	
	# Delete bullet when it leaves the screen
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 1. Logic if we hit the Player
	if body.name == "Player":
		handle_player_collision(body)
		
	# 2. Logic if we hit an Enemy (only if reflected)
	elif body.is_in_group("Enemies") and reflected:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free() # Destroy bullet
	
	# 3. Logic if we hit a Wall
	elif body is TileMapLayer:
		queue_free()

func handle_player_collision(player: Node2D) -> void:
	# Get the player's current color
	var p_color = player.current_color_state
	
	# CASE A: Same Color -> Phase Through
	if p_color == bullet_color:
		# Do nothing! The bullet keeps flying through.
		return 

	# CASE B: "Reflect" Color (We define the cycle here)
	# Example: Red reflects Green, Green reflects Blue, Blue reflects Red
	var is_reflect_match = false
	
	match bullet_color:
		ColorState.RED:   is_reflect_match = (p_color == ColorState.GREEN)
		ColorState.GREEN: is_reflect_match = (p_color == ColorState.BLUE)
		ColorState.BLUE:  is_reflect_match = (p_color == ColorState.RED)

	if is_reflect_match:
		reflect_bullet()
	
	# CASE C: "Damage" Color (The remaining option)
	else:
		if player.has_method("take_damage"):
			player.take_damage(damage)
		queue_free() # Destroy bullet on impact

func reflect_bullet() -> void:
	if reflected: return # Prevent double reflection if needed
	
	reflected = true
	direction = -direction # Reverse direction
	speed *= 1.5 # Optional: Make it return faster!
	
	# CRITICAL: Change collision mask so it no longer hits the player
	# but can now hit enemies.
	set_collision_mask_value(1, false) # Stop looking for Player (Layer 1)
	set_collision_mask_value(3, true)  # Start looking for Enemies (Layer 3)
	

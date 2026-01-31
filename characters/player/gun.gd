extends Node2D

@export var bullet_scene: PackedScene
@onready var muzzle: Marker2D = $Muzzle

# Reference to the parent player to know what color we are
@onready var player = get_parent()

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())
	
	# If the mouse is to the left of the player, flip the gun vertically
	# so the sprite isn't upside down.
	if get_global_mouse_position().x < global_position.x:
		scale.y = -1
	else:
		scale.y = 1

func _unhandled_input(event: InputEvent) -> void:
	# This now handles the Left Mouse Button automatically
	# because we assigned it to the "shoot" action.
	if event.is_action_pressed("shoot"):
		shoot()

func shoot() -> void:
	if bullet_scene == null: return
	
	var bullet = bullet_scene.instantiate()
	
	# Set Position & Rotation
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	
	# Inherit Color from Player
	bullet.bullet_color = player.current_color_state
	
	# Set "Shooter" so we don't hit ourselves immediately
	bullet.shooter = player
	
	# Add to world
	player.get_parent().add_child(bullet)

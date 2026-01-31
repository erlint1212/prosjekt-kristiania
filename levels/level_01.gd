extends Node2D

@onready var player = $Player
@onready var hud = $Hud

func _ready() -> void:
	print("Level 1 Loaded")
	
	# Connect Player Signal -> HUD Function
	player.health_changed.connect(hud.update_health)
	
	# Force an update right now so the bar starts full
	hud.update_health(player.current_health, player.max_health)

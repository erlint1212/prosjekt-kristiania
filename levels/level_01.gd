extends Node2D

@onready var player = $Player
@onready var hud = $Hud

func _ready() -> void:
	print("Level 1 Loaded")
	
	player.health_changed.connect(hud.update_health)
	
	# --- NEW CONNECTION ---
	# When player dies -> Show HUD Game Over screen
	player.player_died.connect(hud.show_game_over)
	
	hud.update_health(player.current_health, player.max_health)

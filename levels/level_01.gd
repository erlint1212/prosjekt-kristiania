extends Node2D

@onready var player = $Player
@onready var hud = $Hud
# Make sure the Flag node in your scene is actually named "Flag"
# If you named it "Area2D", rename it in the scene tree or change this line.
@onready var flag = $Flag 

func _ready() -> void:
	print("Level 1 Loaded")
	
	# 1. Connect Player Signals
	player.health_changed.connect(hud.update_health)
	player.player_died.connect(hud.show_game_over)
	
	# 2. Connect Flag Signal
	# We use 'connect' directly. Since we removed the editor connection,
	# we don't need to check 'is_connected' constantly.
	if flag.has_signal("level_completed"):
		flag.level_completed.connect(_on_flag_level_completed)
		print("Flag signal successfully connected via Code")
	else:
		print("ERROR: Flag node does not have signal 'level_completed'")
	
	hud.update_health(player.current_health, player.max_health)

func _on_flag_level_completed() -> void:
	print("VICTORY! Signal received in Level Script.")
	hud.show_victory()

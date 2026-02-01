extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/ScoreLabel
@onready var health_bar = $Control/HealthBar

# Death Screen
@onready var death_screen = $DeathScreen
@onready var final_score_label = $DeathScreen/VBoxContainer/FinalScoreLabel
@onready var restart_button = $DeathScreen/VBoxContainer/RestartButton

# NEW: Victory Screen
@onready var victory_screen = $VictoryScreen
@onready var victory_score_label = $VictoryScreen/VBoxContainer/FinalScoreLabel
@onready var next_level_button = $VictoryScreen/VBoxContainer/NextLevelButton

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	score_label.text = "Score: 0"
	
	death_screen.visible = false
	victory_screen.visible = false # Hide victory initially
	
	restart_button.pressed.connect(_on_restart_pressed)
	# Connect new button
	next_level_button.pressed.connect(_on_next_level_pressed)

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

# --- GAME OVER ---
func show_game_over() -> void:
	final_score_label.text = "Final Score: " + str(GameManager.score)
	death_screen.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.score = 0
	get_tree().reload_current_scene()

# --- NEW: VICTORY ---
func show_victory() -> void:
	victory_score_label.text = "Total Score: " + str(GameManager.score)
	victory_screen.visible = true
	get_tree().paused = true

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	
	# Logic to load next level
	# For now, we just reload the current one, or go to menu
	# You can replace this with: get_tree().change_scene_to_file("res://levels/level_02.tscn")
	print("Loading Next Level...")
	get_tree().reload_current_scene()

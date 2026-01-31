extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/ScoreLabel
@onready var health_bar = $Control/HealthBar

# NEW VARIABLES
@onready var death_screen = $DeathScreen
@onready var final_score_label = $DeathScreen/VBoxContainer/FinalScoreLabel
@onready var restart_button = $DeathScreen/VBoxContainer/RestartButton

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	score_label.text = "Score: 0"
	
	# Make sure it's hidden on start
	death_screen.visible = false
	
	# Connect the button via code (or you can do it via editor signals)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

# --- NEW FUNCTIONS ---

func show_game_over() -> void:
	# 1. Update the final score text
	final_score_label.text = "Final Score: " + str(GameManager.score)
	
	# 2. Show the overlay
	death_screen.visible = true
	
	# 3. PAUSE the game so enemies stop shooting
	get_tree().paused = true

func _on_restart_pressed() -> void:
	# 1. Unpause the game (Important! Otherwise the next game starts frozen)
	get_tree().paused = false
	
	# 2. Reset Score
	GameManager.score = 0
	
	# 3. Reload the Level
	get_tree().reload_current_scene()

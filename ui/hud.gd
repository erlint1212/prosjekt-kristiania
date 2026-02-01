extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/ScoreLabel
@onready var health_container = $Control/HealthContainer

# Death & Victory Screens
@onready var death_screen = $DeathScreen
@onready var final_score_label = $DeathScreen/VBoxContainer/FinalScoreLabel
@onready var restart_button = $DeathScreen/VBoxContainer/RestartButton

@onready var victory_screen = $VictoryScreen
@onready var victory_score_label = $VictoryScreen/VBoxContainer/FinalScoreLabel
@onready var next_level_button = $VictoryScreen/VBoxContainer/NextLevelButton

# Config for the Pips
var pip_size = Vector2(15, 20) # Size of one health block
var health_color = Color("c30010") # Green
var empty_color = Color("222222") # Dark Grey background for empty pips
var flash_color = Color("ff7f7f") # Light Red for damage

var last_health: int = -1

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	score_label.text = "Score: 0"
	
	death_screen.visible = false
	victory_screen.visible = false
	
	restart_button.pressed.connect(_on_restart_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

func update_health(current: int, max_hp: int) -> void:
	# 1. SETUP PIPS (Only runs once or if max HP changes)
	if health_container.get_child_count() != max_hp:
		rebuild_pips(max_hp)

	# 2. CHECK FOR DAMAGE (Flash Effect)
	if last_health != -1 and current < last_health:
		trigger_damage_flash()
	
	last_health = current

	# 3. UPDATE VISUALS
	for i in range(max_hp):
		var pip = health_container.get_child(i)
		# Index starts at 0. If health is 3, indices 0, 1, 2 are filled.
		if i < current:
			pip.color = health_color
		else:
			pip.color = empty_color

func rebuild_pips(count: int) -> void:
	# Clear old pips
	for child in health_container.get_children():
		child.queue_free()
	
	# Create new ones
	for i in range(count):
		var pip = ColorRect.new()
		pip.custom_minimum_size = pip_size
		pip.color = health_color
		health_container.add_child(pip)

func trigger_damage_flash() -> void:
	# Create a tween to flash the entire container Light Red
	var tween = create_tween()
	health_container.modulate = flash_color
	tween.tween_property(health_container, "modulate", Color.WHITE, 0.2)

# --- GAME OVER / VICTORY LOGIC ---
func show_game_over() -> void:
	final_score_label.text = "Final Score: " + str(GameManager.score)
	death_screen.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.score = 0
	get_tree().reload_current_scene()

func show_victory() -> void:
	victory_score_label.text = "Total Score: " + str(GameManager.score)
	victory_screen.visible = true
	get_tree().paused = true

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	print("Loading Next Level...")
	get_tree().reload_current_scene()

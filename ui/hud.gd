extends CanvasLayer

@onready var score_label = $Control/VBoxContainer/ScoreLabel
@onready var health_bar = $Control/HealthBar


func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	score_label.text = "Score: 0"

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)

# --- NEW FUNCTION ---
func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

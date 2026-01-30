extends CanvasLayer

@onready var score_label = $Control/ScoreLabel

func _ready() -> void:
	# Connect to the global signal
	GameManager.score_updated.connect(_on_score_updated)
	score_label.text = "Score: 0"

func _on_score_updated(new_score: int) -> void:
	# We must convert the integer 'new_score' to a string and add it
	score_label.text = "Score: " + str(new_score)

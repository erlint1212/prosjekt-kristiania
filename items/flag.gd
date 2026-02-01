extends Area2D

signal level_completed

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Goal Reached!")
		level_completed.emit()
		# Optional: Play a sound or animation here

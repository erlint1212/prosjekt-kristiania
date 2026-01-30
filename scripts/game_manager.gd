extends Node

signal score_updated(new_score)

var score: int = 0
var current_level_index: int = 0

func add_score(points: int):
	score += points
	score_updated.emit(score)

func change_scene(scene_path: String):
	# In Godot 4.6, call_deferred is still best practice for changing scenes safely
	call_deferred("_deferred_change_scene", scene_path)

func _deferred_change_scene(path: String):
	get_tree().change_scene_to_file(path)

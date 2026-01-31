extends GPUParticles2D

func _ready() -> void:
	# Force the particles to start immediately
	one_shot = true
	emitting = true
	restart()
	
	print("Boom! Effect Spawned.") # Debug line
	
	await finished
	queue_free()

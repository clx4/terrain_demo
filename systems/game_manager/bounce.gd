extends Label

var velocity = Vector2(200, 150)  # pixels per second

func _process(delta: float) -> void:
	position += velocity * delta
	
	# Get the screen size minus the label size to get the bounds
	var screen = get_viewport_rect().size
	var size = get_rect().size
	
	# Bounce off left and right
	if position.x <= 0:
		position.x = 0
		velocity.x = abs(velocity.x)
	elif position.x + size.x >= screen.x:
		position.x = screen.x - size.x
		velocity.x = -abs(velocity.x)
	
	# Bounce off top and bottom
	if position.y <= 0:
		position.y = 0
		velocity.y = abs(velocity.y)
	elif position.y + size.y >= screen.y:
		position.y = screen.y - size.y
		velocity.y = -abs(velocity.y)

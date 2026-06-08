extends ColorRect

var hue = Color("4B2E83").h  # start at your purple's hue
var speed = 0.05  # how fast the hue shifts

func _ready() -> void:
	color = Color("4B2E83")

func _process(delta: float) -> void:
	hue += speed * delta
	if hue > 1.0:
		hue -= 1.0  # wrap back around
	color = Color.from_hsv(hue, color.s, color.v)

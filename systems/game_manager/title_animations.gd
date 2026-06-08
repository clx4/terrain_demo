extends CanvasLayer

@onready var label2 = $Label2
@onready var label3 = $Label3

func _ready() -> void:
	#scale_label(label2)
	scale_label(label3)

func scale_label(label: Label) -> void:
	while true:
		var tween = create_tween()
		tween.tween_property(label, "scale", Vector2(1.2, 1.2), 1.5).set_trans(Tween.TRANS_SINE)
		await tween.finished
		tween = create_tween()
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
		await tween.finished

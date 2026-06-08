extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")

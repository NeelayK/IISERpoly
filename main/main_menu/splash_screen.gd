extends CanvasLayer

func _ready():
	$Logo.modulate.a = 0
	var tween = create_tween()
	tween.tween_property($Logo, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.2)
	tween.tween_property($Logo, "modulate:a", 0.0, 0.5)
	# Go to Main Menu
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://main/main_menu/main_menu.tscn"))
	

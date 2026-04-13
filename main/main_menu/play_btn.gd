extends Button

func _ready() -> void:
	while true:
		await get_tree().create_timer(1.0 if modulate.a==1.0 else 0.75).timeout
		modulate.a = 1.0 if modulate.a<=0.5 else 0.4

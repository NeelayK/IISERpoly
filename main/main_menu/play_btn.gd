extends Button

@export var color1 = Color("00bbdfff")
@export var color2 = Color.WHITE

func _ready() -> void:
	var i := true
	
	while true:
		await get_tree().create_timer(0.75 if i else 1.0).timeout
		add_theme_color_override("font_color",color2 if i else color1)
		i = !i

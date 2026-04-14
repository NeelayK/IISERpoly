extends CanvasLayer
var is_mobile = OS.has_feature("mobile")

func _ready() -> void:
	if is_mobile:
		queue_free()

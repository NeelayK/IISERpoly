extends Node3D


func _ready():
	get_tree().root.content_scale_factor = GameConfig.new_scale

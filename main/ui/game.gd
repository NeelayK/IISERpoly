extends Node3D
#const port = 11008
func _ready():
	get_tree().root.content_scale_factor = GameConfig.new_scale
	var sync_node = get_tree().root.find_child("Sync", true, false)
	if sync_node:
		sync_node._initialize()

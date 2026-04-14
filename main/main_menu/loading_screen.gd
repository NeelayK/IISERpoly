extends Control

var target_scene = "res://main/board_items/game.tscn"
var progress = []

func _ready():
	ResourceLoader.load_threaded_request(target_scene)

func _process(_delta):
	var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	# Update your ProgressBar node
	$ProgressBar.value = progress[0] * 100
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var new_scene = ResourceLoader.load_threaded_get(target_scene)
		get_tree().change_scene_to_packed(new_scene)

extends Node3D
signal dice_result(val1, val2)

@export var dice_scene : PackedScene
var dice1
var dice2
var results = []
var is_rolling = false

func _ready():
	dice1 = dice_scene.instantiate()
	dice2 = dice_scene.instantiate()
	add_child(dice1)
	add_child(dice2)
	
	dice1.roll_finished.connect(_on_die_finished)
	dice2.roll_finished.connect(_on_die_finished)
	dice1.freeze = true
	dice2.freeze = true
	
	dice1.position = Vector3(-0.7, 0.5, 0)
	dice2.position = Vector3(0.7, 0.5, 0)

func roll_dice():
	print("roll_dice")
	if is_rolling: return
	is_rolling = true
	results.clear()
	
	var slot1 = Vector3(-0.7, 0.5, 0) 
	var slot2 = Vector3(0.7, 0.5, 0)
	
	dice1.roll(slot1, slot1)
	dice2.roll(slot2, slot2)

func _on_die_finished(value):
	print("_on_die_finished")
	results.append(value)
	if results.size() == 2:
		is_rolling = false
		dice_result.emit(results[0], results[1])
		#dice_result.emit(2,1)

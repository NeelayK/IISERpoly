extends Node3D

signal dice_result(val1, val2)

@export var dice_scene: PackedScene

var dice1
var dice2
var die1_result := -1
var die2_result := -1
var is_rolling   := false

const SAFETY_TIMEOUT := 3.0

func _ready():
	dice1 = dice_scene.instantiate()
	dice2 = dice_scene.instantiate()
	add_child(dice1)
	add_child(dice2)
	
	dice1.roll_finished.connect(_on_die1_finished)
	dice2.roll_finished.connect(_on_die2_finished)

	dice1.freeze = true
	dice2.freeze = true
	dice1.position = Vector3(-0.7, 0.5, 0)
	dice2.position = Vector3( 0.7, 0.5, 0)


func roll_dice():
	if is_rolling: return
	is_rolling  = true
	die1_result = -1
	die2_result = -1

	var slot1 = Vector3(-0.7, 0.5, 0)
	var slot2 = Vector3( 0.7, 0.5, 0)
	dice1.roll(slot1, slot1)
	dice2.roll(slot2, slot2)

	_safety_timeout()


func _on_die1_finished(value: int) -> void:
	if die1_result != -1: return
	die1_result = value
	_try_emit()


func _on_die2_finished(value: int) -> void:
	if die2_result != -1: return
	die2_result = value
	_try_emit()


func _try_emit() -> void:
	if die1_result == -1 or die2_result == -1: return
	if not is_rolling: return

	is_rolling = false
	print("Both dice finished. Emitting result: ", die1_result, " ", die2_result)
	dice_result.emit(die1_result, die2_result)
	#dice_result.emit(7,0)

func _safety_timeout() -> void:
	await get_tree().create_timer(SAFETY_TIMEOUT).timeout
	if not is_rolling: return

	push_warning("DiceController: safety timeout — forcing result.")
	if die1_result == -1: die1_result = dice1.get_top_face()
	if die2_result == -1: die2_result = dice2.get_top_face()
	is_rolling = false
	dice_result.emit(die1_result, die2_result)

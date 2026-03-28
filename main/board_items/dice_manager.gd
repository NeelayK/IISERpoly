extends Node3D

signal dice_result(val1, val2)

var is_rolling   := false

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
func roll_dice():
	_try_emit()


func _try_emit() -> void:
	dice_result.emit(rng.randi_range(1, 6),rng.randi_range(1, 6))

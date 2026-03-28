extends Node3D

@export var move_speed := 6.0
var current_tile := 0

signal move_finished
signal passed_go

var negative_dice := false
var is_in_jail := false
var jail_turns := 0
var is_ai := false
var skip_turn = false
var jail_free_cards := 0
var is_bankrupt := false
var player_name = ""
var money := 1500
var next_rent_free : bool = false
var properties = []
var player_index: int = 0 

func move_steps(steps: int, board_tiles: Array):
	if steps == 0: return
	
	var direction = 1 if steps > 0 else -1
	var absolute_steps = abs(steps)
	var tile_count = board_tiles.size()

	# Calculate passing GO instantly
	for i in range(absolute_steps):
		var prev_tile = current_tile
		current_tile = (current_tile + direction + tile_count) % tile_count
		
		if direction == 1 and current_tile < prev_tile and not is_in_jail:
			money += 200
			passed_go.emit()
			
	# Instantly teleport to final position
	var target_tile = board_tiles[current_tile]
	global_position = target_tile.global_position + Vector3(0, 0.1, 0)
		
	move_finished.emit()

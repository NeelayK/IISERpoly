extends Node3D

@export var move_speed := 6.0
var current_tile := 0
var moving := false

signal passed_go

var negative_dice := false
var is_in_jail := false
var jail_turns := 0
var jail_free_cards := 0
var is_bankrupt := false
var player_name = ""
var money := 10
var next_rent_free : bool = false
var properties = []

# called in other functions to move 
func move_steps(steps: int, board_tiles: Array):
	if moving or steps == 0:
		return
	moving = true
	var direction = 1 if steps > 0 else -1
	var absolute_steps = abs(steps)
	var tile_count = board_tiles.size()

	for i in range(absolute_steps):
		var prev_tile = current_tile
		current_tile = (current_tile + direction + tile_count) % tile_count
		
		if direction == 1:
			if current_tile < prev_tile and not is_in_jail:
				money += 200
				passed_go.emit()
		var target_tile = board_tiles[current_tile]
		var target_pos = target_tile.global_position + Vector3(0, 0.1, 0)
		await jump_to(target_pos)
		
	moving = false

#helper function to jump to a tile
func jump_to(target:Vector3):
	var start = global_position
	var mid = (start + target) / 2
	mid.y += 0.6
	var tween = create_tween()
	tween.tween_property(self, "global_position", mid, 0.15)
	tween.tween_property(self, "global_position", target, 0.15)
	await tween.finished

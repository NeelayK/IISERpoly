extends Node3D

@export var move_speed := 6.0
var current_tile := 0
var moving := false

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

func get_visual_offset() -> Vector3:
	var total_slots = 6.0
	var radius = 0.45 
	var angle = player_index * (TAU / total_slots) 
	
	return Vector3(cos(angle) * radius, 0, sin(angle) * radius)

func relocate_on_tile(tile_global_pos: Vector3, offset: Vector3):
	var final_pos = tile_global_pos + Vector3(0, 0.1, 0) + offset
	
	if GameConfig.is_training:
		self.global_position = final_pos
		return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", final_pos, 0.25)


# Helper function with Squash and Stretch
func jump_to(target: Vector3):
	var start = global_position
	var mid = (start + target) / 2
	mid.y += 0.6
	var arc_tween = create_tween()
	arc_tween.tween_property(self, "global_position", mid, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	arc_tween.tween_property(self, "global_position", target, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	await arc_tween.finished
	


func move_steps(steps: int, board_tiles: Array):
	if moving or steps == 0: return
	moving = true
	var direction = 1 if steps > 0 else -1
	if GameConfig.is_training:
		var prev_tile = current_tile
		current_tile = (current_tile + steps + board_tiles.size()) % board_tiles.size()
		
		if direction == 1 and current_tile < prev_tile and not is_in_jail:
			money += 200
			passed_go.emit()
			
		self.global_position = board_tiles[current_tile].global_position + Vector3(0, 0.1, 0)
		moving = false
		move_finished.emit()
		return
	var absolute_steps = abs(steps)
	var tile_count = board_tiles.size()

	for i in range(absolute_steps):
		var prev_tile = current_tile
		current_tile = (current_tile + direction + tile_count) % tile_count
		
		if direction == 1 and current_tile < prev_tile and not is_in_jail:
			money += 200
			passed_go.emit()
				
		var target_tile = board_tiles[current_tile]
		var center_pos = target_tile.global_position + Vector3(0, 0.1, 0)
		target_tile.set_highlight(true, Color(0.6, 0.8, 1.0))
		
		await jump_to(center_pos)
		
		target_tile.set_highlight(false)
		
	moving = false
	move_finished.emit()

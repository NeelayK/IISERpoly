extends Node3D

@onready var camera = $Camera3D
@onready var dice_anchor = $DiceAnchor
@onready var player_anchor = $PlayerAnchor

@export var pan_speed := 0.03
@export var zoom_speed := 10.0

var tracked_player : Node3D = null
var pan_mode := true
var is_transitioning := false
var is_rotating_pan := false

var pan_target := Vector3.ZERO
var pan_offset := Vector3(0, 3.0, 4.0) 
var yaw_target := 0.0
var yaw_current := 0.0

func show_dice(dice_center := Vector3.ZERO):
	pan_mode = false
	tracked_player = null
	is_transitioning = true
	
	var rotated_offset = Vector3(0, 5.0, 4.0).rotated(Vector3.UP, yaw_current)
	var target_pos = dice_center + rotated_offset
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, 1)
	
	var dummy = Node3D.new()
	add_child(dummy)
	dummy.global_position = target_pos
	dummy.look_at(dice_center, Vector3.UP)
	tween.parallel().tween_property(self, "global_rotation", dummy.global_rotation, 1)
	
	await tween.finished
	dummy.queue_free()
	is_transitioning = false

func look_at_player(player):
	pan_mode = false
	tracked_player = player
	is_transitioning = true
	
	var flat_pos = Vector3(player.global_position.x, 0, player.global_position.z)
	var cardinal_dir = get_cardinal_dir(flat_pos)
	var target_pos = flat_pos + (cardinal_dir * 2.5) + Vector3(0, 2.0, 0)
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, 0.8)
	
	var dummy = Node3D.new()
	add_child(dummy)
	dummy.global_position = target_pos
	dummy.look_at(flat_pos, Vector3.UP)
	tween.parallel().tween_property(self, "global_rotation", dummy.global_rotation, 0.8)
	
	await tween.finished
	dummy.queue_free()
	is_transitioning = false

func enable_tabletop_pan(start_pos := Vector3.ZERO):
	pan_mode = true
	tracked_player = null
	pan_target = start_pos

func _process(delta):
	camera.position = camera.position.lerp(Vector3.ZERO, 5.0 * delta)
	camera.rotation = camera.rotation.lerp(Vector3.ZERO, 5.0 * delta)

	if tracked_player and not is_transitioning:
		_process_player_tracking(delta)
	elif pan_mode and not is_transitioning:
		_process_tabletop_panning(delta)

func get_cardinal_dir(pos: Vector3) -> Vector3:
	if abs(pos.x) > abs(pos.z):
		return Vector3(sign(pos.x), 0, 0)
	else:
		return Vector3(0, 0, sign(pos.z))

func _process_player_tracking(delta):
	var flat_player_pos = Vector3(tracked_player.global_position.x, 0, tracked_player.global_position.z)
	
	var cardinal_dir = get_cardinal_dir(flat_player_pos)
	if cardinal_dir.length() < 0.1:
		cardinal_dir = Vector3(0, 0, 1)
		
	var target_pos = flat_player_pos + (cardinal_dir * 2.5) + Vector3(0, 2, 0)
	global_position = global_position.lerp(target_pos, 2.0 * delta)
	
	var target_transform = global_transform.looking_at(flat_player_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, 5.0 * delta)

func _process_tabletop_panning(delta):
	yaw_current = lerp_angle(yaw_current, yaw_target, 6.0 * delta)
	
	var rotated_offset = pan_offset.rotated(Vector3.UP, yaw_current)
	var target_pos = pan_target + rotated_offset
	
	global_position = global_position.lerp(target_pos, 8.0 * delta)
	
	var target_transform = global_transform.looking_at(pan_target, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, 8.0 * delta)

func rotate_pan(drag_direction: float):
	is_rotating_pan = true
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	var angle = sign(drag_direction) * (PI / 2.0)
	var new_yaw = yaw_target + angle
	tween.tween_property(self, "yaw_target", new_yaw, 0.6)
	
	var rotated_target = pan_target.rotated(Vector3.UP, angle)
	tween.tween_property(self, "pan_target", rotated_target, 0.6)
	
	await tween.finished
	is_rotating_pan = false

func _input(event):
	if not pan_mode or is_transitioning: 
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var right = global_transform.basis.x
		var forward = global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var pan_move = -right * event.relative.x * pan_speed - forward * event.relative.y * pan_speed
		var new_target = pan_target + pan_move
		
		var clamped_target = Vector3(
			clamp(new_target.x, -7.5, 7.5),
			new_target.y,
			clamp(new_target.z, -7.5, 7.5)
		)

		if clamped_target != new_target and not is_rotating_pan:
			if abs(event.relative.x) > abs(event.relative.y) and abs(event.relative.x) > 6.0:
				rotate_pan(-event.relative.x)

		pan_target = clamped_target

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			pan_offset.y -= zoom_speed * 0.1
			pan_offset.z -= zoom_speed * 0.1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pan_offset.y += zoom_speed * 0.1
			pan_offset.z += zoom_speed * 0.1
			
		pan_offset.y = clamp(pan_offset.y, 3.0, 7.5)
		pan_offset.z = clamp(pan_offset.z, 2.0, 7.0)

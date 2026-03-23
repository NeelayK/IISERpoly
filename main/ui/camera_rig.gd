extends Node3D

@onready var camera = $Camera3D
@onready var dice_anchor = $DiceAnchor
@onready var player_anchor = $PlayerAnchor

@export var mouse_pan_sensitivity := 0.3
@export var pan_speed := 0.03
@export var zoom_speed := 10.0
@export var zoom_sensitivity := 0.5

var rotation_threshold:=20
var tracked_player : Node3D = null
var pan_mode := true
var is_transitioning := false
var is_rotating_pan := false

var pan_target := Vector3.ZERO
var pan_offset := Vector3(0, 3.0, 4.0) 
var yaw_target := 0.0
var yaw_current := 0.0

func _ready():
	if GameConfig.is_training:
		set_process(false)       # Stops _process(delta) from running
		set_process_input(false) # Stops _input(event) from running
		return    

#switch focus to dice while maintaing yaw
func show_dice(dice_center := Vector3.ZERO):
	if GameConfig.is_training: return
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

#switch focus to player
func look_at_player(player):
	if GameConfig.is_training: return
	pan_mode = false
	tracked_player = player
	is_transitioning = true
	var flat_pos = Vector3(player.global_position.x, 0, player.global_position.z)
	var cardinal_dir = get_cardinal_dir(flat_pos)
	var target_pos = flat_pos + (cardinal_dir * 2.5) + Vector3(0, 2.0, 0)
	var target_transform = Transform3D.IDENTITY
	target_transform.origin = target_pos
	target_transform = target_transform.looking_at(flat_pos, Vector3.UP)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_transform", target_transform, 0.8)
	await tween.finished
	is_transitioning = false

func enable_tabletop_pan(start_pos := Vector3.ZERO): #switch to tabletop pan
	pan_mode = true
	tracked_player = null
	pan_target = start_pos

func _input(event):
	if not pan_mode or is_transitioning: 
		return

	# --- 1. Panning (Mouse Right-Drag OR Mobile Finger-Drag) ---
	var is_mouse_drag = event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var is_touch_drag = event is InputEventScreenDrag
	
	if is_mouse_drag or is_touch_drag:
		var right = global_transform.basis.x
		var forward = global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		# Mobile touch usually needs higher sensitivity than a mouse
		var final_sens = mouse_pan_sensitivity
		if is_touch_drag:
			final_sens *= 2.5 
		
		var pan_move = -right * event.relative.x * pan_speed * final_sens \
					   - forward * event.relative.y * pan_speed * final_sens
		
		var new_target = pan_target + pan_move
		
		# Keep camera within board limits
		var clamped_target = Vector3(
			clamp(new_target.x, -7.5, 7.5),
			new_target.y,
			clamp(new_target.z, -7.5, 7.5)
		)

		# Auto-Rotate when hitting the "edges" of the screen while dragging
		if clamped_target != new_target and not is_rotating_pan:
			if abs(event.relative.x) > abs(event.relative.y) and abs(event.relative.x) > rotation_threshold:
				rotate_pan(-event.relative.x)

		pan_target = clamped_target

	if event.is_action_pressed("zoom_in"):
		pan_offset.y = clamp(pan_offset.y - (zoom_speed * zoom_sensitivity * 0.1), 3.0, 7.5)
		pan_offset.z = clamp(pan_offset.z - (zoom_speed * zoom_sensitivity * 0.1), 2.0, 7.0)
	
	if event.is_action_pressed("zoom_out"):
		pan_offset.y = clamp(pan_offset.y + (zoom_speed * zoom_sensitivity * 0.1), 3.0, 7.5)
		pan_offset.z = clamp(pan_offset.z + (zoom_speed * zoom_sensitivity * 0.1), 2.0, 7.0)

func _process(delta):
	camera.position = camera.position.lerp(Vector3.ZERO, 5.0 * delta)
	camera.rotation = camera.rotation.lerp(Vector3.ZERO, 5.0 * delta)
	
	if tracked_player and not is_transitioning:
		_process_player_tracking(delta)
	elif pan_mode and not is_transitioning:
		_process_tabletop_panning(delta)

func get_cardinal_dir(pos: Vector3) -> Vector3: #helper function to get board direction
	if abs(pos.x) > abs(pos.z):
		return Vector3(sign(pos.x), 0, 0)
	else:
		return Vector3(0, 0, sign(pos.z))

func _process_player_tracking(delta): #calculate player tracking
	var flat_player_pos = Vector3(tracked_player.global_position.x, 0, tracked_player.global_position.z)
	var cardinal_dir = get_cardinal_dir(flat_player_pos)
	if cardinal_dir.length() < 0.1:
		cardinal_dir = Vector3(0, 0, 1)
	var target_pos = flat_player_pos + (cardinal_dir * 2.5) + Vector3(0, 2, 0)
	global_position = global_position.lerp(target_pos, 2.0 * delta)
	var target_transform = global_transform.looking_at(flat_player_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, 5.0 * delta)

func _process_tabletop_panning(delta): #Calculate tabletop tracking
	yaw_current = lerp_angle(yaw_current, yaw_target, 6.0 * delta)
	var rotated_offset = pan_offset.rotated(Vector3.UP, yaw_current)
	var target_pos = pan_target + rotated_offset
	global_position = global_position.lerp(target_pos, 8.0 * delta)
	var target_transform = global_transform.looking_at(pan_target, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, 8.0 * delta)

func rotate_pan(drag_direction: float): #calculates rotation at corners
	is_rotating_pan = true
	
	var angle = sign(drag_direction) * deg_to_rad(90) 
	var new_yaw = yaw_target + angle
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "yaw_target", new_yaw, 0.5)
	
	await tween.finished
	is_rotating_pan = false

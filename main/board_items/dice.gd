extends RigidBody3D

signal roll_finished(value)

@export var centering_force: float = 5.0
var target_pos: Vector3 = Vector3.ZERO
var rolling = false
var stable_frames = 0 

var needs_teleport = false
var teleport_pos = Vector3.ZERO

var face_values = {
	Vector3.UP: 6, Vector3.DOWN: 5,
	Vector3.LEFT: 3, Vector3.RIGHT: 1,
	Vector3.FORWARD: 2, Vector3.BACK: 4
}

func roll(start_pos: Vector3, final_target_pos: Vector3):
	target_pos = final_target_pos
	teleport_pos = start_pos
	
	freeze = false
	sleeping = false 

	needs_teleport = true
	rolling = true
	stable_frames = 0

func _integrate_forces(state):
	if needs_teleport:
		state.transform.origin = teleport_pos
		state.transform.basis = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		state.apply_central_impulse(Vector3(randf_range(-1, 1), 5.0, randf_range(-1, 1)))
		state.apply_torque_impulse(Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)))
		needs_teleport = false
		return
		
	if not rolling: return
	var dir = (target_pos - state.transform.origin)
	dir.y = 0 
	var dist = dir.length()
	
	if dist > 0.1:
		var pull_strength = clamp(dist, 0.0, 2.0)
		state.apply_central_force(dir.normalized() * centering_force * pull_strength)

	if state.linear_velocity.length() < 0.2 and state.angular_velocity.length() < 0.2:
		stable_frames += 1
		if stable_frames > 20:
			call_deferred("finalize_roll") 
	else:
		stable_frames = 0

func finalize_roll():
	if not rolling: return
	rolling = false
	freeze = true 
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_pos, 0.3)
	
	var snapped_rot = Vector3(
		round(rotation_degrees.x / 90.0) * 90.0,
		round(rotation_degrees.y / 90.0) * 90.0,
		round(rotation_degrees.z / 90.0) * 90.0
	)
	tween.tween_property(self, "rotation_degrees", snapped_rot, 0.3)
	
	await tween.finished
	emit_signal("roll_finished", get_top_face())

func get_top_face():
	var best_dot = -1.0
	var best_face = 1
	for dir in face_values.keys():
		var world_dir = global_transform.basis * dir
		var d = world_dir.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_face = face_values[dir]
	return best_face

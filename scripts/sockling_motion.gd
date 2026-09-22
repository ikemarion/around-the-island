extends RefCounted
## Cosmetic puppet posing only. No input, root motion, timers or physics writes
## on the player. The same poses work with observed host or replica movement.
const SOLE_Y := -0.82
var model: Node3D
var state: StringName = &"idle"
var stride_phase := 0.0
var clock := 0.0
var gait := 0.0
var speed := 0.0
var carry := 0.0
var crouch := 0.0
var slide := 0.0
var stun := 0.0
var air := 0.0
var turn := 0.0
var landing := 0.0
var launch := 0.0
var air_duration := 0.0
var impact := 0.0
var fall_speed := 0.0
var was_airborne := false
var initialized := false
var foot_vertices: Array[PackedVector3Array] = []
var foot_deltas: Array[PackedVector3Array] = []
var shoulder_springs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var elbow_springs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var wrist_springs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

func _init(puppet: Node3D) -> void:
	model = puppet
	# Cache sole samples once. Support the deformed foot instead of letting
	# every hip swing bury the toe in the floor; no per-frame mesh readback.
	for leg in model.leg_meshes:
		var points := PackedVector3Array()
		var changes := PackedVector3Array()
		for surface in leg.mesh.get_surface_count():
			var base: PackedVector3Array = leg.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var morph: PackedVector3Array = leg.mesh.surface_get_blend_shape_arrays(surface)[0][Mesh.ARRAY_VERTEX]
			for index in range(0,base.size(),maxi(1,base.size()/128)):
				if base[index].y > -0.20: continue
				points.append(base[index])
				# GLTF imports normalized (absolute-position) blend targets.
				changes.append(morph[index]-base[index] if leg.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else morph[index])
		foot_vertices.append(points)
		foot_deltas.append(changes)

func reset() -> void:
	initialized = false
	was_airborne = false
	landing = 0.0
	launch = 0.0
	air_duration = 0.0
	fall_speed = 0.0
	air = 0.0
	gait = 0.0
	speed = 0.0
	turn = 0.0
	carry = 0.0
	crouch = 0.0
	slide = 0.0
	stun = 0.0
	stride_phase = 0.0
	state = &"idle"
	model.position = Vector3.ZERO
	model.scale = Vector3.ONE
	model.chest.position = Vector3.ZERO
	model.chest.rotation = Vector3.ZERO
	model.head.rotation = Vector3.ZERO
	for i in 2:
		shoulder_springs[i] = Vector2.ZERO
		elbow_springs[i] = Vector2.ZERO
		wrist_springs[i] = Vector2.ZERO
		model.arms[i].rotation = Vector3.ZERO
		model.legs[i].rotation = Vector3.ZERO
		model.legs[i].position.y = -0.41
		model.arm_skeletons[i].reset_bone_poses()
		model.leg_meshes[i].set_blend_shape_value(0,0)

func foot_bottom(index: int, basis: Basis, flex: float) -> float:
	var bottom := 1.0
	for i in foot_vertices[index].size():
		bottom = minf(bottom,(basis*(foot_vertices[index][i]+foot_deltas[index][i]*flex)).y)
	return bottom

func spring(value: Vector2, target: float, frequency: float, dt: float) -> Vector2:
	# Analytic critically damped spring: angle/velocity, stable at low FPS,
	# soft follow-through without overshoot or frame-rate-specific integration.
	var offset := value.x - target
	var step := (value.y + frequency * offset) * dt
	var decay := exp(-frequency * dt)
	return Vector2(target + (offset + step) * decay, (value.y - frequency * step) * decay)

func pose_arm(index: int, dt: float, run: float, rise: float, landing_pulse: float) -> void:
	var side := -1.0 if index == 0 else 1.0
	# A continuous pendulum rather than copying the foot's stance/swing curve.
	# The arm travels opposite its leg, with a delayed elbow and trailing wrist.
	var cycle := stride_phase + index * PI
	var swing := cos(cycle + 0.12)
	var pitch := swing * lerpf(0.40, 0.76, run) * gait
	pitch += sin(clock * 1.7 + index * 0.7) * 0.018 * (1.0 - gait)
	var spread := side * (0.055 + run * gait * 0.028 + absf(turn) * 0.018)
	var elbow_angle := 0.18 + run * gait * 0.36 + (0.5 - 0.5 * cos(cycle - 0.4)) * 0.18 * gait
	pitch = lerpf(pitch, -0.10 - rise * 0.27, air)
	spread = lerpf(spread, side * (0.18 + (1.0 - rise) * 0.08), air)
	elbow_angle = lerpf(elbow_angle, 0.40 + rise * 0.22, air)
	pitch += landing_pulse * 0.14
	pitch = lerpf(pitch, 0.24, slide)
	spread = lerpf(spread, side * 0.22, slide)
	elbow_angle = lerpf(elbow_angle, 0.32, slide)
	# Bring the hands forward around a held prop instead of lifting a T-pose.
	pitch = lerpf(pitch, -0.78, carry)
	spread = lerpf(spread, -side * 0.035, carry)
	elbow_angle = lerpf(elbow_angle, 0.82, carry)
	pitch += sin(clock * 12.0 + index) * stun * 0.055
	shoulder_springs[index] = spring(shoulder_springs[index], pitch, 22.0, dt)
	elbow_springs[index] = spring(elbow_springs[index], elbow_angle, 18.0, dt)
	var wrist_target := clampf(-shoulder_springs[index].y * 0.024 + elbow_springs[index].y * 0.014, -0.22, 0.22)
	wrist_target = lerpf(wrist_target, -0.045, carry)
	wrist_springs[index] = spring(wrist_springs[index], wrist_target, 15.0, dt)
	var arm: Node3D = model.arms[index]
	arm.rotation = Vector3(shoulder_springs[index].x,
		lerpf(arm.rotation.y, -side * carry * 0.08 - turn * 0.016, 1.0 - exp(-10.0 * dt)),
		lerpf(arm.rotation.z, spread, 1.0 - exp(-12.0 * dt)))
	var skeleton: Skeleton3D = model.arm_skeletons[index]
	skeleton.set_bone_pose_rotation(1, Quaternion(Vector3.RIGHT, -elbow_springs[index].x))
	skeleton.set_bone_pose_rotation(2, Quaternion.from_euler(Vector3(wrist_springs[index].x, 0, -side * sin(clock * 1.7 + index) * 0.018 * (1.0 - gait) * (1.0 - carry))))

func update(delta: float, measured_speed: float, holding: bool, airborne: bool, stunned: bool, vertical_speed := 0.0, crouched := false, sliding := false, turn_rate := 0.0) -> void:
	# Sample the moving spring targets at a bounded interval. An analytic spring
	# alone is stable, but sampling a fast pendulum only once at 30 FPS changes
	# its phase relative to 144 FPS. Substeps keep the same motion on both clients.
	var elapsed := clampf(delta, 0.0, 0.10)
	var steps := maxi(1, ceili(elapsed * 120.0))
	for step in steps:
		_step(elapsed / steps, measured_speed, holding, airborne, stunned, vertical_speed, crouched, sliding, turn_rate)

func _step(delta: float, measured_speed: float, holding: bool, airborne: bool, stunned: bool, vertical_speed: float, crouched: bool, sliding: bool, turn_rate: float) -> void:
	var dt := clampf(delta,0.0,0.10)
	var blend := 1.0-exp(-14.0*dt)
	clock = fmod(clock+dt,3600.0)
	if not initialized:
		was_airborne = airborne
		initialized = true
	if airborne and not was_airborne:
		air_duration = 0.0
		fall_speed = 0.0
		# Quick compression/stretch on takeoff; never delay the actual jump.
		launch = 0.18 if vertical_speed > 1.0 else 0.0
	if not airborne and was_airborne and air_duration > 0.07:
		landing = 0.32
		impact = clampf(absf(fall_speed)/11.0,0.25,1.0)
	was_airborne = airborne
	if airborne:
		air_duration += dt
		fall_speed = minf(fall_speed,vertical_speed)
	landing = maxf(landing-dt,0.0)
	launch = maxf(launch-dt,0.0)
	speed = lerpf(speed,clampf(measured_speed,0,22),1.0-exp(-10.0*dt))
	gait = lerpf(gait,clampf(speed/1.4,0,1) if not airborne and not stunned and not sliding else 0.0,blend)
	carry = lerpf(carry,float(holding),blend)
	crouch = lerpf(crouch,float(crouched),blend)
	slide = lerpf(slide,float(sliding),blend)
	stun = lerpf(stun,float(stunned),blend)
	air = lerpf(air,float(airborne),blend)
	turn = lerpf(turn,clampf(turn_rate,-4,4),1.0-exp(-8.0*dt))
	var run := smoothstep(3.5,9.5,speed)
	var cycle_length := lerpf(1.9,3.7,run)
	stride_phase = fposmod(stride_phase+dt*minf(speed,14.0)*TAU/cycle_length*gait,TAU)
	state = &"idle"
	if speed > 0.2: state = &"run" if run > 0.4 else &"walk"
	if crouched: state = &"crouch"
	if landing > 0.0: state = &"land"
	if airborne: state = &"rise" if vertical_speed > 0.6 else &"fall"
	if sliding: state = &"slide"
	if stunned: state = &"stun"
	var landing_pulse := sin((1.0-landing/0.32)*PI)*impact if landing > 0 else 0.0
	var takeoff := 1.0-launch/0.18
	var launch_squash := (sin(takeoff/0.25*PI)*0.10 if takeoff < 0.25 else -sin((takeoff-0.25)/0.75*PI)*0.10) if launch > 0 else 0.0
	var scale_y := 1.0-landing_pulse*0.13-launch_squash+air*clampf(vertical_speed/80.0,-0.035,0.07)
	model.scale = Vector3(1.0/sqrt(scale_y),scale_y,1.0/sqrt(scale_y))
	model.position.y = SOLE_Y*(1.0-scale_y)
	var breath := sin(clock*2.4)*0.006*(1.0-gait)
	model.chest.position = Vector3(sin(stride_phase)*0.010*gait,breath+(0.5-0.5*cos(stride_phase*2.0))*0.025*gait,0)
	var lean := run*0.13*gait+landing_pulse*0.12-slide*0.22+crouch*0.055
	var wobble := sin(clock*12.0)*0.055*stun
	# A little characterful slouch, with opposing shoulder rotation in motion.
	model.chest.rotation = model.chest.rotation.lerp(Vector3(lean+0.025,-turn*0.018+sin(stride_phase-0.15)*0.045*gait,-0.065*(1.0-gait*0.55)+sin(stride_phase)*0.030*gait-turn*0.020+wobble),blend)
	model.head.rotation = model.head.rotation.lerp(Vector3(0.10-lean*0.3+sin(stride_phase*2-0.6)*0.02*gait,-turn*0.022,-sin(stride_phase-0.6)*0.035*gait-wobble*0.5),1.0-exp(-10.0*dt))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var t := fposmod(stride_phase/TAU+i*0.5,1.0)
		var swing_t := clampf((t-0.56)/0.44,0,1)
		var stride := lerpf(-1,1,t/0.56) if t < 0.56 else cos(swing_t*PI)
		var lift := sin(swing_t*PI)*(0.07+run*0.065)*gait
		var leg_pitch := stride*lerpf(0.38,0.72,run)*gait
		var knee := (0.08+sin(swing_t*PI)*0.55)*gait+crouch*0.18
		var rise := clampf(vertical_speed/7.0,0,1)
		leg_pitch = lerpf(leg_pitch,-0.30*rise+side*0.12,air)
		knee = lerpf(knee,0.22+rise*0.6+float(i)*0.08,air)
		leg_pitch = lerpf(leg_pitch,-0.90+float(i)*0.20,slide)
		knee = lerpf(knee,0.13,slide)
		var leg: Node3D = model.legs[i]
		leg.rotation = leg.rotation.lerp(Vector3(leg_pitch,side*0.35,side*(0.045+air*0.10)),blend)
		var leg_mesh: MeshInstance3D = model.leg_meshes[i]
		var flex := lerpf(leg_mesh.get_blend_shape_value(0),clampf(knee,0,1),blend)
		leg_mesh.set_blend_shape_value(0,flex)
		var planted := SOLE_Y-foot_bottom(i,leg.basis,flex)+lift
		leg.position.y = lerpf(planted,-0.40+rise*0.02,air)
		pose_arm(i, dt, run, rise, landing_pulse)
	# The shared soft-body locomotion also serves closed-mouth characters.
	# Preserve Sockling's jaw while allowing Looper's quiet stitched smirk.
	if model.sculpt_body.mesh.get_blend_shape_count() > 0 and is_instance_valid(model.jaw):
		var mouth := clampf(0.12+run*gait*0.2+air*0.28+stun*0.18+sin(clock*3.5)*0.035,0,0.85)
		mouth = lerpf(model.sculpt_body.get_blend_shape_value(0),mouth,blend)
		model.sculpt_body.set_blend_shape_value(0,mouth)
		model.jaw.rotation.x = mouth*0.24
	# Deterministic staggered blinks; no gameplay RNG consumed.
	var blink_clock := fposmod(clock+model.blink_offset,4.1)
	var blink := sin(clampf(blink_clock/0.15,0,1)*PI) if blink_clock < 0.15 else 0.0
	for eye in model.eyes:
		eye.scale.y = 1.0-blink*0.91
	for skin in model.skin_materials:
		skin.set_shader_parameter("stunned",float(stunned))

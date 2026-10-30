extends RigidBody3D

const Geo = preload("res://scripts/geometry.gd")
const Model = preload("res://scripts/vehicle_math.gd")
const Visual = preload("res://scripts/roadster_visual.gd")
const Thrusters = preload("res://scripts/thruster_control.gd")
const JetEffect = preload("res://scripts/jet_effect.gd")
const SurfaceEffect = preload("res://scripts/surface_effect.gd")

@export var spring_rate := 42000.0
@export var damper := 4200.0
@export var tire_grip := 1.2
@export var nozzle_force := 10000.0
@export var auto_landing_enabled := false
const REST := 0.55
const RADIUS := 0.36
var fuel := 1.0
var contacts := 0
var burning := false
var steering := 0.0
var recharge_delay := 0.0
var burst_locked:=false
var charging:=false
var wheels: Array[Node3D] = []
var rays: Array[RayCast3D] = []
var jet_effect: Node3D
var wheel_spin := 0.0
var pending_reset := false
var reset_pose := Transform3D.IDENTITY
var chassis_collision: CollisionShape3D
var nozzle_duties := PackedFloat32Array([0, 0, 0, 0])
var nozzle_hits: Array[Dictionary] = []
var exhaust_hits: Array[Dictionary] = []
var jet_mode := "READY"
var landing_height := INF
var thrust_direction := Vector3.UP
var surface_provider: Node3D
var surface_label := ""
var severe_impact_speed := 0.0
var surface_effect: Node3D

static func configure_inputs() -> void:
	var keys := {"throttle": KEY_W, "brake": KEY_S, "steer_left": KEY_A, "steer_right": KEY_D, "burst": KEY_SPACE, "pitch_forward": KEY_UP, "pitch_back": KEY_DOWN, "roll_left": KEY_LEFT, "roll_right": KEY_RIGHT, "recover": KEY_R, "restart": KEY_ENTER, "pause": KEY_ESCAPE, "handbrake": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func _ready() -> void:
	configure_inputs()
	mass = 1650.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.18, 0.05)
	continuous_cd = true
	linear_damp = 0.04
	angular_damp = 0.45
	can_sleep = false
	max_contacts_reported = 8
	contact_monitor = true
	var collision := CollisionShape3D.new()
	chassis_collision = collision
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.84, 0.53, 4.22)
	collision.shape = shape
	collision.position.y = 0.16
	add_child(collision)
	Visual.build(self)
	var rim := Geo.material(Color("97a6b3"), 0.9)
	for z in [-1.36, 1.36]:
		for x in [-0.93, 0.93]:
			var ray := RayCast3D.new()
			ray.position = Vector3(x, 0, z)
			ray.target_position = Vector3(0, -(REST + RADIUS), 0)
			ray.add_exception(self)
			add_child(ray)
			rays.append(ray)
			var wheel := Node3D.new()
			wheel.position = ray.position - Vector3.UP * REST
			add_child(wheel)
			wheels.append(wheel)
			Visual.build_wheel(wheel, signf(x), RADIUS)
			Geo.cylinder(self, 0.10, 0.12, Vector3(x * 0.68, -0.19, z * 0.70), rim)
	jet_effect = JetEffect.new()
	add_child(jet_effect)
	surface_effect = SurfaceEffect.new()
	add_child(surface_effect)

func _process(_dt: float) -> void:
	if freeze or pending_reset or not visible:
		clear_jets()
	jet_effect.update_output(self)
	surface_effect.update_output(self)

func reset_to(pose: Transform3D) -> void:
	reset_pose = pose
	pending_reset = true
	clear_jets()

func clear_jets() -> void:
	nozzle_duties.fill(0)
	burning = false
	jet_mode = "READY"
	charging=false
	nozzle_hits.clear()
	exhaust_hits.clear()
	landing_height = INF
	if is_instance_valid(jet_effect):
		jet_effect.clear()
	if is_instance_valid(surface_effect):
		surface_effect.clear()

func probe_landing(state: PhysicsDirectBodyState3D) -> bool:
	nozzle_hits.clear()
	landing_height = 0.0
	var valid := 0
	for nozzle in Thrusters.NOZZLES:
		var origin: Vector3 = state.transform * nozzle
		var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * Thrusters.PROBE_LENGTH)
		query.exclude = [get_rid()]
		var hit := state.get_space_state().intersect_ray(query)
		nozzle_hits.append(hit)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP) > 0.75 and hit.collider.get_meta("landing_surface", false):
			landing_height += origin.distance_to(hit.position)
			valid += 1
	landing_height = landing_height / valid if valid > 0 else INF
	return valid >= 3

func lowest_chassis_y() -> float:
	var half: Vector3 = (chassis_collision.shape as BoxShape3D).size * 0.5
	var axes := chassis_collision.global_basis
	return chassis_collision.global_position.y - absf(axes.x.y) * half.x - absf(axes.y.y) * half.y - absf(axes.z.y) * half.z

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform = reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		pending_reset = false
		steering = 0.0
		burning = false
		recharge_delay = 0.8
		severe_impact_speed = 0
		return
	var dt := state.step
	var up := state.transform.basis.y
	var forward := -state.transform.basis.z
	var speed := state.linear_velocity.dot(forward)
	severe_impact_speed = 0
	if is_instance_valid(surface_provider):
		for i in state.get_contact_count():
			# Jolt reports world-space contact normals and pre-impact point velocities.
			var normal := state.get_contact_local_normal(i)
			var velocity := state.get_contact_local_velocity_at_position(i)-state.get_contact_collider_velocity_at_position(i)
			severe_impact_speed = maxf(severe_impact_speed,-velocity.dot(normal))
	surface_label = ""
	var steer_input := Input.get_axis("steer_right", "steer_left")
	steering = move_toward(steering, steer_input * lerpf(0.48, 0.16, clampf(absf(speed) / 65.0, 0, 1)), dt * 1.8)
	var throttle := Input.get_action_strength("throttle")
	var brake := Input.get_action_strength("brake")
	if brake > 0 and speed < 1.0:
		throttle -= brake * 0.45
		brake = 0.0
	contacts = 0
	var supported_load:=0.0
	for i in rays.size():
		var ray := rays[i]
		ray.force_raycast_update()
		var length := REST
		if ray.is_colliding():
			contacts += 1
			var hit := ray.get_collision_point()
			var normal := ray.get_collision_normal()
			length = clampf(ray.global_position.distance_to(hit) - RADIUS, 0.03, REST)
			var offset := hit - state.transform.origin
			var velocity := state.linear_velocity + state.angular_velocity.cross(offset - state.transform.basis * center_of_mass)
			var surface_grip := 1.0
			var rolling := 9.0
			if is_instance_valid(surface_provider):
				var surface: Dictionary = surface_provider.surface_at(hit)
				surface_grip = surface.grip
				rolling = surface.rolling
				surface_label = surface.label
				severe_impact_speed = maxf(severe_impact_speed,-velocity.dot(normal))
			var load_n := clampf((REST - length) * spring_rate - velocity.dot(up) * damper, 0.0, 28000.0)
			supported_load+=load_n*maxf(0,normal.dot(Vector3.UP))
			state.apply_force(up * load_n, offset)
			var wheel_forward := forward.rotated(up, steering if i < 2 else 0.0)
			wheel_forward = wheel_forward.slide(normal).normalized()
			var side := wheel_forward.cross(normal).normalized()
			var grip := tire_grip * surface_grip * (0.48 if i >= 2 and Input.is_action_pressed("handbrake") else 1.0)
			var tire_force := Model.tire_force(load_n, velocity.dot(side), velocity.dot(wheel_forward), throttle, maxf(brake, Input.get_action_strength("handbrake") if i >= 2 else 0.0), grip, rolling)
			state.apply_force(side * tire_force.x + wheel_forward * tire_force.y, offset)
		wheels[i].position = ray.position - Vector3.UP * length
		wheels[i].rotation.y = steering if i < 2 else 0.0
		wheels[i].get_node("WheelVisual").rotation.x = wheel_spin
	wheel_spin -= speed / RADIUS * dt
	var trigger_pressed:=Input.is_action_pressed("burst")
	if not trigger_pressed:
		burst_locked=false
	elif fuel<=0.0001:
		burst_locked=true
	var burst_requested := trigger_pressed and not burst_locked
	var descending := contacts == 0 and state.linear_velocity.y < -0.25
	var road_below := probe_landing(state)
	var landing := Thrusters.landing_duty(landing_height, state.linear_velocity.y, up.dot(Vector3.UP), road_below, contacts, nozzle_force * 4 / mass) if auto_landing_enabled else 0.0
	var pitch := Input.get_axis("pitch_back", "pitch_forward") if contacts == 0 else 0.0
	var roll := Input.get_axis("roll_right", "roll_left") if contacts == 0 else 0.0
	var base := 1.0 if burst_requested else landing
	var result: Dictionary = Thrusters.consume(Thrusters.duties(base, pitch, roll), fuel, dt)
	nozzle_duties = result.duties
	fuel = result.fuel
	if fuel<=0.0001 and trigger_pressed:
		burst_locked=true
	burning = false
	for duty in nozzle_duties:
		burning = burning or duty > 0.0001
	jet_mode = ("DESCENT BRAKE" if descending else "LIFT") if burst_requested else "LANDING BRAKE" if landing > 0 else "ATTITUDE" if burning else "READY"
	if not burning:
		jet_mode = "LOW PRESSURE" if fuel <= 0.15 else "READY"
	thrust_direction = (up + forward * 0.20).normalized() if burst_requested and not descending else up
	exhaust_hits.clear()
	for i in Thrusters.NOZZLES.size():
		var hit := {}
		if nozzle_duties[i] > 0.001:
			var origin: Vector3 = state.transform * Thrusters.NOZZLES[i]
			var query := PhysicsRayQueryParameters3D.create(origin, origin - thrust_direction * 3.5)
			query.exclude = [get_rid()]
			hit = state.get_space_state().intersect_ray(query)
		exhaust_hits.append(hit)
	if burning:
		for i in Thrusters.NOZZLES.size():
			state.apply_force(thrust_direction * nozzle_force * nozzle_duties[i], state.transform.basis * Thrusters.NOZZLES[i])
		recharge_delay = 0.35
	else:
		recharge_delay = maxf(0.0, recharge_delay - dt)
	charging=not burning and recharge_delay<=0 and not burst_requested and fuel<0.999 and Model.can_recharge(contacts,supported_load,up.dot(Vector3.UP),mass)
	if charging:
		fuel = Model.next_fuel(fuel, false, true, dt)
	if not burning:
		jet_mode="RELEASE SPACE" if burst_locked else "RECHARGING" if charging else "LOW PRESSURE" if fuel<=0.15 else "READY"
	state.apply_central_force(-state.linear_velocity * state.linear_velocity.length() * 0.43)

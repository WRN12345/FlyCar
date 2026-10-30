extends RigidBody3D

const Geo = preload("res://scripts/geometry.gd")
const Model = preload("res://scripts/vehicle_math.gd")

@export var spring_rate := 42000.0
@export var damper := 4200.0
@export var tire_grip := 1.2
@export var nozzle_force := 10000.0
const REST := 0.55
const RADIUS := 0.36
var fuel := 1.0
var contacts := 0
var burning := false
var steering := 0.0
var recharge_delay := 0.0
var wheels: Array[Node3D] = []
var rays: Array[RayCast3D] = []
var jets: Array[MeshInstance3D] = []
var wheel_spin := 0.0
var pending_reset := false
var reset_pose := Transform3D.IDENTITY

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
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.84, 0.53, 4.22)
	collision.shape = shape
	collision.position.y = 0.16
	add_child(collision)
	Geo.car_shell(self)
	var tire := Geo.material(Color("10141b"))
	var rim := Geo.material(Color("97a6b3"), 0.9)
	var jet_mat := Geo.material(Color("85e5ff"), 0.0, 3.0)
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
			var rubber := Geo.cylinder(wheel, RADIUS, 0.29, Vector3.ZERO, tire)
			rubber.rotation.z = PI / 2
			var metal := Geo.cylinder(wheel, 0.265, 0.305, Vector3.ZERO, rim)
			metal.rotation.z = PI / 2
			Geo.cylinder(self, 0.10, 0.12, Vector3(x * 0.68, -0.19, z * 0.70), rim)
			var jet_mesh := CylinderMesh.new()
			jet_mesh.top_radius = 0.07
			jet_mesh.bottom_radius = 0.20
			jet_mesh.height = 0.9
			var jet := Geo.mesh_node(self, jet_mesh, Vector3(x * 0.68, -0.65, z * 0.70), jet_mat)
			jet.visible = false
			jets.append(jet)

func reset_to(pose: Transform3D) -> void:
	reset_pose = pose
	pending_reset = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform = reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		pending_reset = false
		steering = 0.0
		burning = false
		recharge_delay = 0.8
		return
	var dt := state.step
	var up := state.transform.basis.y
	var forward := -state.transform.basis.z
	var speed := state.linear_velocity.dot(forward)
	var steer_input := Input.get_axis("steer_right", "steer_left")
	steering = move_toward(steering, steer_input * lerpf(0.48, 0.16, clampf(absf(speed) / 65.0, 0, 1)), dt * 1.8)
	var throttle := Input.get_action_strength("throttle")
	var brake := Input.get_action_strength("brake")
	if brake > 0 and speed < 1.0:
		throttle -= brake * 0.45
		brake = 0.0
	contacts = 0
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
			var load_n := clampf((REST - length) * spring_rate - velocity.dot(up) * damper, 0.0, 28000.0)
			state.apply_force(up * load_n, offset)
			var wheel_forward := forward.rotated(up, steering if i < 2 else 0.0)
			wheel_forward = wheel_forward.slide(normal).normalized()
			var side := wheel_forward.cross(normal).normalized()
			var grip := tire_grip * (0.48 if i >= 2 and Input.is_action_pressed("handbrake") else 1.0)
			var tire_force := Model.tire_force(load_n, velocity.dot(side), velocity.dot(wheel_forward), throttle, maxf(brake, Input.get_action_strength("handbrake") if i >= 2 else 0.0), grip)
			state.apply_force(side * tire_force.x + wheel_forward * tire_force.y, offset)
		wheels[i].position = ray.position - Vector3.UP * length
		wheels[i].rotation.y = steering if i < 2 else 0.0
		wheels[i].get_child(0).rotation.x = wheel_spin
	wheel_spin -= speed / RADIUS * dt
	var burst_requested := Input.is_action_pressed("burst")
	burning = burst_requested and fuel > 0.0001
	if burning:
		var fraction := minf(1.0, fuel * 1.2 / dt)
		for ray in rays:
			var local_nozzle := Vector3(ray.position.x * 0.68, -0.19, ray.position.z * 0.70)
			state.apply_force((up + forward * 0.20).normalized() * nozzle_force * fraction, state.transform.basis * local_nozzle)
		recharge_delay = 0.8
	else:
		recharge_delay = maxf(0.0, recharge_delay - dt)
	fuel = Model.next_fuel(fuel, burning, contacts >= 3 and recharge_delay <= 0.0 and not burst_requested, dt)
	for jet in jets:
		jet.visible = burning
	if contacts == 0:
		var pitch := Input.get_axis("pitch_back", "pitch_forward")
		var roll := Input.get_axis("roll_right", "roll_left")
		state.apply_torque(state.transform.basis.x * pitch * 2600.0 + forward * roll * 2200.0)
	state.apply_central_force(-state.linear_velocity * state.linear_velocity.length() * 0.43)

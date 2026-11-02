extends RefCounted
var yaw := 0.0
var pitch := 0.35
var distance := 11.3
var dragging := false
var obstructed := false
var safe_position := Vector3.ZERO
var _initialized := false
var _anchor := Vector3.ZERO
var _heading := Vector3.FORWARD
var _boom := 11.3
var _release_delay := 0.0
var _render_initialized := false
var _previous_pose := Transform3D.IDENTITY
var _current_pose := Transform3D.IDENTITY

func end_drag() -> void:
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset() -> void:
	end_drag()
	yaw = 0.0
	pitch = 0.35
	distance = 11.3
	obstructed = false
	_initialized = false
	_release_delay = 0.0
	_render_initialized = false

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
			return true
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				reset()
				return true
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				distance = clampf(distance + (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 4.0, 22.0)
				return true
	if event is InputEventMouseMotion and dragging:
		yaw = wrapf(yaw - event.relative.x * 0.004, -PI, PI)
		pitch = clampf(pitch + event.relative.y * 0.004, -0.15, 1.25)
		return true
	return false

func direction(car: Node3D) -> Vector3:
	var forward := -car.global_basis.z
	forward.y = 0
	# Avoid a 180-degree chase reversal when the chassis pitches past vertical.
	if forward.length_squared()<0.0625 or car.global_basis.y.dot(Vector3.UP)<0.2:
		forward = _heading if _initialized else Vector3.FORWARD
		if car is RigidBody3D:
			var travel := Vector3(car.linear_velocity.x,0,car.linear_velocity.z)
			if travel.length_squared()>1.0:
				forward = travel.normalized()
	return forward.normalized().rotated(Vector3.UP, yaw)

func desired(car: Node3D) -> Vector3:
	return car.global_position + Vector3.UP * 0.6 - direction(car) * cos(pitch) * distance + Vector3.UP * sin(pitch) * distance

func probe(car: RigidBody3D) -> void:
	var anchor := _anchor if _initialized else car.global_position+Vector3.UP*0.6
	var forward := _heading.rotated(Vector3.UP,yaw) if _initialized else direction(car)
	var end := anchor-forward*cos(pitch)*distance+Vector3.UP*sin(pitch)*distance
	var ray := (end-anchor).normalized()
	var right := ray.cross(Vector3.UP).normalized()
	var up := right.cross(ray).normalized()
	var limit := distance
	obstructed = false
	# Approximate the near-plane footprint instead of testing a single pixel ray.
	for offset in [Vector3.ZERO,right*0.18,-right*0.18,up*0.18,-up*0.18]:
		var query := PhysicsRayQueryParameters3D.create(anchor+offset,end+offset,1,[car.get_rid()])
		var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			limit = minf(limit,maxf(0.35,anchor.distance_to(hit.position-offset)-0.3))
			obstructed = true
	if obstructed:
		safe_position = anchor+ray*limit

func update(camera: Camera3D, car: RigidBody3D, dt: float, check_collision: bool = false) -> void:
	var raw_anchor := car.global_position+Vector3.UP*0.6
	var heading := direction(car).rotated(Vector3.UP,-yaw)
	if not _initialized or _anchor.distance_to(raw_anchor)>30.0:
		_anchor = raw_anchor
		_heading = heading
		_boom = distance
		_release_delay = 0.0
		_initialized = true
	else:
		var follow := raw_anchor+Vector3(car.linear_velocity.x,0,car.linear_velocity.z)*0.075
		var vertical_rate := lerpf(6.0,18.0,clampf((absf(car.linear_velocity.y)-2.0)/8.0,0,1))
		var next := _anchor.lerp(follow,1.0-exp(-dt*12.0))
		next.y = lerpf(_anchor.y,raw_anchor.y,1.0-exp(-dt*vertical_rate))
		_anchor = next
		var angle := _heading.signed_angle_to(heading,Vector3.UP)
		_heading = _heading.rotated(Vector3.UP,angle*(1.0-exp(-dt*7.0))).normalized()
	var forward := _heading.rotated(Vector3.UP,yaw)
	var ray := -forward*cos(pitch)+Vector3.UP*sin(pitch)
	if check_collision:
		# Query the exact filtered pose used below, during the same physics step.
		probe(car)
	var limit := minf(distance,maxf(0.35,(safe_position-_anchor).dot(ray))) if obstructed else distance
	if limit<_boom:
		_boom = limit
		_release_delay = 0.16
	else:
		_release_delay = 0.16 if obstructed and limit<=_boom+0.05 else maxf(0,_release_delay-dt)
		if _release_delay<=0:
			_boom = move_toward(_boom,lerpf(_boom,limit,1.0-exp(-dt*4.0)),dt*6.0)
	camera.global_position = _anchor+ray*_boom
	var target := _anchor+forward*2.0
	if camera.global_position.distance_squared_to(target) > 0.01:
		camera.look_at(target)

func step(camera: Camera3D, car: RigidBody3D, dt: float) -> void:
	_previous_pose = _current_pose
	update(camera,car,dt,true)
	_current_pose = camera.global_transform
	if not _render_initialized or _previous_pose.origin.distance_to(_current_pose.origin)>2.0 or _previous_pose.basis.get_rotation_quaternion().angle_to(_current_pose.basis.get_rotation_quaternion())>0.6:
		_previous_pose = _current_pose
	_render_initialized = true

func render(camera: Camera3D) -> void:
	if _render_initialized:
		camera.global_transform = _previous_pose.interpolate_with(_current_pose,Engine.get_physics_interpolation_fraction())

extends RefCounted
var yaw := 0.0
var pitch := 0.35
var distance := 11.3
var dragging := false
var obstructed := false
var safe_position := Vector3.ZERO

func end_drag() -> void:
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset() -> void:
	end_drag()
	yaw = 0.0
	pitch = 0.35
	distance = 11.3
	obstructed = false

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
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	return forward.normalized().rotated(Vector3.UP, yaw)

func desired(car: Node3D) -> Vector3:
	return car.global_position + Vector3.UP * 0.6 - direction(car) * cos(pitch) * distance + Vector3.UP * sin(pitch) * distance

func probe(car: RigidBody3D) -> void:
	var query := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP * 0.7, desired(car), 1, [car.get_rid()])
	var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
	obstructed = not hit.is_empty()
	if obstructed:
		safe_position = hit.position + hit.normal * 0.3

func update(camera: Camera3D, car: RigidBody3D, dt: float) -> void:
	camera.global_position = safe_position if obstructed else camera.global_position.lerp(desired(car), 1.0-exp(-dt*8.0))
	var target := car.global_position + Vector3.UP * 0.6 + direction(car) * 2.0
	if camera.global_position.distance_squared_to(target) > 0.01:
		camera.look_at(target)

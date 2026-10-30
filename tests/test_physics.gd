extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in roundi(count * Engine.physics_ticks_per_second / 60.0):
		await physics_frame
func run() -> void:
	var script = load("res://scripts/car.gd")
	if script == null:
		push_error("FAIL: physical car not implemented")
		quit(1)
		return
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 1, 500)
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	root.add_child(ground)
	var car = script.new()
	root.add_child(car)
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0)))
	await frames(180)
	check(car.contacts == 4, "all four wheels settle on flat ground")
	check(car.position.y > 0.5 and car.position.y < 1.1, "springs support chassis weight")
	Input.action_press("throttle")
	await frames(120)
	Input.action_release("throttle")
	check(car.linear_velocity.z < -5.0, "drive forces accelerate forward")
	Input.action_press("steer_left")
	Input.action_press("throttle")
	await frames(45)
	Input.action_release("steer_left")
	Input.action_release("throttle")
	check(absf(car.rotation.y) > 0.05, "front tire steering rotates chassis")
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))
	await frames(60)
	Input.action_press("burst")
	await frames(30)
	check(car.position.y > 1.8, "nozzle forces produce lift")
	await frames(65)
	check(car.fuel <= 0.001, "burst is finite")
	var empty_vertical_speed: float = car.linear_velocity.y
	await frames(30)
	check(car.linear_velocity.y < empty_vertical_speed - 3.5 and not car.burning, "empty tank stops thrust and gravity reduces upward speed")
	Input.action_release("burst")
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	await frames(1)
	check(car.linear_velocity.length() < 0.5 and car.angular_velocity.length() < 0.1, "recovery clears momentum")
	print("Physical vehicle: ", 8 - failures, "/8 passed")
	quit(1 if failures else 0)

extends SceneTree
var checks := 0
var failures := 0
var car
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func drop(assist: bool, gas: float) -> Dictionary:
	car.auto_landing_enabled = assist
	car.fuel = gas
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 6, 0)))
	await frames(3)
	car.linear_velocity = Vector3(0, -8, 0)
	var before := 0.0
	var fired := false
	for i in 240:
		await physics_frame
		fired = fired or car.burning
		if car.contacts > 0:
			return {"speed": -before, "fired": fired, "fuel": car.fuel}
		before = car.linear_velocity.y
	return {"speed": 999, "fired": fired, "fuel": car.fuel}
func run() -> void:
	var ground := StaticBody3D.new()
	ground.set_meta("landing_surface", true)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 1, 60)
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	root.add_child(ground)
	car = load("res://scripts/car.gd").new()
	root.add_child(car)
	var ballistic: Dictionary = await drop(false, 1.0)
	var assisted: Dictionary = await drop(true, 1.0)
	print("Touchdown m/s: ballistic=", ballistic.speed, " assisted=", assisted.speed)
	check(assisted.speed < ballistic.speed * 0.75 and assisted.speed < 8, "real nozzle forces substantially reduce touchdown speed")
	check(assisted.fired and assisted.fuel < 1 and assisted.fuel > 0, "automatic landing uses shared limited tank")
	var empty: Dictionary = await drop(true, 0.0)
	check(not empty.fired and absf(empty.speed - ballistic.speed) < 0.5, "empty tank falls ballistically without landing rescue")
	ground.set_meta("landing_surface", false)
	var terrain: Dictionary = await drop(true, 1.0)
	check(not terrain.fired and absf(terrain.speed - ballistic.speed) < 0.5, "terrain does not receive road landing assist")
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(100, 25, 0)))
	car.fuel = 0.5
	await frames(3)
	Input.action_press("pitch_forward")
	await frames(20)
	Input.action_release("pitch_forward")
	check(car.angular_velocity.x > 0.1 and car.fuel < 0.5, "airborne pitch uses off-center forces and spends fuel")
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(100, 25, 0)))
	car.fuel = 0
	await frames(3)
	Input.action_press("pitch_forward")
	await frames(20)
	Input.action_release("pitch_forward")
	check(car.angular_velocity.length() < 0.01 and not car.burning, "empty tank has no free attitude torque")
	car.fuel = 0.5
	Input.action_press("burst")
	await frames(5)
	paused = true
	var gas_before: float = car.fuel
	await frames(15)
	check(is_equal_approx(car.fuel, gas_before), "pause stops gas consumption")
	Input.action_release("burst")
	paused = false
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(100, 25, 0)))
	check(not car.burning and car.nozzle_duties == PackedFloat32Array([0,0,0,0]), "recovery immediately clears all nozzle output")
	print("Physical landing jets: ", checks - failures, "/", checks, " passed")
	car.clear_jets()
	car.queue_free()
	await process_frame
	await create_timer(0.08).timeout
	quit(1 if failures else 0)

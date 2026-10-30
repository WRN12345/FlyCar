extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.countdown = 0.0
	world.car.freeze = false
	await frames(180)
	Input.action_press("throttle")
	for i in 800:
		await physics_frame
		if world.car.position.z < 33:
			break
	Input.action_press("burst")
	await frames(54)
	Input.action_release("burst")
	for i in 240:
		await physics_frame
		if world.car.position.z < 10:
			break
	print("Barrier crossing: ", world.car.position, " speed ", world.car.linear_velocity.length())
	check(world.car.position.z < 10 and world.car.position.y > 1.3, "powered jump clears full-width barrier")
	Input.action_release("throttle")
	world.car.reset_to(Transform3D(Basis(Vector3.UP, PI), Vector3(210, 1.0, -75)))
	world.car.fuel = 1.0
	await frames(180)
	Input.action_press("throttle")
	for i in 800:
		await physics_frame
		if world.car.position.z > -39:
			break
	Input.action_press("burst")
	await frames(78)
	Input.action_release("burst")
	for i in 500:
		await physics_frame
		if world.car.position.z > 12:
			break
	print("Bridge crossing: ", world.car.position, " recoveries ", world.race.recoveries)
	check(world.car.position.z > 12 and world.car.position.y > 0.5 and world.race.recoveries == 0, "finite burst crosses the real bridge gap")
	Input.action_release("throttle")
	check(world.hud_time.global_position.x > 0 and world.hud_time.global_position.x < root.get_visible_rect().size.x, "timer stays inside viewport")
	check(world.hud_speed.global_position.y > 0 and world.hud_speed.global_position.y < root.get_visible_rect().size.y, "speedometer stays inside viewport")
	print("Obstacles and HUD: ", 4 - failures, "/4 passed")
	quit(1 if failures else 0)

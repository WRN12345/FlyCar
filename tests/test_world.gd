extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var packed = load("res://main.tscn")
	if packed == null:
		push_error("FAIL: playable circuit not implemented")
		quit(1)
		return
	var world = packed.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(210, 3, -7), Vector3(210, -2, -7))
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "broken bridge is an actual physical gap")
	query.from = Vector3(210, 3, -40)
	query.to = Vector3(210, -2, -40)
	check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "road before bridge supports wheels")
	check(world.gates.size() == 8, "complete circuit includes eight ordered gates")
	world.car.fuel = 0.2
	world.recover()
	await physics_frame
	check(world.car.fuel <= 0.21, "recovery cannot refill thruster tank")
	check(world.race.recoveries == 1, "recovery recorded")
	world.restart_race()
	check(world.race.next_gate == 1 and world.countdown > 0, "new race resets ordered lap and countdown")
	for i in 420:
		await physics_frame
	check(not world.car.pending_reset and not world.car.freeze and world.car.position.distance_to(Vector3(0, 0.8, 85)) < 1, "restart applies pose and releases car after countdown")
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	world._unhandled_input(event)
	var before: float = world.race.elapsed
	var pose: Vector3 = world.car.position
	for i in 30:
		await physics_frame
	check(paused and world.race.elapsed == before and world.car.position.is_equal_approx(pose), "pause freezes both simulation and race timer")
	world._unhandled_input(event)
	check(not paused, "escape resumes race")
	for gate in [1, 2, 3, 4, 5, 6, 7, 0]:
		world.race.pass_gate(gate, true)
	var finished_time: float = world.race.elapsed
	var finished_recoveries: int = world.race.recoveries
	world.recover()
	check(world.race.elapsed == finished_time and world.race.recoveries == finished_recoveries, "post-finish recovery cannot change recorded result")
	print("Playable circuit: ", 10 - failures, "/10 passed")
	quit(1 if failures else 0)

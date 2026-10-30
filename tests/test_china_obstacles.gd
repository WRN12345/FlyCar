extends SceneTree
var checks := 0
var failures := 0
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
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	for index in 3:
		await process_frame
		world.switch_track(index)
		world.countdown = 0
		world.car.freeze = false
		await frames(100)
		var barrier: Transform3D = world.course.barrier_pose
		Input.action_press("throttle")
		for i in 900:
			await physics_frame
			if world.car.position.distance_to(barrier.origin) < 21:
				break
		Input.action_press("burst")
		await frames(60)
		Input.action_release("burst")
		for i in 300:
			await physics_frame
			if (world.car.position - barrier.origin).dot(-barrier.basis.z) > 6:
				break
		check((world.car.position - barrier.origin).dot(-barrier.basis.z) > 6 and world.death_remaining == 0, "barrier physically clearable: " + world.tracks[index].id)
		Input.action_release("throttle")
		var pose: Transform3D = world.course.pose_at(world.course.gap_distance - 110)
		pose.origin += Vector3.UP * 0.8
		world.car.reset_to(pose)
		world.car.fuel = 1
		await frames(120)
		Input.action_press("throttle")
		var gap: Transform3D = world.course.gap_pose
		for i in 900:
			await physics_frame
			if world.car.position.distance_to(gap.origin) < 36:
				break
		Input.action_press("burst")
		await frames(84)
		Input.action_release("burst")
		for i in 500:
			await physics_frame
			if (world.car.position - gap.origin).dot(-gap.basis.z) > 19:
				break
		print(world.tracks[index].id, " bridge height=", world.car.position.y - world.course.road_height_at(world.car.position))
		check((world.car.position - gap.origin).dot(-gap.basis.z) > 19 and world.death_remaining == 0 and world.car.position.y > world.course.road_height_at(world.car.position) - 1, "bridge physically clearable: " + world.tracks[index].id)
		Input.action_release("throttle")
	print("Chinese physical obstacles: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

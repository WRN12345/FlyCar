extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.countdown = 0
	var pose: Transform3D = world.course.pose_at(75)
	pose.origin += Vector3.UP*0.9
	world.car.reset_to(pose)
	for i in 90: await physics_frame
	var max_angle := 0.0
	var previous: Vector3 = world.camera.global_basis.z
	for frame in 240:
		await process_frame
		var nearest := INF
		var at := 0
		for i in range(15,65):
			var separation: float = world.car.position.distance_squared_to(world.route[i])
			if separation<nearest:
				nearest = separation
				at = i
		var desired: Vector3 = world.route[at+3]-world.car.position
		desired.y = 0
		var forward: Vector3 = -world.car.global_basis.z
		forward.y = 0
		var error := forward.normalized().signed_angle_to(desired.normalized(),Vector3.UP)
		Input.action_press("steer_left",clampf(error*2.8,0,1))
		Input.action_press("steer_right",clampf(-error*2.8,0,1))
		Input.action_press("throttle",0.65 if world.car.linear_velocity.length()<7 else 0)
		if frame==90: Input.action_press("burst")
		if frame==110: Input.action_release("burst")
		if frame>30:
			max_angle = maxf(max_angle,previous.angle_to(world.camera.global_basis.z))
		previous = world.camera.global_basis.z
	for action in ["steer_left","steer_right","throttle","burst"]: Input.action_release(action)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join("camera-stable-drive.jpg"),0.9)
	print("Native camera drive/jump: max_angle_radians=",max_angle," recoveries=",world.race.recoveries," death=",world.death_remaining)
	quit(1 if world.race.recoveries>0 or world.death_remaining>0 else 0)

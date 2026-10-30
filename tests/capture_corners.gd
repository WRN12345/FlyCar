extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	var anchors := [[1505,326], [471,47], [1518,710]]
	for index in 3:
		await process_frame
		world.switch_track(index)
		var anchor: Vector3 = world.Catalog.world_point(world.tracks[index], anchors[index])
		var nearest := 0
		var closest := INF
		for i in world.route.size():
			var distance: float = world.route[i].distance_to(anchor)
			if distance < closest:
				nearest = i
				closest = distance
		var pose: Transform3D = world.course.pose_at(world.course.distances[nearest] - 24)
		pose.origin += Vector3.UP * 0.8
		world.car.reset_to(pose)
		world.countdown = 0
		world.car.freeze = false
		for i in 80:
			await physics_frame
		world.car.freeze = true
		world.set_process(false)
		world.set_physics_process(false)
		world.banner.text = ""
		world.camera.position = world.route[nearest] + Vector3(25, 48, 35)
		world.camera.look_at(world.route[nearest])
		world.camera.fov = 62
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("flycar-corner-"+world.tracks[index].id+".png"))
		world.set_process(true)
		world.set_physics_process(true)
	quit()

extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.countdown = 0
	world.set_process(false)
	world.set_physics_process(false)
	var hazards = world.course.get_node("TrailObstacles")
	for kind in 3:
		var site: Dictionary = hazards.sites[kind]
		var pose: Transform3D = world.course.pose_at(site.distance-8)
		pose.origin.y += 0.9
		world.car.reset_to(pose)
		for i in 4:
			await physics_frame
		world.car.freeze = true
		var at: Vector3 = site.position
		var basis: Basis = world.course.pose_at(site.distance).basis
		world.camera.position = at+basis.z*9-basis.x*3+Vector3.UP*4
		world.camera.look_at(at+Vector3.UP*0.3)
		world.hud_hint.text = ["岩石阻路 · 减速绕行或喷射越过","林道倒木 · 右键环视观察绕行空间","碎石群 · 控制速度与车身姿态"][kind]
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join("trail-hazard-%d.jpg"%kind),0.9)
	quit()

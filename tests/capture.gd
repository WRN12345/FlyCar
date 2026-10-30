extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func save_image(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await save_image(output.path_join("flycar-map-selection.png"))
	for index in 3:
		await process_frame
		world.switch_track(index)
		world.countdown = 0
		world.car.freeze = false
		await frames(100)
		world.banner.text = ""
		await save_image(output.path_join("flycar-" + world.tracks[index].id + ".png"))
	var p: Vector3 = world.course.spawn.origin
	var sea: Dictionary = world.course.terrain.surface_at(p)
	world.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(p.x, sea.height + 0.1, p.z)))
	await frames(64)
	await save_image(output.path_join("flycar-water-sinking.png"))
	await process_frame
	world.switch_track(0)
	world.countdown = 0
	world.car.freeze = false
	await frames(100)
	p = world.course.spawn.origin
	var land: Dictionary = world.course.terrain.surface_at(p)
	world.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(p.x, land.height + 0.2, p.z)))
	await frames(30)
	await save_image(output.path_join("flycar-land-wreck.png"))
	world.restart_race()
	await frames(5)
	world.countdown = 0
	world.car.freeze = false
	await frames(100)
	world.banner.text = ""
	world.set_process(false)
	world.set_physics_process(false)
	world.car.freeze = true
	root.msaa_3d = Viewport.MSAA_DISABLED
	await save_image(output.path_join("flycar-aa-off.png"))
	root.msaa_3d = Viewport.MSAA_4X
	await save_image(output.path_join("flycar-aa-4x.png"))
	quit()

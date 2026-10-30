extends SceneTree
## godot --path . --script tests/capture.gd -- <absolute-output-directory>
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("flycar-map-selection.png"))
	for index in 3:
		await process_frame
		world.switch_track(index)
		world.countdown = 0
		world.car.freeze = false
		for i in 100:
			await physics_frame
		world.banner.text = ""
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("flycar-" + world.tracks[index].id + ".png"))
	world.begin_explosion()
	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("flycar-explosion.png"))
	quit()

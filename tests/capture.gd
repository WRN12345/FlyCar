extends SceneTree
## Usage: godot --path . --script tests/capture.gd -- <absolute-output-directory>
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.countdown = 0
	world.car.freeze = false
	for i in 100:
		await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.banner.text = ""
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("flycar-gameplay.png"))
	world.camera.position = world.car.position + Vector3(5.2, 2.4, -6.5)
	world.camera.look_at(world.car.position + Vector3(0, 0.3, 0))
	world.camera.fov = 48
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("flycar-roadster.png"))
	quit()

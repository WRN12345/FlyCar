extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out:=OS.get_cmdline_user_args()[0]
	var world=load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("offroad-menu.png"))
	world.switch_track(world.active_index)
	world.countdown=0
	world.car.freeze=false
	var model=load("res://scripts/offroad_model.gd")
	var views={"dirt":Vector3(0,0,-65),"gravel":Vector3(-220,0,-410),"mud":Vector3(-500,0,-750),"grass":Vector3(-150,0,-975),"river":Vector3(255,0,-790),"canyon":Vector3(437,0,-478)}
	for key in views:
		var p: Vector3=views[key]
		p.y=model.height_at(p.x,p.z)+0.9
		world.car.reset_to(Transform3D(Basis.IDENTITY,p))
		for i in 40:
			await physics_frame
		world.car.freeze=true
		world.set_process(false)
		world.camera.position=p+Vector3(-9,5,12) if key!="canyon" else Vector3(535,95,-320)
		world.camera.look_at(p+Vector3(0,0,-5) if key!="canyon" else Vector3(405,0,-430))
		world.hud_hint.text="山谷穿越 / "+key+" / 土路 · 碎石 · 泥地 · 草坡 · 河道 · 峡谷"
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("offroad-"+key+".png"))
		world.car.freeze=false
	world.car.freeze=true
	world.camera.position=Vector3(230,930,590)
	world.camera.look_at(Vector3(-60,0,-430))
	world.camera.far=4500
	world.hud_hint.text="山谷穿越 / 8 CHECKPOINTS / 2 SHORTCUTS"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("offroad-overview.png"))
	quit()

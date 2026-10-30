extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var geo = load("res://scripts/geometry.gd")
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bbc2cf")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("606a7a")
	sky_material.sky_horizon_color = Color("a8aeb9")
	sky_material.ground_bottom_color = Color("303743")
	sky_material.ground_horizon_color = Color("a8aeb9")
	sky.sky_material = sky_material
	env.sky = sky
	environment.environment = env
	scene.add_child(environment)
	for direction in [Vector3(-40,-25,0),Vector3(-30,135,0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = direction
		light.light_energy = 1.0 if direction.y < 0 else 0.65
		light.shadow_enabled = direction.y < 0
		scene.add_child(light)
	geo.solid(scene,Vector3(100,1,100),Vector3(0,-0.5,0),geo.material(Color("222936")))
	var car = load("res://scripts/car.gd").new()
	scene.add_child(car)
	car.reset_to(Transform3D(Basis.IDENTITY,Vector3(0,1,0)))
	var camera := Camera3D.new()
	camera.fov = 36
	camera.current = true
	scene.add_child(camera)
	for i in 180:
		await physics_frame
	car.freeze = true
	var views := {"rear-quarter":Vector3(-4.0,1.8,4.8),"front-quarter":Vector3(-4.0,1.8,-4.8),"side":Vector3(-6.5,1.5,0),"rear":Vector3(0,1.5,6)}
	for name in views:
		camera.position = views[name]
		camera.look_at(car.position + Vector3(0,-0.08,0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("roadster-silver-"+name+".png"))
	quit()

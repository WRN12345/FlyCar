extends SceneTree
var car
var camera: Camera3D
var caption: Label
var out: String
func _initialize() -> void:
	call_deferred("capture")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func save_view(file: String, text: String) -> void:
	caption.text = text
	camera.position = car.position + Vector3(-6, 2.5, 6)
	camera.look_at(car.position + Vector3.DOWN * 0.7)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(file))
func capture() -> void:
	out = OS.get_cmdline_user_args()[0]
	var geo = load("res://scripts/geometry.gd")
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("18232e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aab9cc")
	env.ambient_light_energy = 0.7
	environment.environment = env
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	scene.add_child(light)
	var ground = geo.solid(scene,Vector3(120,1,120),Vector3(0,-0.5,0),geo.material(Color("303d47")))
	ground.set_meta("landing_surface", true)
	for z in range(-50,51,6):
		geo.box(scene,Vector3(0.12,0.01,3),Vector3(3,0.01,z),geo.material(Color("d4dddf")))
	car = load("res://scripts/car.gd").new()
	scene.add_child(car)
	car.reset_to(Transform3D(Basis.IDENTITY,Vector3(0,1,0)))
	camera = Camera3D.new()
	camera.fov = 48
	camera.current = true
	scene.add_child(camera)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	caption = Label.new()
	caption.position = Vector2(30,25)
	caption.add_theme_font_size_override("font_size",26)
	ui.add_child(caption)
	await frames(180)
	Input.action_press("burst")
	await frames(35)
	await save_view("roadster-jets-takeoff.png", "LIFT-OFF / 起飞喷射")
	await frames(18)
	Input.action_release("burst")
	Input.action_press("pitch_forward")
	await frames(12)
	await save_view("roadster-jets-attitude.png", "ATTITUDE / 耗气姿态控制")
	Input.action_release("pitch_forward")
	car.fuel = 1
	car.reset_to(Transform3D(Basis.IDENTITY,Vector3(0,6,0)))
	await frames(3)
	car.linear_velocity = Vector3(0,-8,0)
	Input.action_press("burst")
	for i in 180:
		await physics_frame
		if car.jet_mode == "DESCENT BRAKE" and car.position.y < 5.6:
			break
	await save_view("roadster-jets-landing.png", "DESCENT BRAKE / Space 手动下落喷射")
	Input.action_release("burst")
	await frames(150)
	await save_view("roadster-jets-touchdown.png", "TOUCHDOWN / 悬挂接地")
	car.queue_free()
	await process_frame
	quit()

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
	if world.tracks[world.active_index].get("mode","") != "offroad":
		push_error("Off-road map is not the default and per-wheel terrain driving is not integrated")
		quit(1)
		return
	world.switch_track(world.active_index)
	world.countdown = 0
	world.car.freeze = false
	await frames(180)
	check(world.car.contacts >= 3 and world.death_remaining == 0, "off-road spawn settles safely on actual ground")
	Input.action_press("throttle")
	await frames(180)
	Input.action_release("throttle")
	check(world.car.linear_velocity.length() > 8 and world.death_remaining == 0, "Roadster drives over dirt without ground-contact destruction")
	var origin: Vector3 = world.course.spawn.origin
	world.car.reset_to(Transform3D(Basis.IDENTITY,origin+Vector3.UP*0.8))
	await frames(160)
	check(world.death_remaining == 0 and world.car.visible, "ordinary hop and suspension contact are survivable")
	world.car.reset_to(Transform3D(Basis.IDENTITY,origin+Vector3.UP*24))
	for i in 400:
		await physics_frame
		if world.death_remaining > 0:
			break
	check(world.impact_kind == "land" and world.death_remaining > 0, "high normal-speed terrain impact fragments car")
	for orientation in [Basis(Vector3.RIGHT,PI/2),Basis(Vector3.FORWARD,PI/2),Basis(Vector3.FORWARD,PI)]:
		world.restart_race()
		await frames(4)
		world.countdown = 0
		world.car.freeze = false
		world.car.reset_to(Transform3D(orientation,origin+Vector3.UP*24))
		for i in 400:
			await physics_frame
			if world.death_remaining > 0:
				break
		check(world.impact_kind=="land" and world.death_remaining>0,"body-first hard terrain impact is detected")
	world.restart_race()
	await frames(4)
	world.countdown = 0
	world.car.freeze = false
	var shallow := Vector3(255,3.0,-800)
	world.car.reset_to(Transform3D(Basis.IDENTITY,shallow))
	await frames(150)
	check(world.death_remaining == 0 and world.car.contacts >= 3, "shallow river supports wheels without triggering sinking")
	Input.action_press("throttle")
	await frames(90)
	Input.action_release("throttle")
	var fx = world.car.get_node_or_null("SurfaceEffects")
	check(fx != null and fx.emitters[0].emitting, "wheels create shallow-water spray while driving")
	world.car.reset_to(Transform3D(Basis.IDENTITY,Vector3(255,2.3,-1040)))
	await frames(6)
	check(world.impact_kind == "water" and world.death_remaining > 0, "deep pool triggers intact sinking")
	world.switch_track(0)
	await frames(5)
	check(world.car.surface_provider == null and world.tracks[0].id == "shanghai", "switching restores original asphalt physics")
	print("Off-road driving: ",checks-failures,"/",checks," passed")
	world.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)

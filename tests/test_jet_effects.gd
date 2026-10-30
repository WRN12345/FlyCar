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
	await process_frame
func run() -> void:
	var car = load("res://scripts/car.gd").new()
	root.add_child(car)
	var fx = car.get_node_or_null("JetEffects")
	if fx == null:
		push_error("Directional exhaust, surface mist and jet audio not implemented")
		quit(1)
		return
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 20, 0)))
	await frames(3)
	Input.action_press("burst")
	await frames(15)
	check(fx.plumes.size() == 4 and fx.plumes[0].emitting and fx.audio.playing, "actual firing drives four exhaust sources and jet audio")
	Input.action_release("burst")
	car.freeze = true
	await frames(3)
	check(not car.burning and not fx.plumes[0].emitting and not fx.audio.playing, "freeze stops stale gas plumes and audio")
	car.freeze = false
	Input.action_press("burst")
	await frames(5)
	car.visible = false
	await frames(3)
	check(not fx.plumes[0].visible and not fx.audio.playing, "hidden wrecked car cannot retain world-space gas or audio")
	car.visible = true
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 20, 0)))
	Input.action_release("burst")
	await frames(3)
	check(not fx.plumes[0].emitting and not fx.mists[0].emitting, "reset clears emission and surface hit history")
	var world := Node3D.new()
	root.add_child(world)
	var ground = load("res://scripts/geometry.gd").solid(world, Vector3(20, 1, 20), Vector3(0,-0.5,0), StandardMaterial3D.new())
	ground.set_meta("landing_surface", true)
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	await frames(80)
	Input.action_press("burst")
	await frames(8)
	check(fx.mists[0].emitting, "nearby surface spreads gas while taking off")
	Input.action_release("burst")
	await frames(2)
	check(not fx.mists[0].emitting and fx.mists[0].color.a > 0, "released burst preserves existing gas for natural fading")
	car.reset_to(Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0,2.5,0)))
	await frames(3)
	Input.action_press("burst")
	await frames(2)
	var aligned := false
	for i in car.exhaust_hits.size():
		var hit: Dictionary = car.exhaust_hits[i]
		if not hit.is_empty():
			var origin: Vector3 = car.global_transform * load("res://scripts/thruster_control.gd").NOZZLES[i]
			aligned = (hit.position - origin).normalized().dot(-car.thrust_direction) > 0.99
			if aligned:
				break
	check(aligned, "surface mist contact follows the actual tilted exhaust ray")
	Input.action_release("burst")
	print("Jet effects lifecycle: ", checks - failures, "/", checks, " passed")
	car.queue_free()
	world.queue_free()
	await process_frame
	await create_timer(0.08).timeout
	quit(1 if failures else 0)

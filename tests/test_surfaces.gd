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
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	if not world.has_method("begin_surface_impact"):
		push_error("Surface-aware falls are not implemented")
		quit(1)
		return
	await process_frame
	world.switch_track(0)
	await frames(4)
	world.countdown = 0
	world.car.freeze = false
	var start: Vector3 = world.course.spawn.origin
	world.car.reset_to(Transform3D(Basis.IDENTITY, start - Vector3.UP * 12))
	await frames(6)
	check(world.death_remaining == 0 and world.car.visible, "falling below deck still in air must not explode")
	var land: Dictionary = world.course.terrain.surface_at(start)
	check(land.kind == "land", "Shanghai start is visibly over land")
	world.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(start.x, land.height + 0.08, start.z)))
	await frames(4)
	check(world.death_remaining > 0 and world.impact_kind == "land" and not world.car.visible, "land impact replaces car with fragments")
	check(world.impact_effect.parts.size() >= 10 and not world.impact_effect.has_node("Fireball"), "recognizable body parts, no fireball")
	world.restart_race()
	await frames(5)
	check(world.death_remaining == 0 and world.car.visible, "restart clears impact state")
	world.countdown = 0
	world.car.freeze = false
	world.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(start.x - 30, 20, start.z)))
	await frames(300)
	check(world.impact_kind == "land" and world.death_remaining > 0, "real gravity fall reaches land and breaks car")
	for fixture in [[Basis(Vector3.FORWARD, PI / 2), 0.92], [Basis(Vector3.RIGHT, PI / 2), 2.11]]:
		world.restart_race()
		await frames(4)
		world.countdown = 0
		world.car.freeze = false
		world.car.reset_to(Transform3D(fixture[0], Vector3(start.x - 30, 10, start.z)))
		for i in 240:
			await physics_frame
			if world.car.position.y < land.height + fixture[1] + 0.15:
				break
		await frames(5)
		check(world.impact_kind == "land" and world.death_remaining > 0, "sideways and nose-first ground contacts must break chassis")
	var lake = world.course.terrain.regions[0].rect
	var lake_center: Vector2 = lake.get_center()
	var water_query := PhysicsRayQueryParameters3D.create(Vector3(lake_center.x, 3, lake_center.y), Vector3(lake_center.x, -0.1, lake_center.y))
	check(world.get_world_3d().direct_space_state.intersect_ray(water_query).is_empty(), "visible water region has no hidden land collider")
	var land_query := PhysicsRayQueryParameters3D.create(Vector3(start.x - 30, 3, start.z), Vector3(start.x - 30, -0.1, start.z))
	check(not world.get_world_3d().direct_space_state.intersect_ray(land_query).is_empty(), "visible land has a real collision surface")
	await process_frame
	world.switch_track(2)
	await frames(4)
	world.countdown = 0
	world.car.freeze = false
	start = world.course.spawn.origin
	var sea: Dictionary = world.course.terrain.surface_at(start)
	check(sea.kind == "water", "Zhuhai coast start is over visible sea")
	world.car.fuel = 0.25
	world.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(start.x, sea.height + 0.1, start.z)))
	await frames(4)
	check(world.impact_kind == "water" and world.car.visible and world.death_remaining > 0, "water retains car for sinking")
	var y_before: float = world.car.position.y
	await frames(90)
	check(world.car.position.y < y_before - 0.5, "car visibly sinks through water surface")
	var remaining: float = world.death_remaining
	paused = true
	await frames(20)
	check(world.death_remaining == remaining, "pause stops sinking and recovery")
	paused = false
	world.recover()
	check(world.race.recoveries == 0, "R cannot duplicate surface recovery")
	await frames(270)
	check(world.death_remaining == 0 and world.car.visible and world.race.recoveries == 1, "water recovers exactly once")
	check(world.car.fuel < 0.35, "sinking does not refill fuel")
	check(root.msaa_3d == Viewport.MSAA_4X, "4x MSAA enabled on actual viewport")
	print("Surface impacts: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

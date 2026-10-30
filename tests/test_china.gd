extends SceneTree
var failures := 0
var checks := 0
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
	if not world.has_method("switch_track"):
		push_error("Multi-map lifecycle not implemented")
		quit(1)
		return
	check(world.menu.is_open and paused, "startup requires map selection")
	world.switch_track(0)
	world.countdown = 0
	world.car.freeze = false
	world.car.position = Vector3.ZERO
	world._physics_process(1.0 / 120)
	check(world.death_remaining == 0, "fall check must ignore an unapplied reset pose")
	await frames(10)
	check(world.death_remaining == 0 and world.car.visible, "first physics reset must precede fall detection")
	for index in 3:
		await process_frame
		world.switch_track(index)
		await frames(3)
		check(world.course.route.size() > 80 and world.gates.size() == 8, "each map builds valid gates and road")
		var pose: Transform3D = world.course.gap_pose
		var query := PhysicsRayQueryParameters3D.create(pose.origin + Vector3.UP * 3, pose.origin - Vector3.UP * 2)
		check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "each bridge has a real collision gap")
		world.countdown = 0
		world.car.freeze = false
		await frames(100)
		check(world.car.contacts == 4, "each map spawn supports four wheels")
	check(world.get_children().filter(func(n): return n.name == "ActiveCourse").size() == 1, "switch removes old course")
	var old_time: float = world.race.elapsed
	world.open_maps()
	await frames(10)
	check(paused and world.race.elapsed == old_time, "map selection pauses timer")
	world.close_maps()
	check(not paused, "cancel restores active race")
	paused = true
	world.open_maps()
	world.close_maps()
	check(paused, "cancel preserves pre-existing pause")
	paused = false
	world.car.fuel = 0.25
	world.car.reset_to(Transform3D(Basis.IDENTITY, world.course.spawn.origin - Vector3.UP * 12))
	await frames(4)
	check(world.death_remaining > 0 and not world.car.visible, "fall triggers explosion and hides car")
	var penalty_count: int = world.race.recoveries
	world.recover()
	check(world.race.recoveries == penalty_count, "R cannot bypass active explosion")
	paused = true
	var remaining: float = world.death_remaining
	await frames(20)
	check(world.death_remaining == remaining, "pause suspends explosion countdown")
	paused = false
	await frames(210)
	check(world.death_remaining == 0 and world.car.visible and world.race.recoveries == penalty_count + 1, "explosion recovers once")
	check(world.car.fuel < 0.35, "explosion does not refill tank")
	world.car.reset_to(Transform3D(Basis.IDENTITY, world.course.spawn.origin - Vector3.UP * 12))
	await frames(4)
	world.restart_race()
	await frames(240)
	check(world.race.recoveries == 0 and world.death_remaining == 0 and world.car.visible, "restart cancels stale explosion")
	world.countdown = 0
	world.car.freeze = false
	world.car.reset_to(Transform3D(Basis.IDENTITY, world.course.spawn.origin - Vector3.UP * 12))
	await frames(4)
	await process_frame
	world.switch_track(0)
	await frames(240)
	check(world.active_index == 0 and world.death_remaining == 0 and world.race.recoveries == 0, "switch cancels old-map recovery")
	check(world.course.road_height_at(world.course.spawn.origin) > 25.0, "fall reference uses elevated local road")
	world.record_path = "user://flycar-regression-records.cfg"
	world.best_times.clear()
	world.best_time = 0
	world.save_record(123.0)
	await process_frame
	world.switch_track(1)
	check(world.best_time == 0, "new map does not inherit another map record")
	world.save_record(150.0)
	await process_frame
	world.switch_track(0)
	check(world.best_time == 123.0, "map record restored independently")
	world.save_record(130.0)
	check(world.best_time == 123.0, "slower result cannot replace record")
	var config := ConfigFile.new()
	config.load(world.record_path)
	check(config.get_value("tracks", "zhejiang") == 150.0 and config.get_value("tracks", "shanghai") == 123.0, "records persist in isolated map keys")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.record_path))
	var before_index: int = world.active_index
	world.switch_track(-1)
	check(world.active_index == before_index, "invalid selection cannot destroy active course")
	world.countdown = 0
	world.car.freeze = false
	world.car.reset_to(Transform3D(Basis.IDENTITY, world.course.spawn.origin + Vector3.UP * 20))
	await frames(4)
	check(world.death_remaining == 0 and world.car.visible, "normal airborne height never triggers explosion")
	var fits := true
	for point in world.route:
		var p: Vector2 = world.map.project(point)
		if p.x < 0 or p.y < 0 or p.x > world.map.size.x or p.y > world.map.size.y:
			fits = false
	check(fits, "arbitrary track fits minimap")
	print("China tracks lifecycle: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

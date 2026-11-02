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
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.switch_track(world.active_index)
	world.set_physics_process(false)
	world.record_path = "user://route-boundary-test.cfg"
	world.countdown = 0
	for i in 4: await physics_frame
	var pose: Transform3D = world.course.pose_at(75)
	check(world.boundary_enabled and world.course.within_boundary(pose.origin),"Road boundary is enabled by default")
	check(world.course.within_boundary(pose.origin+Vector3.UP*20),"Vertical flight over road is legal")
	var outside: Vector3 = pose.origin+pose.basis.x*12
	check(not world.course.within_boundary(outside) and not world.course.within_boundary(outside+Vector3.UP*20),"Roadside and airborne shortcuts outside the corridor are illegal")
	for cut in world.course.shortcuts:
		check(world.course.within_boundary(cut.points[0].lerp(cut.points[1],0.5)),"Designated shortcut remains legal")
	check(world.course.within_boundary(Vector3(439,40,-535)),"Canyon runway remains part of the designated flight route")
	world.car.freeze = true
	world.car.fuel = 0.5
	world.car.position = outside+Vector3.UP*8
	world._physics_process(1.0/120)
	check(world.race_failed and world.car.freeze and not world.car.visible and not world.car.pending_reset,"Airborne boundary violation instantly wrecks the vehicle")
	check(world.race.recoveries==0 and is_equal_approx(world.car.fuel,0.5),"Fatal boundary does not recover or refill fuel")
	var crash_position: Vector3 = world.car.position
	var stopped_time: float = world.race.elapsed
	for i in 600: world._physics_process(1.0/120)
	world.recover()
	check(world.race_failed and world.car.freeze and world.car.position==crash_position and not world.car.pending_reset,"Wreck persists after animation and R cannot restore the car")
	check(world.race.elapsed==stopped_time,"Failed race stops its timer")
	world.race.next_gate = 0
	world._gate_entered(world.car,0)
	check(not world.race.finished,"Failed car cannot finish the race")
	world.restart_race()
	for i in 4: await physics_frame
	world.countdown = 0
	check(not world.race_failed and world.car.visible,"Explicit restart creates a new attempt")
	world.car.freeze = true
	world.car.position = pose.origin+Vector3.UP*10
	world._physics_process(1.0/120)
	check(not world.race_failed and world.race.recoveries==0,"Legal flight is not a boundary violation")
	world.race.next_gate = 0
	var elapsed: float = world.race.elapsed
	var best_before: float = world.best_time
	var gate: Transform3D = world.gates[0]
	world.car.position = gate.origin+gate.basis.x*8
	world.car.linear_velocity = -gate.basis.z*5
	world._gate_entered(world.car,0)
	check(not world.race.finished and world.race.next_gate==0 and world.best_time==best_before,"Out-of-bounds finish crossing cannot finish or record a lap")
	world.car.position = gate.origin
	world.car.pending_reset = true
	world._gate_entered(world.car,0)
	check(not world.race.finished and world.race.elapsed==elapsed,"Pending recovery cannot count a checkpoint crossing")
	world.car.pending_reset = false
	world._gate_entered(world.car,0)
	check(world.race.finished,"In-bounds forward finish still completes the race")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.record_path))
	print("Route boundary: %d/%d passed"%[checks-failures,checks])
	world.free()
	quit(1 if failures else 0)

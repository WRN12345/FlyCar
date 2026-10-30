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
	var script = load("res://scripts/offroad_course.gd")
	if script == null:
		push_error("Off-road course and physical terrain not implemented")
		quit(1)
		return
	var course = script.new()
	root.add_child(course)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json"))
	course.build(data)
	await physics_frame
	await physics_frame
	check(course.length >= 2500 and course.length <= 3500 and course.gates.size() == 8, "valley route has approved length and eight gates")
	check(course.shortcuts.size() == 2, "two shortcuts are exposed to map and driving hints")
	var match_height := true
	var space: PhysicsDirectSpaceState3D = course.get_world_3d().direct_space_state
	for x in [-512.0,-384.0,-128.0,0.0,128.0,255.0,310.0,440.0]:
		for z in [-1040.0,-800.0,-430.0,-128.0,0.0]:
			var p := Vector3(x,60,z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*100))
			var sample: Dictionary = course.terrain.surface_at(p)
			if hit.is_empty() or absf(hit.position.y-sample.height) > 0.02:
				print("Height mismatch ",Vector2(x,z)," query=",sample.height," hit=",hit.get("position","missing"))
				match_height = false
	check(match_height, "terrain collision matches queried height across chunks and river/canyon")
	var safe := true
	var steepest:=Vector3.ZERO
	var minimum_normal:=1.0
	for p in course.route:
		var normal_y:float=course.terrain.surface_at(p).normal.y
		if normal_y<minimum_normal:
			minimum_normal=normal_y
			steepest=p
		if normal_y < 0.88:
			safe = false
	if not safe:
		print("Steepest main route point: ",steepest," normal.y=",minimum_normal)
	check(safe, "main route avoids cliffs and excessive low-car slopes")
	var ordered := true
	for i in range(1,8):
		ordered = ordered and course.gate_distances[i] > course.gate_distances[i-1]
	check(ordered, "checkpoint positions remain in route order")
	check(course.terrain.surface_at(Vector3(255,4,-800)).kind == "land" and course.terrain.surface_at(Vector3(255,4,-1040)).kind == "water", "shallow bed is driveable while deep pool uses sinking rule")
	print("Off-road course: ", checks-failures,"/",checks," passed")
	course.queue_free()
	await process_frame
	quit(1 if failures else 0)

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
	var course = load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json")))
	var fence = course.get_node("TrailFence")
	check(fence.panels.size()>1800 and fence.post_count==fence.panels.size(),"Continuous wooden panels and posts on both sides")
	var left := 0
	var right := 0
	var clear := true
	var grounded := true
	var openings := true
	for panel in fence.panels:
		if panel.side<0: left+=1
		else: right+=1
		var midpoint: Vector3 = panel.a.lerp(panel.b,0.5)
		if course.terrain.trail_distance(Vector2(midpoint.x,midpoint.z))<2.7:
			clear = false
		if absf(panel.a.y-load("res://scripts/offroad_model.gd").height_at(panel.a.x,panel.a.z))>0.01:
			grounded = false
		if course.in_shortcut_corridor(midpoint,0.6):
			openings = false
	check(left>800 and right>800,"Both road edges are fenced")
	check(clear,"Curved fence stays outside the driveable road")
	check(grounded,"Fence posts follow actual terrain height")
	check(openings,"Shortcut openings have no fence panels or hidden colliders")
	var aligned := true
	for data in fence.chunks.values():
		for i in range(0,data.poses.size(),3):
			var basis: Basis = data.poses[i].basis
			if absf(basis.x.length()-0.14)>0.001 or absf(basis.y.length()-0.14)>0.001 or absf(basis.x.normalized().dot(basis.z.normalized()))>0.001:
				aligned = false
	check(aligned,"Rotated rail meshes retain local thickness and meet their posts")
	await physics_frame
	await physics_frame
	var sample: Dictionary = fence.panels[20]
	var midpoint: Vector3 = sample.a.lerp(sample.b,0.5)
	var normal := Basis.looking_at((sample.b-sample.a).normalized(),Vector3.UP).x
	var gap := midpoint+Vector3.UP*0.74
	var gap_query := PhysicsRayQueryParameters3D.create(gap-normal*0.5,gap+normal*0.5)
	var gap_hit := root.world_3d.direct_space_state.intersect_ray(gap_query)
	check(gap_hit.is_empty() or not gap_hit.collider.get_meta("trail_fence",false),"Empty space between wooden rails is not an invisible wall")
	var pose: Transform3D = course.pose_at(75)
	var collisions := true
	for side in [-1,1]:
		var closest := INF
		var panel: Dictionary = {}
		for candidate in fence.panels:
			var separation: float = candidate.a.lerp(candidate.b,0.5).distance_squared_to(pose.origin)
			if candidate.side==side and separation<closest:
				closest = separation
				panel = candidate
		var center: Vector3 = panel.a.lerp(panel.b,0.5)+Vector3.UP
		var cross_axis := Basis.looking_at((panel.b-panel.a).normalized(),Vector3.UP).x
		var query := PhysicsRayQueryParameters3D.create(center-cross_axis*0.5,center+cross_axis*0.5)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider.get_meta("trail_fence",false):
			collisions = false
	check(collisions,"Both roadside fences physically block lateral travel")
	var matched := true
	for data in fence.chunks.values():
		var shapes: Array = data.body.get_children()
		if shapes.size()!=data.poses.size():
			matched = false
			continue
		for i in shapes.size():
			var rendered: Transform3D = data.poses[i]
			var size := Vector3(rendered.basis.x.length(),rendered.basis.y.length(),rendered.basis.z.length())
			if not shapes[i].shape.size.is_equal_approx(size) or not shapes[i].position.is_equal_approx(rendered.origin):
				matched = false
	check(matched,"Every collider matches a visible rail or post; no full panel remains")
	var car = load("res://scripts/car.gd").new()
	root.add_child(car)
	car.surface_provider = course.terrain
	pose.origin += Vector3.UP*0.9
	car.reset_to(pose)
	for i in 180: await physics_frame
	car.linear_velocity = pose.basis.x*7
	for i in 120: await physics_frame
	check((car.position-pose.origin).dot(pose.basis.x)<2.2,"Rigid-body vehicle cannot push through the fence")
	print("Trail fence: %d/%d passed; panels=%d"%[checks-failures,checks,fence.panels.size()])
	car.free()
	course.free()
	quit(1 if failures else 0)

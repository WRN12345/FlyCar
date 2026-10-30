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
func run() -> void:
	var catalog = load("res://scripts/track_catalog.gd")
	var ribbon = load("res://scripts/road_ribbon.gd")
	if ribbon == null:
		push_error("Continuous road corner geometry not implemented")
		quit(1)
		return
	for data in catalog.load_tracks():
		var points: Array[Vector3] = catalog.sample(data)
		var road = ribbon.new()
		root.add_child(road)
		var distances: Array[float] = []
		var mask: Array[bool] = []
		var length := 0.0
		for i in points.size():
			distances.append(length)
			length += points[i].distance_to(points[(i+1)%points.size()])
			mask.append(false)
		var geo = load("res://scripts/geometry.gd")
		var mat = geo.material(Color.GRAY)
		var materials := {"asphalt":mat,"shoulder":mat,"edge":mat,"dark":mat,"accent":mat,"white":mat}
		road.build(points, mask, distances, materials)
		var unfolded := true
		var max_angle := 0.0
		for i in points.size():
			var j := (i + 1) % points.size()
			var a: Vector3 = road.offset_point(i, -10)
			var b: Vector3 = road.offset_point(i, 10)
			var c: Vector3 = road.offset_point(j, 10)
			var d: Vector3 = road.offset_point(j, -10)
			if (d-a).cross(b-a).y >= -0.001 or (d-b).cross(c-b).y >= -0.001:
				unfolded = false
			max_angle = maxf(max_angle, (points[i]-points[(i-1+points.size())%points.size()]).angle_to(points[j]-points[i]))
		check(unfolded, "road quad cannot fold or reverse at corners: " + data.id)
		check(max_angle < deg_to_rad(25), "centerline no longer has cusp reversals: " + data.id)
		check(road.minimum_width >= 6.0, "tight corners remain wide enough to drive: " + data.id)
		await physics_frame
		await physics_frame
		var continuous := true
		for i in points.size():
			for offset in [-8.3, 0.0, 8.3]:
				var p: Vector3 = road.offset_point(i, offset)
				var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p - Vector3.UP * 1.5)
				if root.world_3d.direct_space_state.intersect_ray(query).is_empty():
					continuous = false
		check(continuous, "continuous collision across every shared join including lap seam: " + data.id)
		road.queue_free()
	await process_frame
	var circle: Array[Vector3] = []
	var mask: Array[bool] = []
	var distances: Array[float] = []
	for i in 128:
		circle.append(Vector3(cos(TAU * i / 128) * 100, 32, sin(TAU * i / 128) * 100))
		mask.append(i >= 20 and i < 25)
		distances.append(float(i) * TAU * 100 / 128)
	var material = load("res://scripts/geometry.gd").material(Color.GRAY)
	var gap_road = ribbon.new()
	root.add_child(gap_road)
	gap_road.build(circle, mask, distances, {"asphalt":material,"shoulder":material,"edge":material,"dark":material,"accent":material,"white":material})
	await physics_frame
	await physics_frame
	for index in [19, 22, 25]:
		var p: Vector3 = circle[index].lerp(circle[index+1], 0.5)
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP)
		var present := not root.world_3d.direct_space_state.intersect_ray(query).is_empty()
		check(present == (index != 22), "intentional gap stays open with solid road at both ends")
	var tangent: Vector3 = (circle[21] - circle[20]).normalized()
	var cap_query := PhysicsRayQueryParameters3D.create(circle[20] + tangent - Vector3.UP * 0.35, circle[20] - tangent - Vector3.UP * 0.35)
	check(not root.world_3d.direct_space_state.intersect_ray(cap_query).is_empty(), "gap end has a closed deck wall")
	gap_road.queue_free()
	await process_frame
	var course = load("res://scripts/course.gd").new()
	root.add_child(course)
	var seam_track: Dictionary = catalog.load_tracks()[0].duplicate(true)
	seam_track.gap_anchor = seam_track.points[0].duplicate()
	course.build(seam_track)
	await physics_frame
	await physics_frame
	for distance in [-6.0, 6.0, 23.0]:
		var p: Vector3 = course.pose_at(distance).origin
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p - Vector3.UP * 1.5)
		var present := not root.world_3d.direct_space_state.intersect_ray(query).is_empty()
		check(present == (distance > 20), "a seam-crossing bridge gap wraps correctly around lap start")
	print("Road corners: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

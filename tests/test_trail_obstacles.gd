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
	var course = load("res://scripts/offroad_course.gd").new()
	root.add_child(course)
	course.build(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json")))
	var hazards = course.get_node("TrailObstacles")
	check(hazards.sites.size()>=15,"Obstacles distributed around the route")
	check(hazards.find_children("FallenTree*","StaticBody3D",true,false).size()>=4,"Multiple collidable fallen trees")
	check(hazards.find_children("RouteRock*","StaticBody3D",true,false).size()>=15,"Boulders and rock gardens")
	var complete_trees := true
	for tree in hazards.find_children("FallenTree*","StaticBody3D",true,false):
		var crown = tree.get_node_or_null("BranchedLeafyCrown")
		if crown==null or crown.mesh.get_surface_count()!=2 or tree.get_node_or_null("ExposedForkedRoots")==null or tree.get_node_or_null("UprootedSoilPlate")==null:
			complete_trees = false
		elif crown.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX].size()<1000:
			complete_trees = false
	check(complete_trees,"Every fallen tree has forked branches, leafy crown and uprooted root plate")
	var roots_off_road := true
	var crowns_face_road := true
	for tree in hazards.find_children("FallenTree*","StaticBody3D",true,false):
		var root: Vector3 = tree.get_meta("root_anchor")
		var plate: Vector3 = tree.get_node("UprootedSoilPlate").global_position
		if course.terrain.trail_distance(Vector2(plate.x,plate.z))<4.0:
			roots_off_road = false
		var trunk: Vector3 = tree.get_node("MainTrunk").global_position
		if course.terrain.trail_distance(Vector2(trunk.x,trunk.z))>=course.terrain.trail_distance(Vector2(root.x,root.z)):
			crowns_face_road = false
	check(roots_off_road,"All root plates stay in the forest beyond the road and verge")
	check(crowns_face_road,"Each main trunk falls from its off-road root across the trail")
	var safe := true
	for site in hazards.sites:
		for gate in course.gates:
			if Vector2(site.position.x-gate.origin.x,site.position.z-gate.origin.z).length()<36:
				safe = false
	check(safe,"Checkpoint and recovery approaches stay clear")
	await physics_frame
	await physics_frame
	var collidable := true
	for body in hazards.get_children():
		var query := PhysicsRayQueryParameters3D.create(body.position+Vector3.UP*5,body.position+Vector3.DOWN*2)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != body:
			collidable = false
	check(collidable,"Every visible main obstacle has an active physical collider")
	# Every ground-level car-width lane must now intersect a real obstacle.
	var blocked := true
	for site in hazards.sites:
		var pose: Transform3D = course.pose_at(site.distance)
		for across in [-1.5,0.0,1.5]:
			var p: Vector3 = pose.origin+pose.basis.x*across
			p.y = load("res://scripts/offroad_model.gd").height_at(p.x,p.z)+0.7
			var box := BoxShape3D.new()
			box.size = Vector3(2.0,0.6,4.22)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = box
			query.transform = Transform3D(pose.basis,p)
			var hit_obstacle := false
			for hit in root.world_3d.direct_space_state.intersect_shape(query):
				if hit.collider.get_meta("trail_hazard",false):
					hit_obstacle = true
			if not hit_obstacle:
				blocked = false
				print("Open ground lane at site ",site.distance," across=",across)
	check(blocked,"Full-width rocks and trunks leave no ground-level car-width bypass")
	print("Trail obstacles: %d/%d passed; sites=%d"%[checks-failures,checks,hazards.sites.size()])
	course.free()
	quit(1 if failures else 0)

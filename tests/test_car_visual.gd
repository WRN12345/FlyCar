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
	var visual = load("res://scripts/roadster_visual.gd")
	if visual == null:
		push_error("Reference-based visual model not implemented")
		quit(1)
		return
	var car = load("res://scripts/car.gd").new()
	root.add_child(car)
	var valid := true
	var has_faces := false
	for node in car.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is ArrayMesh:
			has_faces = true
			var faces: PackedVector3Array = node.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				if not faces[i].is_finite() or (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared() < 1e-14:
					valid = false
	check(valid and has_faces, "new body meshes are finite and contain no collapsed triangles")
	check(car.get_node_or_null("RoadsterBody") != null, "model is a separate original visual component")
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	collision.shape = box
	collision.position.y = -0.5
	ground.add_child(collision)
	root.add_child(ground)
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	for i in 150:
		await physics_frame
	Input.action_press("throttle")
	for i in 120:
		await physics_frame
	Input.action_release("throttle")
	var spins := true
	for wheel in car.wheels:
		var spin = wheel.get_node_or_null("WheelVisual")
		spins = spins and spin != null and absf(spin.rotation.x) > 0.01
	check(spins, "all visible wheel assemblies rotate under real drive input")
	print("Roadster visual geometry: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

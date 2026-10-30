extends Node3D

signal gate_entered(body: Node3D, index: int)
const Geo = preload("res://scripts/geometry.gd")
const Catalog = preload("res://scripts/track_catalog.gd")
const Terrain = preload("res://scripts/terrain.gd")
var terrain: Node3D
var data: Dictionary
var route: Array[Vector3] = []
var gates: Array[Transform3D] = []
var gate_lights: Array[MeshInstance3D] = []
var distances: Array[float] = []
var length := 0.0
var spawn := Transform3D.IDENTITY
var gap_pose := Transform3D.IDENTITY
var barrier_pose := Transform3D.IDENTITY
var gap_distance := 0.0
var batches: Dictionary = {}
var road_body: StaticBody3D
var accent: Material
var selected: Material

func build(definition: Dictionary) -> void:
	data = definition
	name = "ActiveCourse"
	route = Catalog.sample(data)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(data, route)
	for i in route.size():
		distances.append(length)
		length += route[i].distance_to(route[(i + 1) % route.size()])
	var anchor := Catalog.world_point(data, data.gap_anchor)
	var closest := INF
	for i in route.size():
		var distance := route[i].distance_squared_to(anchor)
		if distance < closest:
			closest = distance
			gap_distance = distances[i]
	gap_pose = pose_at(gap_distance)
	barrier_pose = pose_at(float(data.barrier_distance))
	spawn = pose_at(16.0)
	spawn.origin += Vector3.UP * 0.78
	accent = Geo.material(Color(data.color), 0.15, 0.35)
	selected = Geo.material(Color("b5ec67"), 0.1, 0.45)
	var materials := {"asphalt": Geo.material(Color("2b3640")), "shoulder": Geo.material(Color("7a858a")), "edge": Geo.material(Color("e1e5dc")), "dark": Geo.material(Color("142733"), 0.2), "accent": accent, "white": Geo.material(Color("ebeee3")), "warning": Geo.material(Color("f2b14f")), "green": selected}
	for key in materials:
		batches[key] = {"material": materials[key], "transforms": []}
	road_body = StaticBody3D.new()
	add_child(road_body)
	for i in route.size():
		var a := route[i]
		var b := route[(i + 1) % route.size()]
		var center := (a + b) * 0.5
		var segment := a.distance_to(b)
		if segment < 0.01:
			continue
		var basis := Basis.looking_at((b - a).normalized())
		if absf(distances[i] + segment * 0.5 - gap_distance) < 12.5:
			continue
		add_box(Vector3(20, 0.7, segment + 0.18), center - Vector3.UP * 0.35, basis, "shoulder", true)
		add_box(Vector3(18, 0.035, segment + 0.2), center + Vector3.UP * 0.02, basis, "asphalt")
		for side in [-1.0, 1.0]:
			add_box(Vector3(0.18, 0.04, segment + 0.2), center + basis.x * side * 8.45 + Vector3.UP * 0.045, basis, "edge")
			add_box(Vector3(0.65, 0.08, segment + 0.2), center + basis.x * side * 9.1 + Vector3.UP * 0.04, basis, "accent" if i % 2 else "white")
			# Low guards do not prevent a misjudged airborne exit.
			add_box(Vector3(0.22, 0.45, segment + 0.2), center + basis.x * side * 9.85 + Vector3.UP * 0.23, basis, "dark", true)
		if i % 2 == 0:
			add_box(Vector3(0.18, 0.04, segment * 0.5), center + Vector3.UP * 0.045, basis, "edge")
		if i % 20 == 0:
			add_box(Vector3(2.5, center.y, 2.5), Vector3(center.x, center.y / 2 - 0.8, center.z), Basis.IDENTITY, "dark")
		if i % 24 == 0:
			add_box(Vector3(0.18, 5, 0.18), center + basis.x * 10.7 + Vector3.UP * 2.5, basis, "dark")
			add_box(Vector3(0.4, 0.16, 2.3), center + basis.x * 10.7 + Vector3.UP * 5, basis, "white")
	add_box(Vector3(18, 1.25, 1.6), barrier_pose.origin + Vector3.UP * 0.625, barrier_pose.basis, "warning", true)
	for x in range(-8, 9, 2):
		add_box(Vector3(0.7, 0.9, 0.05), barrier_pose * Vector3(x, 0.65, 0.84), barrier_pose.basis * Basis(Vector3.FORWARD, 0.45), "dark")
	for feature in [float(data.barrier_distance), gap_distance - 12.5]:
		for back in [28.0, 33.0, 38.0]:
			var pose := pose_at(feature - back)
			add_box(Vector3(17, 0.05, 0.35), pose.origin + Vector3.UP * 0.06, pose.basis, "green")
		var warning_pose := pose_at(feature - 46.0)
		add_box(Vector3(17, 2.4, 0.18), warning_pose.origin + Vector3.UP * 6.5, warning_pose.basis, "dark")
		label_at("LIFT-OFF / 喷射越障" if feature == float(data.barrier_distance) else "25m GAP / 前方断桥", warning_pose, 6.5, 0.014)
	for offset in [-13.0, 13.0]:
		var pose := pose_at(gap_distance + offset)
		add_box(Vector3(18, 0.16, 0.35), pose.origin + Vector3.UP * 0.05, pose.basis, "warning")
	for i in 8:
		var pose := pose_at(length * i / 8)
		gates.append(pose)
		create_gate(i, pose)
	# Start building is original scenery placed relative to each track's grid.
	for i in 6:
		var pose := pose_at(25.0 + i * 14)
		add_box(Vector3(12, 9, 11), pose.origin + pose.basis.x * 29 + Vector3.UP * 3.5, pose.basis, "dark")
		add_box(Vector3(12.3, 0.18, 11.3), pose.origin + pose.basis.x * 29 + Vector3.UP * 8.1, pose.basis, "accent")
		add_box(Vector3(0.10, 5, 8.5), pose.origin + pose.basis.x * 22.9 + Vector3.UP * 3, pose.basis, "shoulder")
	for x in range(-8, 9):
		for z in range(2):
			var pose := pose_at(0)
			add_box(Vector3(1, 0.06, 1), pose * Vector3(x, 0.07, z), pose.basis, "white" if (x + z) % 2 == 0 else "dark")
	flush_batches()

func add_box(size: Vector3, pos: Vector3, basis: Basis, key: String, collision: bool = false) -> void:
	batches[key].transforms.append(Transform3D(basis * Basis.from_scale(size), pos))
	if collision:
		var node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		node.shape = shape
		node.transform = Transform3D(basis, pos)
		road_body.add_child(node)

func flush_batches() -> void:
	for key in batches:
		var values: Array = batches[key].transforms
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		mesh.mesh = cube
		mesh.instance_count = values.size()
		for i in values.size():
			mesh.set_instance_transform(i, values[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mesh
		node.material_override = batches[key].material
		add_child(node)
	batches.clear()

func pose_at(distance: float) -> Transform3D:
	distance = fposmod(distance, length)
	for i in route.size():
		var a := route[i]
		var b := route[(i + 1) % route.size()]
		var segment := a.distance_to(b)
		if distance <= distances[i] + segment or i == route.size() - 1:
			return Transform3D(Basis.looking_at((b - a).normalized()), a.lerp(b, clampf((distance - distances[i]) / maxf(segment, 0.001), 0, 1)))
	return Transform3D.IDENTITY

func road_height_at(position: Vector3) -> float:
	var best := INF
	var height := Catalog.BASE_HEIGHT
	for i in route.size():
		var a := route[i]
		var b := route[(i + 1) % route.size()]
		var flat := Vector3(position.x, 0, position.z)
		var delta := Vector3(b.x - a.x, 0, b.z - a.z)
		var t := clampf((flat - Vector3(a.x, 0, a.z)).dot(delta) / maxf(delta.length_squared(), 0.001), 0, 1)
		var p := a.lerp(b, t)
		var distance := Vector2(p.x - position.x, p.z - position.z).length_squared()
		if distance < best:
			best = distance
			height = p.y
	return height

func label_at(text: String, pose: Transform3D, height: float, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel
	label.outline_size = 5
	label.transform = pose
	label.position += Vector3.UP * height + pose.basis.z * 0.12
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	label.font = font
	add_child(label)

func create_gate(index: int, pose: Transform3D) -> void:
	for side in [-1.0, 1.0]:
		add_box(Vector3(0.28, 6, 0.28), pose * Vector3(side * 9.7, 3, 0), pose.basis, "dark")
	var lamp := Geo.box(self, Vector3(19.6, 0.16, 0.26), pose.origin + Vector3.UP * 6, accent)
	lamp.basis = pose.basis
	gate_lights.append(lamp)
	label_at("START / FINISH" if index == 0 else "CP  %02d" % index, pose, 6.6, 0.012)
	var area := Area3D.new()
	area.transform = pose
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 64, 1)
	node.shape = shape
	node.position.y = 30
	area.add_child(node)
	add_child(area)
	area.body_entered.connect(func(body): gate_entered.emit(body, index))

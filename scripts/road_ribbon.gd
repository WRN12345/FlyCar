extends Node3D
## Adjacent segments use identical cross sections: no independent rotated road boxes.
var points: Array[Vector3] = []
var offsets: Array[Vector3] = []
var widths: Array[float] = []
var minimum_width := 18.0
var triangles: Dictionary = {}
var collision_points: Array[Vector3] = []

func offset_point(index: int, lateral: float, height: float = 0.0) -> Vector3:
	return points[index] + offsets[index] * lateral * widths[index] + Vector3.UP * height

func build(route: Array[Vector3], gap: Array[bool], distances: Array[float], materials: Dictionary) -> void:
	name = "ContinuousRoad"
	points = route
	var count := points.size()
	for i in count:
		var incoming := points[i] - points[(i - 1 + count) % count]
		var outgoing := points[(i + 1) % count] - points[i]
		incoming.y = 0
		outgoing.y = 0
		var side_before := incoming.normalized().cross(Vector3.UP)
		var side_after := outgoing.normalized().cross(Vector3.UP)
		var miter := (side_before + side_after).normalized()
		offsets.append(miter / maxf(0.6, miter.dot(side_after)))
		var radius := incoming.length() * outgoing.length() * (incoming + outgoing).length() / maxf(2 * incoming.cross(outgoing).length(), 0.00001)
		# Keep the inner offset below local curvature radius. Narrow only pinched hairpins.
		widths.append(clampf(radius * 0.72 / 10, 1.0 / 3, 1))
	# Propagate a bounded taper both ways around the closed loop, including the seam.
	for i in count * 2:
		var j := i % count
		var previous := (j - 1 + count) % count
		widths[j] = minf(widths[j], widths[previous] + points[j].distance_to(points[previous]) * 0.022)
	for i in count * 2:
		var j := posmod(count - 1 - i, count)
		var next := (j + 1) % count
		widths[j] = minf(widths[j], widths[next] + points[j].distance_to(points[next]) * 0.022)
	for width in widths:
		minimum_width = minf(minimum_width, width * 18)
	for key in materials:
		triangles[key] = []
	for i in count:
		if gap[i]:
			continue
		var j := (i + 1) % count
		strip(i, j, -10, 10, 0.0, "shoulder", true)
		strip(i, j, -9, 9, 0.025, "asphalt", false)
		strip(i, j, -10, 10, -0.7, "shoulder", true, true)
		wall(i, j, -10, -0.7, 0, "shoulder", true)
		wall(i, j, 10, -0.7, 0, "shoulder", true)
		for side in [-1.0, 1.0]:
			strip(i, j, side * 8.45 - 0.09, side * 8.45 + 0.09, 0.045, "edge")
			strip(i, j, side * 9.1 - 0.325, side * 9.1 + 0.325, 0.065, "accent" if int(distances[i] / 4.0) % 2 else "white")
			var lo: float = side * 9.85 - 0.11
			var hi: float = side * 9.85 + 0.11
			strip(i, j, lo, hi, 0.47, "dark", true)
			wall(i, j, lo, 0, 0.47, "dark", true)
			wall(i, j, hi, 0, 0.47, "dark", true)
		if int(distances[i] / 6.0) % 2 == 0:
			strip(i, j, -0.09, 0.09, 0.045, "edge")
		if gap[(i - 1 + count) % count]:
			cap(i, -10, 10, -0.7, 0, "shoulder")
		if gap[j]:
			cap(j, -10, 10, -0.7, 0, "shoulder")
	for key in triangles:
		if triangles[key].is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in triangles[key]:
			st.add_vertex(vertex)
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.name = "Road_" + key
		node.mesh = st.commit()
		var material: Material = materials[key].duplicate()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = material
		add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("landing_surface", true)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(collision_points))
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String, collision: bool = false, reverse: bool = false) -> void:
	var vertices := [a, d, b, b, d, c] if not reverse else [a, b, d, b, c, d]
	triangles[key].append_array(vertices)
	if collision:
		collision_points.append_array(vertices)

func strip(i: int, j: int, lo: float, hi: float, height: float, key: String, collision: bool = false, reverse: bool = false) -> void:
	quad(offset_point(i, lo, height), offset_point(i, hi, height), offset_point(j, hi, height), offset_point(j, lo, height), key, collision, reverse)

func wall(i: int, j: int, offset: float, bottom: float, top: float, key: String, collision: bool) -> void:
	quad(offset_point(i, offset, top), offset_point(i, offset, bottom), offset_point(j, offset, bottom), offset_point(j, offset, top), key, collision)

func cap(i: int, lo: float, hi: float, bottom: float, top: float, key: String) -> void:
	quad(offset_point(i, lo, top), offset_point(i, hi, top), offset_point(i, hi, bottom), offset_point(i, lo, bottom), key, true)

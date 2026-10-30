extends RefCounted
## All meshes are original procedural geometry. No external model dependency.

static func material(color: Color, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.38 if metallic > 0.0 else 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, pos, mat)

static func solid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	box(body, size, Vector3.ZERO, mat)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	body.add_child(c)
	return body

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return mesh_node(parent, mesh, pos, mat)

static func loft(parent: Node3D, sections: Array, mat: Material) -> void:
	var rings: Array[PackedVector3Array] = []
	for s in sections:
		var z: float = s[0]
		var w: float = s[1]
		var lo: float = s[2]
		var hi: float = s[3]
		var bevel := minf(0.10, (hi - lo) * 0.3)
		rings.append(PackedVector3Array([
			Vector3(-w * 0.82, lo, z), Vector3(-w, lo + bevel, z),
			Vector3(-w, hi - bevel, z), Vector3(-w * 0.76, hi, z),
			Vector3(w * 0.76, hi, z), Vector3(w, hi - bevel, z),
			Vector3(w, lo + bevel, z), Vector3(w * 0.82, lo, z)]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		for j in 8:
			var k := (j + 1) % 8
			for v in [rings[i][j], rings[i][k], rings[i + 1][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]]:
				st.add_vertex(v)
	for end in [0, rings.size() - 1]:
		for j in range(1, 7):
			var tri := [rings[end][0], rings[end][j], rings[end][j + 1]]
			if end != 0:
				tri.reverse()
			for v in tri:
				st.add_vertex(v)
	st.generate_normals()
	mesh_node(parent, st.commit(), Vector3.ZERO, mat)

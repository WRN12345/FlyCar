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
		rings.append(PackedVector3Array([
			Vector3(-w * 0.82, lo, z), Vector3(-w, lo + 0.10, z),
			Vector3(-w, hi - 0.10, z), Vector3(-w * 0.76, hi, z),
			Vector3(w * 0.76, hi, z), Vector3(w, hi - 0.10, z),
			Vector3(w, lo + 0.10, z), Vector3(w * 0.82, lo, z)]))
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

static func car_shell(parent: Node3D) -> void:
	var paint := material(Color("bd263c"), 0.45)
	var dark := material(Color("101d29"), 0.65)
	var glass := material(Color("19394a"), 0.4)
	glass.roughness = 0.45
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var white := material(Color("c6f5ff"), 0.0, 2.5)
	var red := material(Color("ff3354"), 0.0, 2.0)
	loft(parent, [[-2.28, 0.65, -0.31, 0.16], [-1.92, 0.94, -0.44, 0.32], [-1.35, 1.0, -0.48, 0.43], [-0.65, 0.94, -0.48, 0.44], [0.65, 0.97, -0.48, 0.43], [1.35, 1.04, -0.46, 0.49], [2.16, 0.94, -0.36, 0.37]], paint)
	loft(parent, [[-1.0, 0.73, 0.36, 0.47], [-0.32, 0.69, 0.38, 0.99], [0.54, 0.68, 0.38, 1.00], [1.28, 0.76, 0.36, 0.49]], glass)
	box(parent, Vector3(1.27, 0.035, 0.65), Vector3(0, 1.005, 0.12), dark)
	for side in [-1.0, 1.0]:
		var headlight := box(parent, Vector3(0.58, 0.045, 0.10), Vector3(side * 0.61, 0.24, -2.09), white)
		headlight.rotation.y = side * -0.18
		box(parent, Vector3(0.67, 0.045, 0.07), Vector3(side * 0.53, 0.31, 2.16), red)
		box(parent, Vector3(0.09, 0.10, 2.4), Vector3(side * 0.97, -0.40, 0.1), dark)
		box(parent, Vector3(0.22, 0.10, 0.27), Vector3(side * 0.98, 0.56, -0.58), paint)
	box(parent, Vector3(1.4, 0.10, 0.11), Vector3(0, -0.07, -2.23), dark)
	box(parent, Vector3(1.65, 0.15, 0.24), Vector3(0, -0.07, 2.10), dark)
	for x in [-0.55, -0.27, 0.0, 0.27, 0.55]:
		box(parent, Vector3(0.035, 0.21, 0.43), Vector3(x, -0.08, 2.05), dark)
	box(parent, Vector3(1.55, 0.045, 0.15), Vector3(0, 0.43, 2.04), dark)
	var badge := Label3D.new()
	badge.text = "R O A D S T E R"
	badge.font_size = 32
	badge.pixel_size = 0.002
	badge.position = Vector3(0, 0.16, 2.205)
	badge.rotation.y = PI
	parent.add_child(badge)

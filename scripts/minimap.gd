extends Control

var points: Array[Vector3] = []
var vehicle: Node3D
var gates: Array[Transform3D] = []
var next_gate := 1

func project(p: Vector3) -> Vector2:
	return Vector2(22 + p.x * 0.57, 22 + (p.z + 210) * 0.40)

func _draw() -> void:
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for p in points:
		line.append(project(p))
	line.append(project(points[0]))
	draw_polyline(line, Color("334754"), 5, true)
	for i in gates.size():
		draw_circle(project(gates[i].origin), 4 if i == next_gate else 2, Color("b6f56c") if i == next_gate else Color("647e8b"))
	if is_instance_valid(vehicle):
		var p := project(vehicle.position)
		var forward := -vehicle.global_basis.z
		var dir := Vector2(forward.x, forward.z).normalized()
		draw_circle(p, 4, Color("e6faff"))
		draw_line(p, p + dir * 10, Color("e6faff"), 2, true)

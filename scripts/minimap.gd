extends Control

var minimum := Vector2.ZERO
var maximum := Vector2.ONE
var points: Array[Vector3] = []:
	set(value):
		points = value
		minimum = Vector2(INF, INF)
		maximum = Vector2(-INF, -INF)
		for point in points:
			minimum = minimum.min(Vector2(point.x, point.z))
			maximum = maximum.max(Vector2(point.x, point.z))
		queue_redraw()
var vehicle: Node3D
var gates: Array[Transform3D] = []
var next_gate := 1
var route_color := Color("7797a7")
var shortcut_lines: Array = []

func project(p: Vector3) -> Vector2:
	if points.is_empty():
		return size / 2
	var extent := maximum - minimum
	var scale_factor := minf((size.x - 24) / maxf(extent.x, 1), (size.y - 24) / maxf(extent.y, 1))
	return (Vector2(p.x, p.z) - (minimum + maximum) * 0.5) * scale_factor + size * 0.5

func _draw() -> void:
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for p in points:
		line.append(project(p))
	line.append(project(points[0]))
	draw_polyline(line, route_color.darkened(0.65), 6, true)
	draw_polyline(line, route_color, 2, true)
	for cut in shortcut_lines:
		for i in range(cut.points.size()-1):
			draw_dashed_line(project(cut.points[i]),project(cut.points[i+1]),Color("f4c477"),2,4)
	for i in gates.size():
		draw_circle(project(gates[i].origin), 4 if i == next_gate else 2, Color("b6f56c") if i == next_gate else Color("647e8b"))
	if is_instance_valid(vehicle):
		var p := project(vehicle.position)
		var forward := -vehicle.global_basis.z
		var dir := Vector2(forward.x, forward.z).normalized()
		draw_circle(p, 4, Color("e6faff"))
		draw_line(p, p + dir * 10, Color("e6faff"), 2, true)

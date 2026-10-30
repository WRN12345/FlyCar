extends RefCounted
## Original manually interpreted centerlines; publicly referenced diagrams are not bundled.
const BASE_HEIGHT := 32.0

static func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["id", "name", "subtitle", "source", "color"]:
		if not data.get(key) is String or data[key].is_empty():
			return false
	for key in ["scale", "reference_km", "elevation", "barrier_distance"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return false
	if data.scale < 0.05 or data.scale > 10 or data.reference_km <= 0 or data.reference_km > 30 or absf(data.elevation) > 20:
		return false
	if not data.id.is_valid_identifier() or not Color.html_is_valid(data.color):
		return false
	if not data.get("points") is Array or data.points.size() < 12 or data.points.size() > 512:
		return false
	if not data.get("gap_anchor") is Array or data.gap_anchor.size() != 2:
		return false
	for p in data.points + [data.gap_anchor]:
		if not p is Array or p.size() != 2:
			return false
		for value in p:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(value) > 100000:
				return false
	var perimeter := 0.0
	for i in data.points.size():
		var a: Array = data.points[i]
		var b: Array = data.points[(i + 1) % data.points.size()]
		var distance := Vector2(a[0] - b[0], a[1] - b[1]).length() * float(data.scale)
		if distance < 0.25 or distance > 2500:
			return false
		perimeter += distance
	if perimeter < 1000 or perimeter > 10000 or data.barrier_distance < 50 or data.barrier_distance > perimeter - 50:
		return false
	return true

static func load_tracks() -> Array:
	var result: Array = []
	var files := DirAccess.get_files_at("res://tracks")
	files.sort()
	var ids: Array[String] = []
	for file in files:
		if file.ends_with(".json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/" + file))
			if valid(data) and not data.id in ids:
				result.append(data)
				ids.append(data.id)
	return result

static func world_point(data: Dictionary, p: Array) -> Vector3:
	var origin: Array = data.points[0]
	var initial := Vector3(data.points[1][0] - origin[0], 0, data.points[1][1] - origin[1])
	var yaw := -Basis.looking_at(initial.normalized()).get_euler().y
	return Vector3((p[0] - origin[0]) * data.scale, 0, (p[1] - origin[1]) * data.scale).rotated(Vector3.UP, yaw) + Vector3.UP * BASE_HEIGHT

static func sample(data: Dictionary) -> Array[Vector3]:
	if not valid(data):
		return []
	var controls: Array[Vector3] = []
	for p in data.points:
		controls.append(world_point(data, p))
	var result: Array[Vector3] = []
	var count := controls.size()
	for i in count:
		var a := controls[(i - 1 + count) % count]
		var b := controls[i]
		var c := controls[(i + 1) % count]
		var d := controls[(i + 2) % count]
		var steps := maxi(2, ceili(b.distance_to(c) / 4.0))
		for j in steps:
			var t := float(j) / steps
			var point := b.cubic_interpolate(c, a, d, t)
			point.y += sin(TAU * (i + t) / count) * data.elevation
			result.append(point)
	return result

static func length_of(points: Array) -> float:
	var length := 0.0
	for i in points.size():
		length += points[i].distance_to(points[(i + 1) % points.size()])
	return length

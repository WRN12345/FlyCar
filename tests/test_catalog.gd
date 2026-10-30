extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var catalog = load("res://scripts/track_catalog.gd")
	if catalog == null:
		push_error("Track catalog not implemented")
		quit(1)
		return
	var tracks: Array = catalog.load_tracks()
	tracks = tracks.filter(func(data): return data.get("mode","")!="offroad")
	check(tracks.size() == 3, "three Chinese tracks discovered from JSON")
	var lengths: Array = []
	for data in tracks:
		var route: Array = catalog.sample(data)
		check(route.size() > 80, "centerline is sampled for smooth road")
		check(route[0].distance_to(route[-1]) < 12, "closed centerline has no seam gap")
		var anchor: Vector3 = catalog.world_point(data, data.gap_anchor)
		var nearest := INF
		for point in route:
			nearest = minf(nearest, point.distance_to(anchor))
		check(nearest < 12.0, "bridge anchor lies on generated centerline")
		check(catalog.length_of(route) > 1000.0, "course has meaningful racing length")
		lengths.append(snappedf(catalog.length_of(route), 1.0))
	check(lengths[0] != lengths[1] and lengths[1] != lengths[2], "distinct routes are not renamed oval")
	check(not catalog.valid({}), "invalid track data rejected")
	var repeated: Dictionary = tracks[0].duplicate(true)
	repeated.points[1] = repeated.points[0].duplicate()
	check(not catalog.valid(repeated), "zero direction must be rejected before Basis construction")
	var huge: Dictionary = tracks[0].duplicate(true)
	huge.points[1] = [1e20, 1e20]
	check(not catalog.valid(huge), "oversized input cannot cause unbounded sampling")
	var bad_color: Dictionary = tracks[0].duplicate(true)
	bad_color.color = "not-a-color"
	check(not catalog.valid(bad_color), "invalid material color rejected")
	print("Track catalog: ", 18 - failures, "/18 passed")
	quit(1 if failures else 0)

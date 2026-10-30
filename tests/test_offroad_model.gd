extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var model = load("res://scripts/offroad_model.gd")
	if model == null:
		push_error("Continuous off-road terrain not implemented")
		quit(1)
		return
	var profiles := {}
	for key in ["dirt", "gravel", "mud", "grass", "water", "rock"]:
		var p: Dictionary = model.profile(key)
		profiles[key] = p
		check(p.grip > 0 and p.rolling > 0 and p.color is Color, "surface profile exists: " + key)
	check(profiles.mud.grip < profiles.dirt.grip and profiles.water.rolling > profiles.dirt.rolling, "mud slips and shallow water resists more than packed dirt")
	var smooth := true
	for x in range(-600, 550, 23):
		for z in range(-1050, 150, 29):
			var h: float = model.height_at(x, z)
			if not is_finite(h) or absf(h - model.height_at(x + 0.001, z)) > 0.02:
				smooth = false
	check(smooth, "height field is finite and continuous including chunk borders")
	check(model.water_depth(255,-800) > 0.1 and model.water_depth(255,-800) < 0.5, "main river crossing has a shallow driveable bed")
	check(model.water_depth(255,-1040) > 1.0, "off-route deep pool can submerge a car")
	check(model.height_at(440,-430) < model.height_at(310,-430) - 10, "canyon shortcut crosses a deep depression while main bypass stays high")
	var catalog = load("res://scripts/track_catalog.gd")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/04_valley.json"))
	var bad: Dictionary = data.duplicate(true)
	bad.erase("checkpoint_anchors")
	check(not catalog.valid(bad), "off-road without checkpoint anchors is rejected")
	bad = data.duplicate(true)
	bad.checkpoint_anchors[2] = [INF,0]
	check(not catalog.valid(bad), "non-finite checkpoint anchors rejected")
	bad = data.duplicate(true)
	bad.checkpoint_anchors.resize(7)
	check(not catalog.valid(bad), "off-road requires exactly eight checkpoints")
	bad = data.duplicate(true)
	bad.checkpoint_anchors[3]=bad.checkpoint_anchors[2].duplicate()
	check(not catalog.valid(bad), "duplicated or reversed checkpoint order is rejected")
	print("Off-road terrain model: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

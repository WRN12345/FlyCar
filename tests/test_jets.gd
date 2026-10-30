extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var control = load("res://scripts/thruster_control.gd")
	if control == null:
		push_error("Fuel-limited landing and attitude jets not implemented")
		quit(1)
		return
	var lift: float = 40000.0 / 1650.0
	check(control.landing_duty(2.0, -6.0, 1.0, true, 0, lift) > 0, "descending over track engages landing brake")
	check(control.landing_duty(2.0, 3.0, 1.0, true, 0, lift) == 0, "ascent does not trigger landing jets")
	check(control.landing_duty(2.0, -6.0, 1.0, false, 0, lift) == 0, "sea, terrain and absent road cannot trigger landing assist")
	check(control.landing_duty(2.0, -6.0, -1.0, true, 0, lift) == 0, "inverted car receives no automatic rescue")
	check(control.landing_duty(20.0, -6.0, 1.0, true, 0, lift) == 0, "jets wait for nearby landing surface")
	check(control.landing_duty(0.6, -2.0, 1.0, true, 3, lift) == 0, "suspension takes over after road contact")
	var pitch: PackedFloat32Array = control.duties(0.0, 1.0, 0.0)
	var torque := Vector3.ZERO
	for i in 4:
		torque += control.NOZZLES[i].cross(Vector3.UP * pitch[i])
	check(torque.x > 0.1 and absf(torque.z) < 0.0001, "front nozzle differential produces requested pitch without roll")
	var roll: PackedFloat32Array = control.duties(1.0, 0.0, 1.0)
	torque = Vector3.ZERO
	for i in 4:
		torque += control.NOZZLES[i].cross(Vector3.UP * roll[i])
	check(torque.z < -0.1 and absf(torque.x) < 0.0001, "left nozzle differential produces requested roll at full burst")
	var spent: Dictionary = control.consume(PackedFloat32Array([1,1,1,1]), 0.001, 1.0 / 120)
	check(spent.fuel == 0 and spent.duties[0] > 0 and spent.duties[0] < 1, "last gas fraction scales force to available impulse")
	spent = control.consume(PackedFloat32Array([1,1,1,1]), 0.0, 1.0 / 120)
	check(spent.duties == PackedFloat32Array([0,0,0,0]), "empty tank produces no thrust")
	var quarter: Dictionary = control.consume(PackedFloat32Array([1,0,0,0]), 1.0, 0.12)
	check(is_equal_approx(quarter.fuel, 0.975), "gas use follows actual sum of nozzle duties")
	print("Thruster controller: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

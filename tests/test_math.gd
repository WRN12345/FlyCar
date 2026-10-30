extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var script = load("res://scripts/vehicle_math.gd")
	if script == null:
		push_error("FAIL: vehicle fuel and tire model has not been implemented")
		quit(1)
		return
	check(is_equal_approx(script.next_fuel(0.1, true, false, 1.0), 0.0), "fuel never goes negative")
	check(is_equal_approx(script.next_fuel(0.3, false, false, 1.0), 0.3), "airborne fuel cannot recharge")
	check(is_equal_approx(script.next_fuel(0.9, false, true, 1.0), 1.0), "ground recharge capped")
	check(script.tire_force(1000.0, 100.0, 30.0, 1.0, 0.0, 1.1).length() <= 1100.01, "combined tire force respects grip circle")
	check(script.tire_force(0.0, 10.0, 20.0, 1.0, 1.0, 1.1).is_zero_approx(), "no traction without contact load")
	check(script.tire_force(1000.0, 2.0, 20.0, 0.0, 0.0, 1.1).x < 0.0, "lateral grip opposes slip")
	print("Vehicle math: ", 6 - failures, "/6 passed")
	quit(1 if failures else 0)

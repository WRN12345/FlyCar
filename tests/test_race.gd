extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var script = load("res://scripts/race_state.gd")
	if script == null:
		push_error("FAIL: ordered checkpoint race not implemented")
		quit(1)
		return
	var race = script.new(6)
	check(not race.pass_gate(3, true), "cannot skip checkpoint")
	check(not race.pass_gate(1, false), "reverse crossing rejected")
	check(race.pass_gate(1, true), "next checkpoint accepted")
	check(not race.pass_gate(1, true), "duplicate rejected")
	check(not race.pass_gate(0, true), "early finish rejected")
	for gate in [2, 3, 4, 5, 0]:
		race.pass_gate(gate, true)
	check(race.finished, "complete ordered lap finishes")
	race.restart()
	check(not race.finished and race.next_gate == 1 and race.elapsed == 0.0, "restart clears race state")
	print("Race state: ", 7 - failures, "/7 passed")
	quit(1 if failures else 0)

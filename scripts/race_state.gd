extends RefCounted

var gate_count: int
var next_gate := 1
var elapsed := 0.0
var finished := false
var recoveries := 0

func _init(count: int = 8) -> void:
	gate_count = count

func pass_gate(index: int, forward: bool) -> bool:
	if finished or not forward or index != next_gate:
		return false
	if index == 0:
		finished = true
	else:
		next_gate = (index + 1) % gate_count
	return true

func restart() -> void:
	next_gate = 1
	elapsed = 0.0
	finished = false
	recoveries = 0

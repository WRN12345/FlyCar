extends RefCounted
## Game tuning in SI units; not inferred Tesla hardware specifications.
const NOZZLES := [Vector3(-0.6324, -0.19, -0.952), Vector3(0.6324, -0.19, -0.952), Vector3(-0.6324, -0.19, 0.952), Vector3(0.6324, -0.19, 0.952)]
const TANK_SECONDS := 1.2
const PROBE_LENGTH := 12.0

static func landing_duty(height: float, vertical_speed: float, upright: float, road_below: bool, contacts: int, lift_acceleration: float) -> float:
	if not road_below or upright < 0.65 or contacts > 0 or vertical_speed >= -1.5 or height < 0.2 or height > PROBE_LENGTH:
		return 0.0
	var available := lift_acceleration * upright
	var brake_acceleration := available - 9.81
	if brake_acceleration <= 0:
		return 0.0
	var fall_speed := -vertical_speed
	var stopping_distance := fall_speed * fall_speed / (2.0 * brake_acceleration)
	if height > stopping_distance + 1.6:
		return 0.0
	var target_speed := maxf(1.5, sqrt(8.0 * maxf(0, height - 0.65)))
	return clampf((9.81 + (fall_speed - target_speed) * 6.0) / available, 0, 1)

static func duties(base: float, pitch: float, roll: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	base = maxf(base, 0.22 * maxf(absf(pitch), absf(roll)))
	for nozzle in NOZZLES:
		result.append(clampf(base - signf(nozzle.z) * pitch * 0.22 - signf(nozzle.x) * roll * 0.22, 0, 1))
	return result

static func consume(requested: PackedFloat32Array, fuel: float, dt: float) -> Dictionary:
	var total := 0.0
	for duty in requested:
		total += duty
	var cost := total * 0.25 * dt / TANK_SECONDS
	var fraction := minf(1.0, fuel / cost) if cost > 0 else 0.0
	var actual := requested.duplicate()
	for i in actual.size():
		actual[i] *= fraction
	return {"duties": actual, "fuel": maxf(0, fuel - cost)}

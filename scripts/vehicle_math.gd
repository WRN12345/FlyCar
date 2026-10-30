extends RefCounted
## Units: metres, seconds, kilograms, newtons. Game tuning, not Tesla specs.

static func next_fuel(current: float, burning: bool, grounded: bool, dt: float) -> float:
	if burning:
		return maxf(0.0, current - dt / 1.2)
	return minf(1.0, current + dt * 0.18) if grounded else current

static func tire_force(load_n: float, side_speed: float, speed: float, throttle: float, brake: float, grip: float, rolling: float = 9.0) -> Vector2:
	if load_n <= 0.0:
		return Vector2.ZERO
	var lateral := -side_speed * 2100.0
	var drive := throttle * 3400.0 * clampf(1.0 - absf(speed) / 88.0, 0.0, 1.0)
	var longitudinal := drive - signf(speed) * minf(absf(speed) * 1800.0, brake * 7200.0) - speed * rolling
	return Vector2(lateral, longitudinal).limit_length(load_n * grip)

# Camera jitter correction

Root causes reproduced before changing implementation:

- Position was smoothed while `look_at` used raw suspension position/heading, injecting high-frequency pitch into the view (0.010818 radians per frame in the alternating-bounce fixture).
- An obstructed camera snapped directly to each ray hit point. Alternating fence rail/post hits produced 1 metre position changes between frames.
- Reset retained camera position/history until the previous follow caught up.

Correction:

- Shared filtered anchor and heading for camera position/target. Horizontal follow has small velocity feed-forward; vertical response increases during real jumps/falls instead of freezing the camera height.
- Filter and five-ray near-plane footprint collision query run together in the same physics step, using the same candidate pose. Rendering interpolates the resulting world transforms; automatic camera interpolation is disabled to avoid applying it twice.
- Immediate inward collision limit, 0.16 second release hold, 5 cm hysteresis, damped extension capped at 6 metres/second. Camera stays upright and preserves travel heading when chassis pitch passes vertical.
- Reset clears follow, collision release and render interpolation history; large discontinuities do not interpolate through the environment.

Verification:

- `test_camera_stability.gd`: controlled bounce, alternating obstruction, clear-and-release, reset, vertical pitch, 30/60/144 FPS response, actual moving collider with orbit and render interpolation history (9 checks).
- The controlled bounce fixture drops below 0.003 radians/frame; the alternating obstruction fixture has no repeated position jumps. These are synthetic regression measurements, not a promise of zero motion in every scene.
- `capture_camera_stability.gd` runs native road driving and a short manual jet jump, checks no recoveries/crash, and saves a game screenshot.
- Mouse look, map/focus release, boundary, landing jets and fence regressions are run separately.

Reference: [Godot 4.7 manual camera interpolation](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html).

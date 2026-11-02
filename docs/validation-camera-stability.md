# Camera jitter correction

## Follow-up: continuous normal-driving jitter

The first fix smoothed/interpolated only the camera. The project's vehicle rendering still had physics interpolation disabled, so the visible car jumped between physics poses while the camera moved between them. The earlier synthetic camera tests did not render the car and therefore missed this phase mismatch.

The project now enables physics interpolation; `main._ready()` also enables it at runtime so editor-cached project settings cannot leave the old behavior active. Camera interpolation remains manual/off to avoid applying it twice. Car spawns and teleports prime and reset their interpolation history after the physics transform has synced back to the node. New course history is reset on creation. Frame-driven wreck effects explicitly disable automatic interpolation.

Native constant-velocity render measurements (`probe_camera_render.gd`, 120 Hz physics, screen-space vehicle position relative to the camera):

| Render cap | Old vehicle rendering | Synchronized rendering |
| --- | --- | --- |
| 75 FPS | 2.77 px range | <0.001 px range |
| 144 FPS | 3.20 px range | <0.001 px range |

These measure removal of render quantization in a controlled uniform-motion fixture, not elimination of real suspension movement or low-FPS stalls. A 100 m actual-car teleport produced 0 m stale render deviation. Native forest driving without jets and a separate drive/jump trial both ran with interpolation enabled and no crash/recovery.

Run the render check without headless mode: `--script tests/probe_camera_render.gd -- 75 on` and `--script tests/probe_camera_render.gd -- 144 on`. The `off` mode reproduces the former configuration for comparison. Unlike the earlier mock tests, this checks the displayed vehicle pose at actual render cadence.

## Earlier follow/occlusion fixes

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

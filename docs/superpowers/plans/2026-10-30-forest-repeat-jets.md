# Forest valley and reusable jets

User reports one-flight-only behavior and a simplistic map; selected a dense forest valley with trees, cliffs, creek and muddy/rocky trails. Execute inline with test-first fixes and final independent review.

- [x] Reproduce empty tank held-Space lockout and repeated launch behavior. Add supported two-wheel recharge tests; implement empty-trigger release latch, grounded faster refill and visible recharge/rearm status. Never refill in air or while inverted; recovery itself does not give free gas.
- [x] Replace sparse cone-tree scenery with original textured, branched tree prototypes in spatial MultiMesh batches, dense layered forest/undergrowth, creek-bank detail and physical cliff formations. Preserve main road, shortcuts and gas/vehicle physics.
- [x] Improve procedural soil/rock/bark/leaf materials, water and off-road lighting/backdrop. Keep old elevated-map environment unchanged. Use original code-generated assets, no external download dependency.
- [x] Validate reuse, dense scene/route clearance, full physical lap/shortcuts and legacy behavior. Inspect native forest/rock/creek shots, obtain review, document and synchronize.

Final validation: 226/226 checks across all 22 scripts passed sequentially with fixed 120Hz simulation after the last geometry changes. Native screenshots passed shader/normal visual QA, measured 55–60FPS on AMD780M OpenGL in the sampled view. Main lap 276.67s, shortcuts 2/2. Fresh review accepted wall-support weighting, release/rearm and correct shortcut waypoint driving. Headless fast-exit audio teardown may still log ObjectDB warnings; no script errors or failed checks. The unrelated project.godot settings-order-only edit remains unstaged.

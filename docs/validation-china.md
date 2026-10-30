# China expansion validation — 2026-10-30

Approved spec: superpowers/specs/2026-10-30-china-tracks-design.md.

Environment: Godot 4.7.2, Windows, Jolt 120Hz, OpenGL Compatibility / AMD Radeon 780M.

## Checks

- Legacy vehicle/race/obstacle regression: 35 checks (original course moved to explicit tests/fixtures/legacy_world.tscn; shared production car physics remains under test).
- New track catalog: 18 checks, including distinct closed paths, gap anchors on route, rejected degenerate geometry, oversized input and invalid colors.
- New multi-map lifecycle: 31 checks covering selection, road gap raycasts, four-wheel spawning on all maps, old course removal, pause state restoration, finite explosion, no duplicate R penalty, fuel preservation, restart/switch cancellation, record isolation/persistence, airborne safety and map projection.
- New physical obstacle driving: 6 checks; each of three maps cleared its full-width barrier and bridge using actual throttle/burst inputs. Bridge approach tested at approximately 23m/s (83km/h), with a 0.7s burst.
- Actual rendered menu, all three courses and explosion inspected. Menu includes automatic horizontal scrolling for later additions. Road geometry is grouped into MultiMeshes to reduce draw calls.

## Bugs found and corrected

A native-render run could evaluate falling before a pending rigid-body teleport had reached the physics state, explode at the stale position, and freeze the unapplied reset. Regression reproduced this by calling the world update before its pending pose; world fall/countdown processing now waits for pending reset to apply.

Independent code review found unbounded and degenerate input accepted by the track loader. Three regressions failed before the fix. Loader now bounds control count, scale, coordinate magnitudes, edge lengths and perimeter, rejects zero-length directions and invalid colors, and refuses invalid data before sampling.

## Decisions and limits

Work performed inline in user's existing active project; original project.godot formatting-only reorder preserved. Original full world retained only as a test fixture to keep v1 obstacle regressions reproducible. The three routes were manually interpreted from public layout references; no source reference images are bundled. Scaled route lengths are displayed separately from real-circuit reference lengths. Added original procedural explosion visuals and synthesized sound.

No exact CAD terrain/elevation, licensed track artwork, multiplayer, AI opponents or executable export. Full human-driven laps and final tire/suspension tuning remain playtesting work; automated checks validate specific physics and lifecycle behaviors rather than claiming measured real-world fidelity.
